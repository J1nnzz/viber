package com.example.viber.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.model.ListenEvent;
import com.example.viber.model.TrackMetadata;
import com.example.viber.model.User;
import com.example.viber.repository.ListenEventRepository;
import com.example.viber.repository.UserRepository;

/**
 * Construye el "perfil de gusto" como vectores de géneros y artistas ponderados
 * por RECENCIA (Pieza 2 y 3 del sistema).
 *
 * La clave es el decaimiento temporal: cada reproducción aporta
 * <pre>peso = 0.5 ^ (edad_en_días / vida_media)</pre>
 * de modo que una escucha de hoy vale 1.0, la de hace una vida media vale 0.5, y
 * la de hace meses tiende a 0. Así, alguien que lleva dos semanas con el rock pero
 * un año con hip-hop tendrá el rock por delante — sin IA, solo ponderación, y la
 * agresividad se controla con {@code reco.half-life-days}.
 *
 * El género NO vive en {@link ListenEvent}: se resuelve cruzando el videoId con
 * {@link TrackMetadata} (que se enriquece async), así que los perfiles mejoran
 * solos a medida que el catálogo se va completando.
 */
@Service
public class TasteProfileService {

    @Autowired private ListenEventRepository listenEventRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private TrackMetadataService trackMetadataService;

    /** Vida media del decaimiento (días). 14 ≈ "las últimas 2-3 semanas mandan". */
    @Value("${reco.half-life-days:14}")
    private double halfLifeDays;

    /** Solo se miran eventos más recientes que esto: lo anterior ya pesa ~0. */
    @Value("${reco.window-days:120}")
    private int windowDays;

    // ── Registro de eventos ─────────────────────────────────────────────────────

    /**
     * Registra que {@code videoId} sonó en {@code roomId} para cada oyente online.
     * Un evento por oyente alimenta su gusto; la huella de la sala deduplica luego
     * por canción para no sesgarse por cuánta gente había.
     */
    @Transactional
    public void recordPlay(Set<String> listeners, Long roomId, String videoId, String artist) {
        if (videoId == null || videoId.isBlank() || listeners == null || listeners.isEmpty()) return;

        for (String username : listeners) {
            User user = userRepository.findByUsername(username).orElse(null);
            if (user == null) continue;

            ListenEvent event = new ListenEvent();
            event.setUser(user);
            event.setRoomId(roomId);
            event.setVideoId(videoId);
            event.setArtist(artist);
            listenEventRepository.save(event);
        }
    }

    // ── Perfiles ────────────────────────────────────────────────────────────────

    /** Gusto del usuario: vectores género/artista ponderados por recencia. */
    @Transactional(readOnly = true)
    public Profile userProfile(User user) {
        LocalDateTime since = LocalDateTime.now().minusDays(windowDays);
        List<ListenEvent> events = listenEventRepository.findByUserAndPlayedAtAfter(user, since);
        return build(events, false);
    }

    /** Huella de la sala: igual, pero deduplicando por canción (sin sesgo de aforo). */
    @Transactional(readOnly = true)
    public Profile roomProfile(Long roomId) {
        LocalDateTime since = LocalDateTime.now().minusDays(windowDays);
        List<ListenEvent> events = listenEventRepository.findByRoomIdAndPlayedAtAfter(roomId, since);
        return build(events, true);
    }

    /**
     * Agrega eventos en vectores ponderados.
     *
     * @param dedupeByVideo si true, cada canción cuenta una sola vez (su play más
     *                      reciente) — para la huella de sala, que no debe inflarse
     *                      por el número de oyentes.
     */
    private Profile build(List<ListenEvent> events, boolean dedupeByVideo) {
        if (events.isEmpty()) return Profile.empty();

        if (dedupeByVideo) {
            Map<String, ListenEvent> latest = new HashMap<>();
            for (ListenEvent e : events) {
                ListenEvent prev = latest.get(e.getVideoId());
                if (prev == null || e.getPlayedAt().isAfter(prev.getPlayedAt())) {
                    latest.put(e.getVideoId(), e);
                }
            }
            events = List.copyOf(latest.values());
        }

        Map<String, TrackMetadata> meta = trackMetadataService.findByVideoIds(
            events.stream().map(ListenEvent::getVideoId).collect(Collectors.toSet()));

        LocalDateTime now = LocalDateTime.now();
        Map<String, Double> genres = new HashMap<>();
        Map<String, Double> artists = new HashMap<>();

        for (ListenEvent e : events) {
            double w = decayWeight(e.getPlayedAt(), now);
            if (w <= 0.0001) continue;

            TrackMetadata tm = meta.get(e.getVideoId());

            String genre = tm != null ? tm.getGenre() : null;
            if (genre != null && !genre.isBlank()) {
                genres.merge(genre.toLowerCase(), w, Double::sum);
            }

            String artist = (tm != null && tm.getArtist() != null) ? tm.getArtist() : e.getArtist();
            if (artist != null && !artist.isBlank()) {
                artists.merge(artist.toLowerCase(), w, Double::sum);
            }
        }

        return new Profile(genres, artists);
    }

    /** peso = 0.5 ^ (edad_en_días / vida_media). */
    private double decayWeight(LocalDateTime playedAt, LocalDateTime now) {
        if (playedAt == null) return 0.0;
        double ageDays = Duration.between(playedAt, now).toSeconds() / 86_400.0;
        if (ageDays < 0) ageDays = 0;
        return Math.pow(0.5, ageDays / halfLifeDays);
    }

    // ── Modelo + utilidades de similitud ────────────────────────────────────────

    /** Vectores de gusto. Inmutable de facto: solo se lee tras construirse. */
    public static class Profile {
        private final Map<String, Double> genres;
        private final Map<String, Double> artists;

        public Profile(Map<String, Double> genres, Map<String, Double> artists) {
            this.genres = genres;
            this.artists = artists;
        }

        public static Profile empty() {
            return new Profile(Map.of(), Map.of());
        }

        public Map<String, Double> getGenres() { return genres; }
        public Map<String, Double> getArtists() { return artists; }

        public boolean isEmpty() {
            return genres.isEmpty() && artists.isEmpty();
        }

        /** Géneros/artistas ordenados de mayor a menor peso (para mostrar o sembrar). */
        public List<String> topGenres(int n) { return top(genres, n); }
        public List<String> topArtists(int n) { return top(artists, n); }

        private static List<String> top(Map<String, Double> m, int n) {
            return m.entrySet().stream()
                .sorted(Map.Entry.<String, Double>comparingByValue().reversed())
                .limit(n)
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());
        }
    }

    /** Similitud coseno entre dos vectores dispersos (0 = nada en común, 1 = idénticos). */
    public static double cosine(Map<String, Double> a, Map<String, Double> b) {
        if (a == null || b == null || a.isEmpty() || b.isEmpty()) return 0.0;
        Map<String, Double> small = a.size() <= b.size() ? a : b;
        Map<String, Double> big = small == a ? b : a;

        double dot = 0.0;
        for (Map.Entry<String, Double> e : small.entrySet()) {
            Double other = big.get(e.getKey());
            if (other != null) dot += e.getValue() * other;
        }
        if (dot == 0.0) return 0.0;

        double normA = norm(a);
        double normB = norm(b);
        return (normA == 0 || normB == 0) ? 0.0 : dot / (normA * normB);
    }

    private static double norm(Map<String, Double> v) {
        double sum = 0.0;
        for (double x : v.values()) sum += x * x;
        return Math.sqrt(sum);
    }
}
