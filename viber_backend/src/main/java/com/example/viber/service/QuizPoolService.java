package com.example.viber.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.example.viber.exception.ConflictException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.QuizSong;
import com.example.viber.repository.QuizSongRepository;

/**
 * Gestión del catálogo de canciones del quiz (solo admin).
 *
 * El seeding parte del import de playlists de YouTube ya existente
 * (1 unidad de cuota por cada 50 vídeos) y enriquece cada canción con
 * Deezer. Las que no matchean se guardan "incompletas" para que el admin
 * las corrija y re-matchee desde el panel.
 */
@Service
public class QuizPoolService {

    @Autowired private QuizSongRepository quizSongRepository;
    @Autowired private YoutubeService     youtubeService;
    @Autowired private DeezerService      deezerService;
    @Autowired private LrclibService      lrclibService;
    @Autowired private EmojiSuggestService emojiSuggestService;

    // ── Import de playlist ────────────────────────────────────────────────────

    /**
     * Importa una playlist pública de YouTube al pool.
     * Devuelve un resumen: añadidas con metadata, añadidas incompletas y omitidas.
     */
    public Map<String, Object> importPlaylist(String playlistUrlOrId, int max) {
        String playlistId = YoutubeService.extractPlaylistId(playlistUrlOrId);
        if (playlistId == null || playlistId.isEmpty()) {
            throw new RuntimeException(
                "No se pudo extraer el ID de la playlist. Comprueba que la URL incluye 'list='.");
        }

        List<Map<String, String>> items = youtubeService.getPlaylistItems(playlistId, max);
        if (items.isEmpty()) {
            throw new NotFoundException("La playlist no contiene vídeos públicos o no existe");
        }

        int matched = 0, unmatched = 0, skipped = 0;

        for (Map<String, String> item : items) {
            String videoId = item.get("videoId");
            if (videoId == null || quizSongRepository.existsByVideoId(videoId)) {
                skipped++;
                continue;
            }

            QuizSong song = buildFromYoutube(
                videoId, item.get("title"), item.get("channel"), item.get("thumbnail"));

            if (song.getDeezerTrackId() != null) matched++;
            else unmatched++;

            quizSongRepository.save(song);

            // Respetar el límite de Deezer (50 peticiones / 5 s)
            try { Thread.sleep(DeezerService.THROTTLE_MS); }
            catch (InterruptedException e) { Thread.currentThread().interrupt(); break; }
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("total",     items.size());
        summary.put("matched",   matched);
        summary.put("unmatched", unmatched);
        summary.put("skipped",   skipped);
        return summary;
    }

    // ── Alta individual ───────────────────────────────────────────────────────

    /** Añade una sola canción (desde el buscador de YouTube del panel admin). */
    public QuizSong addSong(String videoId, String youtubeTitle, String channelTitle) {
        if (videoId == null || videoId.isBlank()) {
            throw new RuntimeException("Falta el videoId");
        }
        if (quizSongRepository.existsByVideoId(videoId)) {
            throw new ConflictException("Esa canción ya está en el pool del quiz");
        }
        return quizSongRepository.save(
            buildFromYoutube(videoId, youtubeTitle, channelTitle, null));
    }

    /** Construye la entidad matcheando contra Deezer; si falla queda incompleta. */
    private QuizSong buildFromYoutube(String videoId, String youtubeTitle,
                                      String channelTitle, String thumbnail) {
        QuizSong song = new QuizSong();
        song.setVideoId(videoId);

        Optional<DeezerService.DeezerTrack> match =
            deezerService.match(youtubeTitle, channelTitle);

        if (match.isPresent()) {
            DeezerService.DeezerTrack t = match.get();
            song.setTitle(t.getTitle());
            song.setArtistName(t.getArtistName());
            song.setAlbumTitle(t.getAlbumTitle());
            song.setReleaseYear(t.getReleaseYear());
            song.setGenre(t.getGenre());
            song.setDurationSec(t.getDurationSec());
            song.setExplicit(t.getExplicit());
            song.setPreviewUrl(t.getPreviewUrl());
            song.setCoverUrl(t.getCoverUrl() != null ? t.getCoverUrl() : thumbnail);
            song.setDeezerTrackId(t.getTrackId());
            // Con el match ya tenemos artista/título canónicos → letra para el modo letra.
            // Si lrclib está caído queda a null y se recupera con "Buscar letras".
            try {
                lrclibService.fetchPlainLyrics(t.getArtistName(), t.getTitle(), t.getDurationSec())
                    .ifPresent(song::setLyrics);
            } catch (LrclibService.LrclibUnavailable ignored) {}
        } else {
            // Sin match: guardamos lo que sabemos para que el admin lo complete
            song.setTitle(DeezerService.cleanYoutubeTitle(youtubeTitle));
            song.setArtistName(DeezerService.cleanChannelName(channelTitle));
            song.setCoverUrl(thumbnail);
        }
        return song;
    }

    // ── CRUD del panel ────────────────────────────────────────────────────────

    public List<QuizSong> findAll() {
        return quizSongRepository.findAllByOrderByCreatedAtDesc();
    }

    public QuizSong update(Long id, Map<String, Object> changes) {
        QuizSong song = findById(id);

        if (changes.containsKey("title"))      song.setTitle(asText(changes.get("title")));
        if (changes.containsKey("artistName")) song.setArtistName(asText(changes.get("artistName")));
        if (changes.containsKey("albumTitle")) song.setAlbumTitle(asText(changes.get("albumTitle")));
        if (changes.containsKey("genre"))      song.setGenre(asText(changes.get("genre")));
        if (changes.containsKey("releaseYear"))
            song.setReleaseYear(asInt(changes.get("releaseYear")));
        if (changes.containsKey("durationSec"))
            song.setDurationSec(asInt(changes.get("durationSec")));
        if (changes.containsKey("explicit"))
            song.setExplicit(changes.get("explicit") instanceof Boolean b ? b : null);
        if (changes.containsKey("active") && changes.get("active") instanceof Boolean b)
            song.setActive(b);
        if (changes.containsKey("lyrics")) song.setLyrics(asText(changes.get("lyrics")));
        if (changes.containsKey("emojis")) song.setEmojis(asText(changes.get("emojis")));

        if (song.getTitle() == null || song.getTitle().isBlank())
            throw new RuntimeException("El título no puede quedar vacío");
        if (song.getArtistName() == null || song.getArtistName().isBlank())
            throw new RuntimeException("El artista no puede quedar vacío");

        return quizSongRepository.save(song);
    }

    /**
     * Re-intenta el match en Deezer usando el título/artista actuales
     * (útil después de que el admin corrija una canción incompleta).
     */
    public QuizSong rematch(Long id) {
        QuizSong song = findById(id);

        Optional<DeezerService.DeezerTrack> match =
            deezerService.match(song.getTitle() + " " + song.getArtistName(), song.getArtistName());
        DeezerService.DeezerTrack t = match.orElseThrow(() ->
            new NotFoundException("Deezer no encontró resultados para ese título y artista"));

        song.setTitle(t.getTitle());
        song.setArtistName(t.getArtistName());
        song.setAlbumTitle(t.getAlbumTitle());
        song.setReleaseYear(t.getReleaseYear());
        song.setGenre(t.getGenre());
        song.setDurationSec(t.getDurationSec());
        song.setExplicit(t.getExplicit());
        song.setPreviewUrl(t.getPreviewUrl());
        if (t.getCoverUrl() != null) song.setCoverUrl(t.getCoverUrl());
        song.setDeezerTrackId(t.getTrackId());
        try {
            lrclibService.fetchPlainLyrics(t.getArtistName(), t.getTitle(), t.getDurationSec())
                .ifPresent(song::setLyrics);
        } catch (LrclibService.LrclibUnavailable ignored) {}

        return quizSongRepository.save(song);
    }

    /** Canciones por llamada a fetchMissingLyrics — evita peticiones HTTP eternas. */
    private static final int LYRICS_BATCH = 20;

    /**
     * Busca en lrclib las letras de las canciones matcheadas que aún no la
     * tienen (p. ej. importadas antes de que existiera el modo letra).
     *
     * Procesa como mucho {@link #LYRICS_BATCH} por llamada y devuelve cuántas
     * quedan: el admin pulsa de nuevo hasta llegar a cero. Un miss real se
     * marca con letra vacía "" para no reintentarlo en cada lote (el admin
     * puede pegarla a mano al editar); si lrclib NO RESPONDE, la canción se
     * deja a null para reintentar, y tras 3 fallos seguidos se aborta el lote.
     */
    public Map<String, Object> fetchMissingLyrics() {
        List<QuizSong> pending = quizSongRepository.findMissingLyrics();
        List<QuizSong> batch = pending.size() > LYRICS_BATCH
            ? pending.subList(0, LYRICS_BATCH) : pending;

        int found = 0, notFound = 0, unavailable = 0, consecutiveErrors = 0;

        for (QuizSong song : batch) {
            try {
                Optional<String> lyrics = lrclibService.fetchPlainLyrics(
                    song.getArtistName(), song.getTitle(), song.getDurationSec());
                song.setLyrics(lyrics.orElse(""));
                quizSongRepository.save(song);
                if (lyrics.isPresent()) found++; else notFound++;
                consecutiveErrors = 0;
            } catch (LrclibService.LrclibUnavailable e) {
                unavailable++;
                if (++consecutiveErrors >= 3) break;    // el servicio está caído
            }

            try { Thread.sleep(DeezerService.THROTTLE_MS); }
            catch (InterruptedException e) { Thread.currentThread().interrupt(); break; }
        }

        int processed = found + notFound;
        Map<String, Object> summary = new HashMap<>();
        summary.put("checked",     processed);
        summary.put("found",       found);
        summary.put("unavailable", unavailable);
        summary.put("remaining",   pending.size() - processed);
        return summary;
    }

    /**
     * Genera con Claude los emojis de las canciones que aún no tienen
     * (modo emoji). Procesa un lote por llamada — el admin pulsa de nuevo
     * hasta que remaining llegue a 0 — y guarda solo sugerencias validadas
     * (solo emojis, 2-5). Lo generado es editable en el diálogo de edición.
     */
    public Map<String, Object> suggestMissingEmojis() {
        if (!emojiSuggestService.isConfigured()) {
            throw new RuntimeException(
                "Falta configurar groq.api.key en application.properties. " +
                "Crea una API key gratis en https://console.groq.com/keys y reinicia el backend.");
        }

        List<QuizSong> pending = quizSongRepository.findMissingEmojis();
        List<QuizSong> batch = pending.size() > EmojiSuggestService.BATCH_SIZE
            ? pending.subList(0, EmojiSuggestService.BATCH_SIZE) : pending;

        Map<Long, String> suggestions = emojiSuggestService.suggestForBatch(batch);

        int found = 0;
        for (QuizSong song : batch) {
            // Sin sugerencia válida → "" para no reintentarla en bucle (editable a mano)
            song.setEmojis(suggestions.getOrDefault(song.getId(), ""));
            quizSongRepository.save(song);
            if (suggestions.containsKey(song.getId())) found++;
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("checked",   batch.size());
        summary.put("found",     found);
        summary.put("remaining", pending.size() - batch.size());
        return summary;
    }

    public void delete(Long id) {
        QuizSong song = findById(id);
        try {
            quizSongRepository.delete(song);
            quizSongRepository.flush();
        } catch (Exception e) {
            // FK desde quiz_games/quiz_guesses/quiz_dailies: ya se ha jugado con ella
            throw new ConflictException(
                "La canción ya se ha usado en partidas; desactívala en lugar de borrarla");
        }
    }

    private QuizSong findById(Long id) {
        return quizSongRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("Canción no encontrada en el pool"));
    }

    private static String asText(Object o) {
        if (o == null) return null;
        String s = o.toString().trim();
        return s.isEmpty() ? null : s;
    }

    private static Integer asInt(Object o) {
        if (o instanceof Number n) return n.intValue();
        if (o instanceof String s && !s.isBlank()) {
            try { return Integer.parseInt(s.trim()); } catch (NumberFormatException ignored) {}
        }
        return null;
    }
}
