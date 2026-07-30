package com.example.viber.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import lombok.Data;

/**
 * Cliente de la API pública de Deezer (https://api.deezer.com).
 * No requiere API key ni OAuth para datos de catálogo.
 *
 * Se usa para enriquecer las canciones del quiz con metadata estructurada que
 * YouTube no da: artista real, álbum, año, género, duración, explícito,
 * portada y preview MP3 de 30 s (modo audio).
 *
 * Límite de Deezer: 50 peticiones / 5 s por IP. El import duerme entre
 * canciones (ver THROTTLE_MS) para no superarlo.
 */
@Service
public class DeezerService {

    private static final String API = "https://api.deezer.com";

    /** Pausa entre canciones durante un import (hasta 3 llamadas por canción). */
    public static final long THROTTLE_MS = 350;

    // Con timeouts: una petición colgada no puede bloquear un import entero
    private final RestTemplate restTemplate = buildRestTemplate();

    private static RestTemplate buildRestTemplate() {
        org.springframework.http.client.SimpleClientHttpRequestFactory factory =
            new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(10_000);
        return new RestTemplate(factory);
    }

    /** Cache género por álbum: muchas canciones comparten álbum y el género no cambia. */
    private final Map<Long, String> albumGenreCache = new ConcurrentHashMap<>();

    // ── Resultado del matching ────────────────────────────────────────────────

    @Data
    public static class DeezerTrack {
        private Long trackId;
        private String title;
        private String artistName;
        private String albumTitle;
        private Integer releaseYear;
        private String genre;
        private Integer durationSec;
        private Boolean explicit;
        private String previewUrl;
        private String coverUrl;
    }

    // ── Matching título de YouTube → track de Deezer ──────────────────────────

    /**
     * Intenta encontrar en Deezer la canción correspondiente a un vídeo de YouTube.
     *
     * Estrategia: limpiar el título (quitar "(Official Video)" etc.), intentar el
     * patrón "Artista - Título" con búsqueda estricta de Deezer, y si no, búsqueda
     * libre con el canal como pista. El resultado se valida por solapamiento de
     * tokens para descartar matches absurdos.
     */
    public Optional<DeezerTrack> match(String youtubeTitle, String channelTitle) {
        String cleanTitle   = cleanYoutubeTitle(youtubeTitle);
        String cleanChannel = cleanChannelName(channelTitle);

        Map<String, Object> best = null;

        // 1) Patrón "Artista - Título" → búsqueda estricta artist:"..." track:"..."
        int dash = cleanTitle.indexOf(" - ");
        if (dash > 0) {
            String artistPart = cleanTitle.substring(0, dash).trim();
            String trackPart  = cleanTitle.substring(dash + 3).trim();
            best = firstResult(String.format("artist:\"%s\" track:\"%s\"", artistPart, trackPart));
        }

        // 2) Búsqueda libre: título limpio + canal (el canal suele ser el artista)
        if (best == null && !cleanChannel.isBlank()) {
            best = firstResult(cleanTitle + " " + cleanChannel);
        }

        // 3) Último recurso: solo el título limpio
        if (best == null) {
            best = firstResult(cleanTitle);
        }

        if (best == null) return Optional.empty();

        DeezerTrack track = fromSearchItem(best);

        // Validación: el match debe parecerse a lo que dice YouTube
        if (!looksLikeSameSong(track, youtubeTitle, channelTitle)) {
            return Optional.empty();
        }

        enrich(track);
        return Optional.of(track);
    }

    // ── Llamadas a la API ─────────────────────────────────────────────────────

    /** GET /search?q=... — devuelve el primer resultado o null. */
    @SuppressWarnings("unchecked")
    private Map<String, Object> firstResult(String query) {
        try {
            String url = API + "/search?limit=3&q=" +
                URLEncoder.encode(query, StandardCharsets.UTF_8);
            Map<String, Object> response = restTemplate.getForObject(url, Map.class);
            if (response == null || !(response.get("data") instanceof List<?> data) || data.isEmpty()) {
                return null;
            }
            return (Map<String, Object>) data.get(0);
        } catch (Exception e) {
            return null;
        }
    }

    /** Convierte un ítem de /search en DeezerTrack (sin año ni género todavía). */
    @SuppressWarnings("unchecked")
    private DeezerTrack fromSearchItem(Map<String, Object> item) {
        DeezerTrack t = new DeezerTrack();
        t.setTrackId(asLong(item.get("id")));
        // title_short viene sin coletillas tipo "(Remastered 2011)" — mejor para el juego
        String title = (String) item.get("title_short");
        if (title == null || title.isBlank()) title = (String) item.get("title");
        t.setTitle(title);
        t.setDurationSec(asInt(item.get("duration")));
        t.setExplicit(Boolean.TRUE.equals(item.get("explicit_lyrics")));
        t.setPreviewUrl(emptyToNull((String) item.get("preview")));

        Map<String, Object> artist = (Map<String, Object>) item.get("artist");
        if (artist != null) t.setArtistName((String) artist.get("name"));

        Map<String, Object> album = (Map<String, Object>) item.get("album");
        if (album != null) {
            t.setAlbumTitle((String) album.get("title"));
            String cover = (String) album.get("cover_medium");
            if (cover == null) cover = (String) album.get("cover");
            t.setCoverUrl(emptyToNull(cover));
        }
        return t;
    }

