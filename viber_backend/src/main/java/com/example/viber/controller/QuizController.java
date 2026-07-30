package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.LeaderboardResponse;
import com.example.viber.dto.QuizGameStateResponse;
import com.example.viber.dto.QuizSongResponse;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.model.QuizMode;
import com.example.viber.model.User;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.QuizGameService;
import com.example.viber.service.QuizLeaderboardService;
import com.example.viber.utils.JwtUtil;

/**
 * Minijuego de adivinar canciones (tipo LoLdle/Heardle).
 *
 * Todos los endpoints requieren JWT. El estado que se devuelve nunca incluye
 * la canción secreta hasta que la partida termina; el preview del modo audio
 * se sirve por proxy para no exponer la URL de Deezer.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Quiz", description = "Minijuego de adivinar canciones")
@RestController
@RequestMapping("/api/quiz")
@CrossOrigin(origins = "*")
public class QuizController {

    @Autowired private QuizGameService        quizGameService;
    @Autowired private QuizLeaderboardService quizLeaderboardService;
    @Autowired private UserRepository         userRepository;
    @Autowired private JwtUtil                jwtUtil;

    // ── Helpers ───────────────────────────────────────────────────────────────

    private User userFromHeader(String authHeader) {
        String token    = authHeader.substring(7);
        String username = jwtUtil.getUsernameFromToken(token);
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
    }

    private static QuizMode parseMode(String mode) {
        try {
            return QuizMode.valueOf(mode.toUpperCase());
        } catch (Exception e) {
            throw new RuntimeException("Modo de quiz no válido: " + mode);
        }
    }

    // ── Autocompletado de intentos ────────────────────────────────────────────

    // GET /api/quiz/songs/search?q=que&mode=classic
    @GetMapping("/songs/search")
    public ResponseEntity<List<QuizSongResponse>> search(
            @RequestHeader("Authorization") String auth,
            @RequestParam String q,
            @RequestParam(defaultValue = "classic") String mode) {

        userFromHeader(auth);
        if (q == null || q.trim().length() < 2) return ResponseEntity.ok(List.of());
        return ResponseEntity.ok(quizGameService.searchPool(q, parseMode(mode)));
    }

    // ── Partidas ──────────────────────────────────────────────────────────────

    // GET /api/quiz/daily/classic — partida diaria del usuario (se crea si no existe)
    @GetMapping("/daily/{mode}")
    public ResponseEntity<QuizGameStateResponse> daily(
            @RequestHeader("Authorization") String auth,
            @PathVariable String mode) {
        return ResponseEntity.ok(
            quizGameService.dailyGame(userFromHeader(auth), parseMode(mode)));
    }

    // POST /api/quiz/practice/audio — nueva partida de práctica (modo infinito)
    @PostMapping("/practice/{mode}")
    public ResponseEntity<QuizGameStateResponse> practice(
            @RequestHeader("Authorization") String auth,
            @PathVariable String mode) {
        return ResponseEntity.ok(
            quizGameService.newPracticeGame(userFromHeader(auth), parseMode(mode)));
    }

    // GET /api/quiz/games/{id} — reabrir una partida
    @GetMapping("/games/{id}")
    public ResponseEntity<QuizGameStateResponse> game(
            @RequestHeader("Authorization") String auth,
            @PathVariable Long id) {
        return ResponseEntity.ok(quizGameService.gameState(userFromHeader(auth), id));
    }

    // POST /api/quiz/games/{id}/guess  body: {"songId": 42}
    @PostMapping("/games/{id}/guess")
    public ResponseEntity<QuizGameStateResponse> guess(
            @RequestHeader("Authorization") String auth,
            @PathVariable Long id,
            @RequestBody Map<String, Long> body) {

        Long songId = body.get("songId");
        if (songId == null) throw new RuntimeException("Falta el songId del intento");
        return ResponseEntity.ok(
            quizGameService.guess(userFromHeader(auth), id, songId));
    }

    // POST /api/quiz/games/{id}/skip — saltar turno (solo audio)
    @PostMapping("/games/{id}/skip")
    public ResponseEntity<QuizGameStateResponse> skip(
            @RequestHeader("Authorization") String auth,
            @PathVariable Long id) {
        return ResponseEntity.ok(quizGameService.skip(userFromHeader(auth), id));
    }

    // POST /api/quiz/games/{id}/surrender — rendirse y ver la respuesta
    @PostMapping("/games/{id}/surrender")
    public ResponseEntity<QuizGameStateResponse> surrender(
            @RequestHeader("Authorization") String auth,
            @PathVariable Long id) {
        return ResponseEntity.ok(quizGameService.surrender(userFromHeader(auth), id));
    }

    // ── Audio (modo audio) ────────────────────────────────────────────────────

    /**
     * GET /api/quiz/games/{id}/audio?token=JWT
     *
     * Proxy del preview MP3 de 30 s. Acepta el JWT como query param porque el
     * elemento &lt;audio&gt; del navegador (just_audio en Flutter web) no puede
     * enviar el header Authorization.
     */
    @GetMapping("/games/{id}/audio")
    public ResponseEntity<byte[]> audio(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestParam(required = false) String token,
            @PathVariable Long id) {

        User user = userFromHeaderOrToken(auth, token);
        byte[] bytes = quizGameService.audioPreview(user, id);
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("audio/mpeg"))
            .cacheControl(CacheControl.noStore())
            .body(bytes);
    }

    /** Auth por header (normal) o por query param (audio/imagen del navegador). */
    private User userFromHeaderOrToken(String authHeader, String tokenParam) {
        String jwt = (authHeader != null && authHeader.startsWith("Bearer "))
            ? authHeader.substring(7) : tokenParam;
        if (jwt == null || !jwtUtil.validateToken(jwt)) {
            throw new ForbiddenException("Token no válido");
        }
        return userRepository.findByUsername(jwtUtil.getUsernameFromToken(jwt))
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
    }

    // ── Portada pixelada (modo portada) ───────────────────────────────────────

    /**
     * GET /api/quiz/games/{id}/cover?token=JWT
     *
     * Portada de la canción secreta reescalada a N×N píxeles según los intentos
     * gastados. El pixelado es del servidor: el cliente nunca ve la imagen real
     * hasta terminar. El token va como query param por el mismo motivo que en
     * el audio (los elementos de imagen/audio del navegador no mandan headers).
     */
    @GetMapping("/games/{id}/cover")
    public ResponseEntity<byte[]> cover(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestParam(required = false) String token,
            @PathVariable Long id) {

        User user = userFromHeaderOrToken(auth, token);
        byte[] bytes = quizGameService.coverImage(user, id);
        return ResponseEntity.ok()
            .contentType(MediaType.IMAGE_PNG)
            .cacheControl(CacheControl.noStore())
            .body(bytes);
    }

    // ── Estadísticas del usuario ──────────────────────────────────────────────

    // GET /api/quiz/stats
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> stats(
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(quizGameService.userStats(userFromHeader(auth)));
    }

    // ── Leaderboard ───────────────────────────────────────────────────────────

    // GET /api/quiz/leaderboard?scope=world|friends&period=daily|month
    @GetMapping("/leaderboard")
    public ResponseEntity<LeaderboardResponse> leaderboard(
            @RequestHeader("Authorization") String auth,
            @RequestParam(defaultValue = "world") String scope,
            @RequestParam(defaultValue = "daily") String period) {
        return ResponseEntity.ok(
            quizLeaderboardService.getLeaderboard(userFromHeader(auth), scope, period));
    }
}
