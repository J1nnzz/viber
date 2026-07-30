package com.example.viber.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.dto.RoomResponse;
import com.example.viber.model.Room;
import com.example.viber.model.RoomState;
import com.example.viber.model.User;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.UserRepository;

/**
 * Recomendación de salas por contenido (Pieza 4a): ordena las salas públicas
 * activas por su afinidad con el gusto del usuario.
 *
 * Es 100% determinista y explicable: representa al usuario y a cada sala como
 * vectores de géneros/artistas y los compara con similitud coseno. No usa datos
 * de otros usuarios (nada de filtrado colaborativo), así que funciona desde el
 * primer usuario y no sufre cold-start a nivel de producto.
 *
 * Para usuarios nuevos (perfil vacío) todas las afinidades son 0 y el desempate
 * por número de oyentes hace que se muestren primero las salas más animadas —
 * un fallback razonable mientras se aprende su gusto.
 */
@Service
public class RoomRecommendationService {

    @Autowired private RoomRepository roomRepository;
    @Autowired private RoomStateService roomStateService;
    @Autowired private TasteProfileService tasteProfileService;
    @Autowired private UserRepository userRepository;

    /** Peso de cada género DECLARADO de la sala, para que las salas sin historial aún casen. */
    @Value("${reco.declared-genre-weight:3.0}")
    private double declaredGenreWeight;

    @Value("${reco.max-results:20}")
    private int maxResults;

    /** Cuánto pesa el solape de géneros frente al de artistas en el score final. */
    private static final double GENRE_WEIGHT = 0.6;
    private static final double ARTIST_WEIGHT = 0.4;

    @Transactional(readOnly = true)
    public List<RoomResponse> recommendFor(String username) {
        User user = userRepository.findByUsername(username).orElse(null);
        TasteProfileService.Profile profile = user != null
            ? tasteProfileService.userProfile(user)
            : TasteProfileService.Profile.empty();

        List<Scored> scored = new ArrayList<>();
        for (Room room : roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC")) {
            // No tiene sentido recomendarle al usuario sus propias salas
            if (user != null && room.getHost().getId().equals(user.getId())) continue;

            double score = scoreRoom(profile, room);
            RoomState state = roomStateService.getState(room.getId());
            int listeners = state != null ? state.getOnlineUsers().size() : 0;
            scored.add(new Scored(room, state, score, listeners));
        }

        Comparator<Scored> byScore = Comparator.comparingDouble(Scored::score).reversed();
        Comparator<Scored> byListeners = Comparator.comparingInt(Scored::listeners).reversed();
        scored.sort(byScore.thenComparing(byListeners));

        return scored.stream()
            .limit(maxResults)
            .map(s -> RoomResponse.from(s.room(), s.state()))
            .collect(Collectors.toList());
    }

    /** Afinidad usuario↔sala: mezcla del coseno de géneros y del de artistas. */
    private double scoreRoom(TasteProfileService.Profile profile, Room room) {
        TasteProfileService.Profile roomProfile = tasteProfileService.roomProfile(room.getId());

        Map<String, Double> roomGenres = new HashMap<>(roomProfile.getGenres());
        if (room.getGenres() != null) {
            for (String g : room.getGenres().split(",")) {
                String name = g.trim().toLowerCase();
                if (!name.isEmpty()) roomGenres.merge(name, declaredGenreWeight, Double::sum);
            }
        }

        double cosGenre  = TasteProfileService.cosine(profile.getGenres(), roomGenres);
        double cosArtist = TasteProfileService.cosine(profile.getArtists(), roomProfile.getArtists());
        return GENRE_WEIGHT * cosGenre + ARTIST_WEIGHT * cosArtist;
    }

    private record Scored(Room room, RoomState state, double score, int listeners) {}
}
