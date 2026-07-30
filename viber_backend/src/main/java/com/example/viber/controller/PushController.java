package com.example.viber.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.RegisterDeviceRequest;
import com.example.viber.model.DeviceToken;
import com.example.viber.model.User;
import com.example.viber.repository.DeviceTokenRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.utils.JwtUtil;

/**
 * Registro y baja de tokens de dispositivo para notificaciones push (FCM).
 * El cliente llama a /register tras iniciar sesión y a /unregister al cerrar sesión.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Push", description = "Tokens de notificaciones push")
@RestController
@RequestMapping("/api/push")
@CrossOrigin(origins = "*")
public class PushController {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final DeviceTokenRepository tokenRepository;

    public PushController(JwtUtil jwtUtil,
                          UserRepository userRepository,
                          DeviceTokenRepository tokenRepository) {
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
    }

    /** Registra (o reasigna al usuario actual) el token FCM del dispositivo. */
    @PostMapping("/register")
    public ResponseEntity<?> register(
            @RequestHeader("Authorization") String auth,
            @RequestBody RegisterDeviceRequest req) {
        if (req.getToken() == null || req.getToken().isBlank())
            return ResponseEntity.badRequest().body(Map.of("error", "token requerido"));

        User user = userFromHeader(auth);

        // Si el token ya existía (mismo dispositivo, otra cuenta) se reasigna al usuario actual.
        DeviceToken dt = tokenRepository.findByToken(req.getToken())
            .orElseGet(DeviceToken::new);
        dt.setToken(req.getToken());
        dt.setPlatform(req.getPlatform());
        dt.setUser(user);
        tokenRepository.save(dt);

        return ResponseEntity.ok(Map.of("message", "Dispositivo registrado"));
    }

    /** Elimina el token del dispositivo (al cerrar sesión). No requiere usuario. */
    @PostMapping("/unregister")
    public ResponseEntity<?> unregister(@RequestBody RegisterDeviceRequest req) {
        if (req.getToken() != null && !req.getToken().isBlank()) {
            tokenRepository.findByToken(req.getToken())
                .ifPresent(tokenRepository::delete);
        }
        return ResponseEntity.ok(Map.of("message", "Dispositivo eliminado"));
    }

    private User userFromHeader(String authHeader) {
        String token = authHeader.substring(7);
        String username = jwtUtil.getUsernameFromToken(token);
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
    }
}
