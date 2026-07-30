package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.exception.ForbiddenException;
import com.example.viber.model.Friendship;
import com.example.viber.model.User;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.FirestoreDirectMessageService;
import com.example.viber.utils.JwtUtil;

/**
 * Mensajería directa (DM) entre amigos y chat global de la plataforma.
 * Solo usuarios que son amigos pueden intercambiar DMs; el chat global está
 * abierto a cualquier usuario autenticado. La persistencia se delega a Firestore
 * a través de {@link com.example.viber.service.FirestoreDirectMessageService}.
 */
@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*")
public class ChatController {

    @Autowired private JwtUtil                       jwtUtil;
    @Autowired private UserRepository                userRepository;
    @Autowired private FriendshipRepository          friendshipRepository;
    @Autowired private FirestoreDirectMessageService dmService;

    // ── Helper ────────────────────────────────────────────────────────────────

    private User userFromHeader(String authHeader) {
        String token    = authHeader.substring(7);
        String username = jwtUtil.getUsernameFromToken(token);
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
    }

    private boolean areFriends(User a, User b) {
        return friendshipRepository.findBetween(a, b)
            .map(f -> f.getStatus() == Friendship.Status.ACCEPTED)
            .orElse(false);
    }

    // ── GET /api/chat/conversations ───────────────────────────────────────────

    @GetMapping("/conversations")
    public ResponseEntity<?> getConversations(@RequestHeader("Authorization") String auth) {
        User me = userFromHeader(auth);
        List<Map<String, Object>> convs = dmService.getConversations(me.getUsername());
        return ResponseEntity.ok(convs);
    }

    // ── GET /api/chat/dm/{username} ───────────────────────────────────────────

    @GetMapping("/dm/{username}")
    public ResponseEntity<?> getDMs(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        User me    = userFromHeader(auth);
        User other = userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        if (!areFriends(me, other))
            throw new ForbiddenException("Solo puedes chatear con tus amigos");

        return ResponseEntity.ok(dmService.getDMs(me.getUsername(), other.getUsername()));
    }

    // ── POST /api/chat/dm/{username} ──────────────────────────────────────────

    @PostMapping("/dm/{username}")
    public ResponseEntity<?> sendDM(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth,
            @RequestBody Map<String, String> body) {
        User me    = userFromHeader(auth);
        User other = userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        if (!areFriends(me, other))
            throw new ForbiddenException("Solo puedes chatear con tus amigos");

        String text = body.get("text");
        if (text == null || text.isBlank())
            throw new RuntimeException("El mensaje no puede estar vacío");
        if (text.length() > 500)
            throw new RuntimeException("Mensaje demasiado largo (máx. 500 caracteres)");

        dmService.sendDM(me.getUsername(), other.getUsername(), text.trim());
        return ResponseEntity.ok(Map.of("message", "Enviado"));
    }

    // ── GET /api/chat/global ──────────────────────────────────────────────────

    @GetMapping("/global")
    public ResponseEntity<?> getGlobal(@RequestHeader("Authorization") String auth) {
        userFromHeader(auth);
        return ResponseEntity.ok(dmService.getGlobalMessages());
    }

    // ── POST /api/chat/global ─────────────────────────────────────────────────

    @PostMapping("/global")
    public ResponseEntity<?> sendGlobal(
            @RequestHeader("Authorization") String auth,
            @RequestBody Map<String, String> body) {
        User me   = userFromHeader(auth);
        String text = body.get("text");
        if (text == null || text.isBlank())
            throw new RuntimeException("El mensaje no puede estar vacío");
        if (text.length() > 500)
            throw new RuntimeException("Mensaje demasiado largo (máx. 500 caracteres)");

        dmService.sendGlobal(me.getUsername(), text.trim());
        return ResponseEntity.ok(Map.of("message", "Enviado"));
    }
}