    /**
     * Completa año y género con dos llamadas extra:
     * /track/{id} → release_date + id del álbum; /album/{id} → género (cacheado).
     */
    @SuppressWarnings("unchecked")
    private void enrich(DeezerTrack track) {
        if (track.getTrackId() == null) return;
        try {
            Map<String, Object> full = restTemplate.getForObject(
                API + "/track/" + track.getTrackId(), Map.class);
            if (full == null) return;

            String releaseDate = (String) full.get("release_date");
            if (releaseDate != null && releaseDate.length() >= 4) {
                try {
                    track.setReleaseYear(Integer.parseInt(releaseDate.substring(0, 4)));
                } catch (NumberFormatException ignored) {}
            }

            Map<String, Object> album = (Map<String, Object>) full.get("album");
            Long albumId = album != null ? asLong(album.get("id")) : null;
            if (albumId != null) {
                track.setGenre(albumGenre(albumId));
            }
        } catch (Exception ignored) {
            // Sin año/género el admin puede completarlos a mano; no rompemos el import
        }
    }

    /** Género principal de un álbum, con cache en memoria ("" = consultado sin género). */
    @SuppressWarnings("unchecked")
    private String albumGenre(Long albumId) {
        String genre = albumGenreCache.computeIfAbsent(albumId, id -> {
            try {
                Map<String, Object> album = restTemplate.getForObject(
                    API + "/album/" + id, Map.class);
                if (album == null) return "";
                Map<String, Object> genres = (Map<String, Object>) album.get("genres");
                if (genres != null && genres.get("data") instanceof List<?> data && !data.isEmpty()) {
                    String name = (String) ((Map<String, Object>) data.get(0)).get("name");
                    return name != null ? name : "";
                }
                return "";
            } catch (Exception e) {
                return "";
            }
        });
        return genre.isBlank() ? null : genre;
    }

    // ── Preview fresco ────────────────────────────────────────────────────────

