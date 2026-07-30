package com.example.viber.service;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.example.viber.dto.RoomListEvent;
import com.example.viber.dto.RoomMessage;
import com.example.viber.dto.RoomResponse;
import com.example.viber.model.Room;
import com.example.viber.model.RoomState;
import com.example.viber.model.YoutubeResolution;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.YoutubeResolutionRepository;

/**
 * Auto-DJ de salas permanentes (Pieza 4b): cuando una sala con auto-DJ encendido
 * y oyentes online se queda corta de cola, le añade una canción afín a lo que ya
 * ha sonado — manteniendo el estilo ("si se añadió Drake, sigue Drake; si era pop,
 * sigue pop") pero con variedad gracias al grafo de similares.
 *
 * Flujo de un relleno:
 *   1. Elige un artista semilla entre lo reproducido recientemente en la sala.
 *   2. Decide continuidad (mismo artista) vs descubrimiento (uno similar).
 *   3. Convierte ese artista en canciones reales (Deezer top tracks).
 *   4. Las resuelve a un videoId de YouTube — con CACHÉ para no gastar cuota.
 *   5. Encola reusando la misma mecánica que un usuario (applyMessage + broadcast).
 *
 * Presupuesto de cuota: como mucho UNA búsqueda en vivo de YouTube por relleno;
 * el resto sale de la caché. Solo rellena salas con gente dentro para no malgastar.
 */
@Service
public class AutoDjService {

    private static final String AUTO_DJ_USER = "auto-dj";

    @Autowired private RoomRepository roomRepository;
    @Autowired private RoomStateService roomStateService;
    @Autowired private TasteProfileService tasteProfileService;
    @Autowired private SimilarArtistService similarArtistService;
    @Autowired private YoutubeService youtubeService;
    @Autowired private YoutubeResolutionRepository resolutionRepo;
    @Autowired private SimpMessagingTemplate messagingTemplate;

    /** Rellena si la cola tiene menos de esto (contando lo que suena aparte). */
    @Value("${autodj.min-queue:2}")
    private int minQueue;

    /** Probabilidad de seguir con el MISMO artista (continuidad) vs descubrir uno similar. */
    @Value("${autodj.same-artist-probability:0.5}")
    private double sameArtistProbability;

    // ── Tick programado ─────────────────────────────────────────────────────────

    /**
     * Revisa periódicamente las salas auto-DJ. fixedDelay (no fixedRate) para no
     * solapar ticks si uno tarda; el intervalo se puede ajustar por property.
     */
    @Scheduled(fixedDelayString = "${autodj.scan-interval-ms:20000}")
    public void refillTick() {
        for (Room room : roomRepository.findByAutoDjTrueAndActiveTrue()) {
            try {
                RoomState state = roomStateService.getState(room.getId());
                if (state == null) continue;                       // sala sin estado vivo
                if (state.getOnlineUsers().isEmpty()) continue;    // nadie escuchando → no gastar cuota
                if (state.getQueue().size() >= minQueue) continue; // cola suficiente
                refill(room, state);
            } catch (Exception e) {
                // Una sala que falle no debe tumbar el tick de las demás
            }
        }
    }

    // ── Relleno de una sala ───────────────────────────────────────────────────

    private void refill(Room room, RoomState state) {
        Set<String> played = playedVideoIds(state);
        String artist = chooseArtist(room, state);
        if (artist == null) return;

        List<String> titles = new ArrayList<>(similarArtistService.topTracksForArtist(artist, 15));
        if (titles.isEmpty()) titles.add("");   // sin top tracks: buscaremos solo por el artista
        Collections.shuffle(titles);

        // 1) Cache-first: candidatos ya resueltos antes (coste de cuota = 0)
        for (String title : titles) {
            String key = queryKey(artist, title);
            YoutubeResolution r = resolutionRepo.findById(key).orElse(null);
            if (r != null && r.getVideoId() != null && !played.contains(r.getVideoId())) {
                enqueue(room, state, r);
                return;
            }
        }

        // 2) Una sola búsqueda en vivo, sobre el primer candidato aún no cacheado
        for (String title : titles) {
            String key = queryKey(artist, title);
            if (resolutionRepo.existsById(key)) continue;   // ya conocido (resultado o callejón sin salida)
            YoutubeResolution r = liveSearch(artist, title, key);
            if (r != null && r.getVideoId() != null && !played.contains(r.getVideoId())) {
                enqueue(room, state, r);
            }
            return;   // presupuesto agotado: una búsqueda por tick, gane o no
        }
    }

