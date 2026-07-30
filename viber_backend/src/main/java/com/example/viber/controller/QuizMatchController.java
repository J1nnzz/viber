package com.example.viber.controller;

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

import com.example.viber.dto.CreateMatchRequest;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.service.QuizMatchService;
import com.example.viber.utils.JwtUtil;

/**
 * Creación y consulta de partidas de quiz EN VIVO. El juego en sí (sala de espera,
 * rondas, respuestas) transcurre por STOMP — ver {@link QuizMatchWebSocketController}.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Quiz en vivo", description = "Competición de quiz entre amigos")
@RestController
@RequestMapping("/api/quiz/match")
@CrossOrigin(origins = "*")
public class QuizMatchController {

    @Autowired private QuizMatchService quizMatchService;
    @Autowired private JwtUtil          jwtUtil;

    private String extractUsername(String authHeader) {
        return jwtUtil.getUsernameFromToken(authHeader.substring(7));
    }

    // POST /api/quiz/match — crear una partida e invitar a los rivales
    @PostMapping
    public ResponseEntity<Map<String, Object>> create(
            @RequestBody CreateMatchRequest request,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(quizMatchService.createMatch(request, extractUsername(auth)));
    }

    // GET /api/quiz/match/{id}/lobby — snapshot de la sala de espera al abrir la pantalla
    @GetMapping("/{id}/lobby")
    public ResponseEntity<Map<String, Object>> lobby(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        extractUsername(auth); // exige token válido
        return ResponseEntity.ok(quizMatchService.lobbySnapshot(id));
    }

    /**
     * GET /api/quiz/match/{id}/audio?token=JWT
     *
     * Preview MP3 de 30 s de la ronda actual (modo audio), por proxy. El token
     * va como query param porque el elemento &lt;audio&gt; del navegador no
     * puede mandar el header Authorization (igual que en el quiz individual).
     */
    @GetMapping("/{id}/audio")
    public ResponseEntity<byte[]> audio(
            @PathVariable Long id,
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestParam(required = false) String token) {
        String jwt = (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : token;
        if (jwt == null || !jwtUtil.validateToken(jwt))
            throw new ForbiddenException("Token no válido");
        byte[] bytes = quizMatchService.roundAudio(id, jwtUtil.getUsernameFromToken(jwt));
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("audio/mpeg"))
            .cacheControl(CacheControl.noStore())
            .body(bytes);
    }
}