    /**
     * Las URLs de preview de Deezer van firmadas y CADUCAN (~15-20 min, parámetro
     * hdnea/exp). La URL guardada al importar solo sirve como flag "tiene preview";
     * para reproducir hay que pedir una fresca con el ID del track.
     */
    @SuppressWarnings("unchecked")
    public Optional<String> freshPreviewUrl(Long trackId) {
        if (trackId == null) return Optional.empty();
        try {
            Map<String, Object> track = restTemplate.getForObject(
                API + "/track/" + trackId, Map.class);
            if (track == null) return Optional.empty();
            return Optional.ofNullable(emptyToNull((String) track.get("preview")));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    // ── Artistas: id, relacionados y top tracks (recomendación / auto-DJ) ──────

    /**
     * Busca el id de Deezer de un artista por nombre. Necesario porque los
     * endpoints de relacionados y top tracks van por id, no por nombre.
     */
    @SuppressWarnings("unchecked")
    public Optional<Long> searchArtistId(String name) {
        if (name == null || name.isBlank()) return Optional.empty();
        try {
            String url = API + "/search/artist?limit=1&q=" +
                URLEncoder.encode(name, StandardCharsets.UTF_8);
            Map<String, Object> response = restTemplate.getForObject(url, Map.class);
            if (response == null || !(response.get("data") instanceof List<?> data) || data.isEmpty()) {
                return Optional.empty();
            }
            return Optional.ofNullable(asLong(((Map<String, Object>) data.get(0)).get("id")));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    /** /artist/{id}/related → nombres de artistas parecidos (grafo musical de Deezer). */
    @SuppressWarnings("unchecked")
    public List<String> relatedArtists(Long artistId) {
        if (artistId == null) return List.of();
        try {
            Map<String, Object> response = restTemplate.getForObject(
                API + "/artist/" + artistId + "/related", Map.class);
            return extractNames(response);
        } catch (Exception e) {
            return List.of();
        }
    }

    /** /artist/{id}/top → títulos de las canciones más escuchadas del artista. */
    @SuppressWarnings("unchecked")
    public List<String> topTrackTitles(Long artistId, int limit) {
        if (artistId == null) return List.of();
        try {
            Map<String, Object> response = restTemplate.getForObject(
                API + "/artist/" + artistId + "/top?limit=" + Math.max(1, limit), Map.class);
            if (response == null || !(response.get("data") instanceof List<?> data)) return List.of();
            List<String> titles = new ArrayList<>();
            for (Object o : data) {
                if (!(o instanceof Map<?, ?>)) continue;
                Map<String, Object> m = (Map<String, Object>) o;
                String t = (String) m.get("title_short");
                if (t == null || t.isBlank()) t = (String) m.get("title");
                if (t != null && !t.isBlank()) titles.add(t);
            }
            return titles;
        } catch (Exception e) {
            return List.of();
        }
    }

    /** Extrae la lista de nombres ("name") del array "data" de una respuesta de Deezer. */
    @SuppressWarnings("unchecked")
    private static List<String> extractNames(Map<String, Object> response) {
        if (response == null || !(response.get("data") instanceof List<?> data)) return List.of();
        List<String> names = new ArrayList<>();
        for (Object o : data) {
            if (!(o instanceof Map<?, ?>)) continue;
            String name = (String) ((Map<String, Object>) o).get("name");
            if (name != null && !name.isBlank()) names.add(name);
        }
        return names;
    }

    // ── Limpieza de títulos de YouTube ────────────────────────────────────────

    private static final Pattern BRACKETS  = Pattern.compile("[(\\[{][^)\\]}]*[)\\]}]");
    private static final Pattern NOISE     = Pattern.compile(
        "(?i)\\b(official|video|oficial|videoclip|lyric[s]?|letra|audio|visualizer|" +
        "hd|4k|mv|m/v|remaster(ed)?|videolyric|clip)\\b");
    private static final Pattern SEPARATOR_TAIL = Pattern.compile("[|•].*$");
    private static final Pattern MULTI_SPACE    = Pattern.compile("\\s{2,}");

    /**
     * "Queen – Bohemian Rhapsody (Official Video Remastered)" → "Queen - Bohemian Rhapsody".
     * Quita paréntesis/corchetes, palabras de relleno, colas tras "|" y comillas.
     */
    public static String cleanYoutubeTitle(String raw) {
        if (raw == null) return "";
        String s = raw;
        s = s.replace('–', '-').replace('—', '-');          // guiones tipográficos
        s = BRACKETS.matcher(s).replaceAll(" ");
        s = SEPARATOR_TAIL.matcher(s).replaceAll(" ");
        s = NOISE.matcher(s).replaceAll(" ");
        s = s.replace("\"", " ").replace('’', '\'');   // ’ tipográfico → apóstrofo normal
        s = MULTI_SPACE.matcher(s).replaceAll(" ").trim();
        // Guion suelto al final ("Artista - " tras limpiar) → fuera
        s = s.replaceAll("\\s*-\\s*$", "").replaceAll("^\\s*-\\s*", "").trim();
        return s;
    }

    /** "QueenVEVO" → "Queen", "Dua Lipa - Topic" → "Dua Lipa". */
    public static String cleanChannelName(String channel) {
        if (channel == null) return "";
        return channel
            .replaceAll("(?i)\\s*-\\s*topic$", "")
            .replaceAll("(?i)vevo$", "")
            .replaceAll("(?i)\\bofficial\\b", "")
            .trim();
    }

    // ── Validación del match ──────────────────────────────────────────────────

    /**
     * Acepta el match si al menos la mitad de los tokens del título de Deezer
     * aparecen en el título del vídeo, o si el artista de Deezer aparece en el
     * título o el canal de YouTube.
     */
    private boolean looksLikeSameSong(DeezerTrack track, String youtubeTitle, String channelTitle) {
        if (track.getTitle() == null || track.getArtistName() == null) return false;

        String haystack = normalize(youtubeTitle + " " + channelTitle);
        Set<String> deezerTokens = tokens(track.getTitle());
        if (deezerTokens.isEmpty()) return false;

        long found = deezerTokens.stream().filter(haystack::contains).count();
        boolean titleOverlap  = found * 2 >= deezerTokens.size();
        boolean artistPresent = haystack.contains(normalize(track.getArtistName()));

        return titleOverlap && (artistPresent || found == deezerTokens.size());
    }

    private static String normalize(String s) {
        if (s == null) return "";
        return java.text.Normalizer.normalize(s.toLowerCase(Locale.ROOT), java.text.Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "")           // sin tildes
            .replaceAll("[^a-z0-9 ]", " ");
    }

    private static Set<String> tokens(String s) {
        Set<String> set = new HashSet<>(Arrays.asList(normalize(s).split("\\s+")));
        set.removeIf(t -> t.length() < 2);      // fuera "a", "y", restos
        return set;
    }

    // ── Helpers de parseo ─────────────────────────────────────────────────────

    private static Long asLong(Object o) {
        return o instanceof Number n ? n.longValue() : null;
    }

    private static Integer asInt(Object o) {
        return o instanceof Number n ? n.intValue() : null;
    }

    private static String emptyToNull(String s) {
        return (s == null || s.isBlank()) ? null : s;
    }
}
