package com.example.viber.controller;

import java.security.Principal;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import com.example.viber.model.Friendship;
import com.example.viber.model.User;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.FirestoreDirectMessageService;

/**
 * Chat en tiempo real sobre STOMP (gemelo WebSocket del {@link ChatController} REST,
 * que se mantiene para cargar el historial y marcar leídos).
 *
 * <p>Chat global:
 * <ul>
 *   <li>cliente → {@code /app/chat.global}  · payload {@code {text}}</li>
 *   <li>broadcast → {@code /topic/chat.global}  · payload {@code {sender, text, timestamp}}</li>
 * </ul>
 *
 * <p>Mensaje directo (DM):
 * <ul>
 *   <li>cliente → {@code /app/chat.dm}  · payload {@code {to, text}}</li>
 *   <li>entrega → {@code /user/{to}/queue/dm} y {@code /user/{from}/queue/dm} (eco al
 *       remitente)  · payload {@code {sender, text, timestamp, to}}</li>
 * </ul>
 *
 * El remitente SIEMPRE se toma del {@link Principal} STOMP (el JWT validado en el
 * frame CONNECT por {@code JwtChannelInterceptor}), nunca de datos del cliente.
 * La persistencia se delega a {@link FirestoreDirectMessageService} (asíncrona).
 */
@Controller
public class ChatWebSocketController {

    private static final int MAX_LEN = 500;

    @Autowired private SimpMessagingTemplate         messagingTemplate;
    @Autowired private FirestoreDirectMessageService dmService;
    @Autowired private UserRepository                userRepository;
    @Autowired private FriendshipRepository          friendshipRepository;

    // ── Chat global ─────────────────────────────────────────────────────────

    @MessageMapping("/chat.global")
    public void global(@Payload Map<String, String> body, Principal principal) {
        if (principal == null) return;
        String from = principal.getName();
        String text = sanitize(body.get("text"));
        if (text == null) return;

        long ts = System.currentTimeMillis();
        dmService.sendGlobal(from, text);

        // Cast a Object: con un Map, convertAndSend(destino, payload) y
        // convertAndSend(payload, headers) serían ambiguas. El cast fuerza la
        // primera sobrecarga (destino + payload).
        Object payload = Map.of("sender", from, "text", text, "timestamp", ts);
        messagingTemplate.convertAndSend("/topic/chat.global", payload);
    }

    // ── Mensaje directo ───────────────────────────────────────────────────────

    @MessageMapping("/chat.dm")
    public void dm(@Payload Map<String, String> body, Principal principal) {
        if (principal == null) return;
        String from = principal.getName();
        String to   = body.get("to");
        String text = sanitize(body.get("text"));
        if (to == null || to.isBlank() || text == null) return;

        User me    = userRepository.findByUsername(from).orElse(null);
        User other = userRepository.findByUsername(to).orElse(null);
        // Solo se permite DM entre amigos (misma regla que el endpoint REST).
        if (me == null || other == null || !areFriends(me, other)) return;

        long ts = System.currentTimeMillis();
        dmService.sendDM(from, to, text);

        Map<String, Object> payload =
            Map.of("sender", from, "text", text, "timestamp", ts, "to", to);
        // Entrega al destinatario y eco al remitente (para confirmación inmediata).
        messagingTemplate.convertAndSendToUser(to,   "/queue/dm", payload);
        messagingTemplate.convertAndSendToUser(from, "/queue/dm", payload);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private String sanitize(String text) {
        if (text == null) return null;
        String t = text.trim();
        if (t.isEmpty() || t.length() > MAX_LEN) return null;
        return t;
    }

    private boolean areFriends(User a, User b) {
        return friendshipRepository.findBetween(a, b)
            .map(f -> f.getStatus() == Friendship.Status.ACCEPTED)
            .orElse(false);
    }
}
