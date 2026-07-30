package com.example.viber.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.dto.GenreStat;
import com.example.viber.dto.UserStatsResponse;
import com.example.viber.model.ArtistPlayCount;
import com.example.viber.model.Room;
import com.example.viber.model.RoomVisit;
import com.example.viber.model.User;
import com.example.viber.model.UserStatsTotals;
import com.example.viber.repository.ArtistPlayCountRepository;
import com.example.viber.repository.LikedSongRepository;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.RoomVisitRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.repository.UserStatsTotalsRepository;

/**
 * Calcula y registra las estadísticas de perfil: tiempo escuchado, salas
 * creadas/unidas, canciones añadidas/escuchadas y géneros/artistas más escuchados.
 *
 * El tiempo de escucha se acumula con sesiones en memoria (username -> inicio en ms),
 * de forma análoga a como PresenceService rastrea la sala actual de cada usuario.
 */
@Service
public class UserStatsService {

    @Autowired private UserRepository            userRepository;
    @Autowired private RoomRepository            roomRepository;
    @Autowired private RoomVisitRepository       roomVisitRepository;
    @Autowired private UserStatsTotalsRepository userStatsTotalsRepository;
    @Autowired private ArtistPlayCountRepository artistPlayCountRepository;
    @Autowired private LikedSongRepository       likedSongRepository;

    // username -> timestamp (ms) de inicio de la sesión de escucha actual
    private final Map<String, Long> activeSessions = new ConcurrentHashMap<>();

    // ── Consulta agregada ─────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public UserStatsResponse getStats(User user) {
        long roomsCreated    = roomRepository.countByHost(user);
        long roomsJoined     = roomVisitRepository.countByUser(user);
        long likedSongsCount = likedSongRepository.countByUser(user);

        UserStatsTotals totals = userStatsTotalsRepository.findById(user.getId())
            .orElseGet(() -> emptyTotals(user));

        List<GenreStat> topGenres = computeTopGenres(user);
        List<GenreStat> topArtists = artistPlayCountRepository
            .findTop5ByUserOrderByPlayCountDesc(user)
            .stream()
            .map(a -> new GenreStat(a.getArtistName(), a.getPlayCount()))
            .collect(Collectors.toList());

        return new UserStatsResponse(
            roomsCreated,
            roomsJoined,
            totals.getTotalListenSeconds(),
            topGenres,
            topArtists,
            totals.getSongsAdded(),
            totals.getSongsPlayed(),
            likedSongsCount
        );
    }

    private List<GenreStat> computeTopGenres(User user) {
        Map<String, Integer> tally = new HashMap<>();

        for (Room room : roomRepository.findByHost(user)) {
            tallyGenres(tally, room.getGenres());
        }
        for (RoomVisit visit : roomVisitRepository.findByUser(user)) {
            tallyGenres(tally, visit.getRoom().getGenres());
        }

        return tally.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
            .limit(5)
            .map(e -> new GenreStat(e.getKey(), e.getValue()))
            .collect(Collectors.toList());
    }

    private void tallyGenres(Map<String, Integer> tally, String genresCsv) {
        if (genresCsv == null || genresCsv.isBlank()) return;
        for (String genre : genresCsv.split(",")) {
            String name = genre.trim();
            if (name.isEmpty()) continue;
            tally.merge(name, 1, Integer::sum);
        }
    }

    // ── Registro de eventos ───────────────────────────────────────────────────

    /** Registra que un usuario se ha conectado a una sala ajena (su propia sala no cuenta). */
    @Transactional
    public void recordRoomVisit(String username, Long roomId) {
        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null) return;

        Room room = roomRepository.findById(roomId).orElse(null);
        if (room == null) return;

        if (room.getHost().getId().equals(user.getId())) return;
        if (roomVisitRepository.existsByUserAndRoom(user, room)) return;

        RoomVisit visit = new RoomVisit();
        visit.setUser(user);
        visit.setRoom(room);
        roomVisitRepository.save(visit);
    }

    /** Incrementa el contador de canciones añadidas a la cola por el usuario. */
    @Transactional
    public void recordSongAdded(String username) {
        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null) return;

        UserStatsTotals totals = getOrCreateTotals(user);
        totals.setSongsAdded(totals.getSongsAdded() + 1);
        userStatsTotalsRepository.save(totals);
    }

    /**
     * Por cada oyente online, incrementa "canciones escuchadas" y, si se conoce
     * el artista/canal, su tally de reproducciones por artista.
     */
    @Transactional
    public void recordSongPlayed(Set<String> listeners, String artistName) {
        if (listeners == null || listeners.isEmpty()) return;

        for (String username : listeners) {
            User user = userRepository.findByUsername(username).orElse(null);
            if (user == null) continue;

            UserStatsTotals totals = getOrCreateTotals(user);
            totals.setSongsPlayed(totals.getSongsPlayed() + 1);
            userStatsTotalsRepository.save(totals);

            if (artistName != null && !artistName.isBlank()) {
                ArtistPlayCount apc = artistPlayCountRepository
                    .findByUserAndArtistName(user, artistName)
                    .orElseGet(() -> {
                        ArtistPlayCount n = new ArtistPlayCount();
                        n.setUser(user);
                        n.setArtistName(artistName);
                        return n;
                    });
                apc.setPlayCount(apc.getPlayCount() + 1);
                artistPlayCountRepository.save(apc);
            }
        }
    }

    private UserStatsTotals getOrCreateTotals(User user) {
        return userStatsTotalsRepository.findById(user.getId())
            .orElseGet(() -> emptyTotals(user));
    }

    private UserStatsTotals emptyTotals(User user) {
        UserStatsTotals totals = new UserStatsTotals();
        totals.setUserId(user.getId());
        return totals;
    }

    // ── Sesiones de escucha ────────────────────────────────────────────────────

    /** Marca el inicio de una sesión de escucha. Si ya había una abierta, la cierra antes. */
    public void startListenSession(String username) {
        if (activeSessions.containsKey(username)) {
            endListenSession(username);
        }
        activeSessions.put(username, System.currentTimeMillis());
    }

    /** Cierra la sesión de escucha y acumula el tiempo transcurrido en user_stats. */
    @Transactional
    public void endListenSession(String username) {
        Long start = activeSessions.remove(username);
        if (start == null) return;

        long seconds = (System.currentTimeMillis() - start) / 1000;
        if (seconds <= 0) return;

        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null) return;

        UserStatsTotals totals = getOrCreateTotals(user);
        totals.setTotalListenSeconds(totals.getTotalListenSeconds() + seconds);
        userStatsTotalsRepository.save(totals);
    }

    /** Cierra las sesiones de escucha de todos los usuarios indicados (cierre de sala). */
    @Transactional
    public void endSessions(Set<String> usernames) {
        if (usernames == null) return;
        for (String username : usernames) {
            endListenSession(username);
        }
    }
}