    /** Búsqueda real en YouTube + guardado en caché (incluido el "sin resultado"). */
    private YoutubeResolution liveSearch(String artist, String title, String key) {
        String query = title.isBlank() ? artist : artist + " " + title;
        YoutubeResolution entry = new YoutubeResolution();
        entry.setQueryKey(key);
        entry.setResolvedAt(java.time.LocalDateTime.now());
        try {
            List<Map<String, String>> results = youtubeService.search(query);
            if (!results.isEmpty()) {
                Map<String, String> first = results.get(0);
                entry.setVideoId(first.get("videoId"));
                entry.setTitle(first.get("title"));
                entry.setThumbnail(first.get("thumbnail"));
                entry.setChannel(first.get("channel"));
            }
        } catch (Exception e) {
            // Búsqueda fallida: guardamos el "sin resultado" para no reintentar en bucle
        }
        try {
            resolutionRepo.save(entry);
        } catch (Exception ignore) { /* carrera */ }
        return entry;
    }

    /** Encola el vídeo reusando la mecánica de cola normal (arranque automático incluido). */
    private void enqueue(Room room, RoomState state, YoutubeResolution r) {
        RoomMessage msg = new RoomMessage();
        msg.setType(RoomMessage.Type.QUEUE_ADD);
        msg.setVideoId(r.getVideoId());
        msg.setVideoTitle(r.getTitle());
        msg.setVideoThumbnail(r.getThumbnail());
        msg.setVideoChannel(r.getChannel());
        msg.setSenderUsername(AUTO_DJ_USER);
        msg.setServerTimestamp(System.currentTimeMillis());

        // applyMessage puede mutar el tipo a PLAY si la sala estaba parada (arranque automático)
        roomStateService.applyMessage(room.getId(), msg);
        messagingTemplate.convertAndSend("/topic/room." + room.getId(), msg);

        // Si arrancó la reproducción, refrescar la tarjeta en el listado de salas
        if (msg.getType() == RoomMessage.Type.PLAY && "PUBLIC".equals(room.getPrivacy())) {
            RoomListEvent event = new RoomListEvent();
            event.setType(RoomListEvent.Type.ROOM_UPDATED);
            event.setRoomId(room.getId());
            event.setRoom(RoomResponse.from(room, state));
            messagingTemplate.convertAndSend("/topic/rooms", event);
        }
    }

    // ── Elección del artista semilla ────────────────────────────────────────────

    /**
     * Elige a quién parecerse: parte de los artistas sonados recientemente en la
     * sala y, según {@code sameArtistProbability}, sigue con ese mismo o salta a uno
     * similar. Si la sala no ha sonado nada aún, cae a un género declarado.
     */
    private String chooseArtist(Room room, RoomState state) {
        List<String> recent = recentArtists(state);

        if (!recent.isEmpty()) {
            String base = recent.get(ThreadLocalRandom.current().nextInt(Math.min(3, recent.size())));
            if (ThreadLocalRandom.current().nextDouble() < sameArtistProbability) {
                return base;   // continuidad: más del mismo artista
            }
            List<String> similar = similarArtistService.similarArtists(base);
            if (similar.isEmpty()) return base;
            int span = Math.min(10, similar.size());
            return similar.get(ThreadLocalRandom.current().nextInt(span));
        }

        // Cold start: sin historial, sembramos por un género declarado de la sala
        if (room.getGenres() != null && !room.getGenres().isBlank()) {
            String[] genres = room.getGenres().split(",");
            String g = genres[ThreadLocalRandom.current().nextInt(genres.length)].trim();
            return g.isEmpty() ? null : g;
        }
        return null;
    }

    /** Artistas (canales limpios) sonados en la sala, más recientes primero, sin duplicados. */
    private List<String> recentArtists(RoomState state) {
        LinkedHashSet<String> ordered = new LinkedHashSet<>();
        addArtist(ordered, state.getCurrentVideoChannel());
        List<RoomState.QueueItem> history = state.getHistory();
        for (int i = history.size() - 1; i >= 0; i--) {
            addArtist(ordered, history.get(i).getChannelTitle());
        }
        for (RoomState.QueueItem q : state.getQueue()) {
            addArtist(ordered, q.getChannelTitle());
        }
        return new ArrayList<>(ordered);
    }

    private void addArtist(LinkedHashSet<String> set, String channel) {
        String clean = DeezerService.cleanChannelName(channel);
        if (clean != null && !clean.isBlank()) set.add(clean);
    }

    private Set<String> playedVideoIds(RoomState state) {
        Set<String> ids = new java.util.HashSet<>();
        if (state.getCurrentVideoId() != null) ids.add(state.getCurrentVideoId());
        for (RoomState.QueueItem q : state.getQueue()) ids.add(q.getVideoId());
        for (RoomState.QueueItem h : state.getHistory()) ids.add(h.getVideoId());
        return ids;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String queryKey(String artist, String title) {
        String raw = (title == null || title.isBlank()) ? artist : artist + " " + title;
        String norm = Normalizer.normalize(raw.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "")
            .replaceAll("\\s+", " ")
            .trim();
        return norm.length() > 200 ? norm.substring(0, 200) : norm;
    }
}
