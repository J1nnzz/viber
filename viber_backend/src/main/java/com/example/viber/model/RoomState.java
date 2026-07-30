package com.example.viber.model;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import lombok.Data;

@Data
public class RoomState {

    // ── Reproducción ──────────────────────────────────────────────────────────
    private String currentVideoId;
    private String currentVideoTitle;
    private String currentVideoThumbnail;
    private String currentVideoChannel; // canal/artista del vídeo actual (solo en memoria, para stats)
    private Double currentPosition = 0.0;
    private boolean playing = false;
    private Long lastUpdateTimestamp;

    // ── Cola e historial de reproducción ──────────────────────────────────────
    private List<QueueItem> queue   = new ArrayList<>();
    private List<QueueItem> history = new ArrayList<>();

    // ── Roles de sala ─────────────────────────────────────────────────────────
    // Valores posibles: "HOST", "DJ", "LISTENER"
    // El host se registra al crear la sala; el resto entra como LISTENER.
    // Los roles persisten aunque el usuario se desconecte temporalmente.
    private Map<String, String> userRoles = new ConcurrentHashMap<>();

    // ── Usuarios online ───────────────────────────────────────────────────────
    // Set separado de userRoles: solo contiene usuarios ACTUALMENTE conectados.
    // Se envía al cliente en /state para que nuevos usuarios vean quién hay.
    private Set<String> onlineUsers = new HashSet<>();

    // Epoch ms en que la sala quedó sin oyentes mientras seguía reproduciendo.
    // Cuando alguien entra se usa para calcular la posición virtual y se borra.
    private Long lastEmptyTimestamp;

    // ── Aforo ─────────────────────────────────────────────────────────────────
    private Integer maxParticipants;

    // ── Moderación ────────────────────────────────────────────────────────────
    private Set<String> mutedUsers  = new HashSet<>();
    private Set<String> kickedUsers = new HashSet<>();

    // ── Historial de chat (Firestore) ─────────────────────────────────────────
    // Solo se popula en la respuesta del endpoint /state.
    // No vive en memoria entre mensajes — se carga puntualmente al entrar a la sala.
    // Cada elemento: { "sender": String, "text": String, "timestamp": Long }
    private List<Map<String, Object>> chatHistory = new ArrayList<>();

    // ── Helpers de rol ────────────────────────────────────────────────────────

    public void setHost(String username) {
        userRoles.put(username, "HOST");
        onlineUsers.add(username);
    }

    public void addUser(String username) {
        userRoles.putIfAbsent(username, "LISTENER");
        onlineUsers.add(username);
    }

    public void removeUser(String username) {
        // Mantener el rol por si reconecta, solo quitar de online
        onlineUsers.remove(username);
        // Si la sala queda vacía mientras suena, registrar el instante
        // para poder calcular la posición virtual cuando alguien vuelva a entrar.
        if (onlineUsers.isEmpty() && playing && lastEmptyTimestamp == null) {
            lastEmptyTimestamp = System.currentTimeMillis();
        }
    }

    public String getRole(String username) {
        return userRoles.getOrDefault(username, "LISTENER");
    }

    public boolean isHost(String username) {
        return "HOST".equals(getRole(username));
    }

    public boolean isDJ(String username) {
        return "DJ".equals(getRole(username));
    }

    public boolean canControlPlayback(String username) {
        // Solo el host controla play/pause/seek
        return isHost(username);
    }

    public boolean canManageQueue(String username) {
        // Host y DJ pueden gestionar la cola
        String role = getRole(username);
        return "HOST".equals(role) || "DJ".equals(role);
    }

    public boolean isMuted(String username) {
        return mutedUsers.contains(username);
    }

    public boolean isKicked(String username) {
        return kickedUsers.contains(username);
    }

    /** La sala está llena para este usuario (el host siempre puede entrar). */
    public boolean isFull(String username) {
        if (maxParticipants == null) return false;
        if (isHost(username)) return false;
        return onlineUsers.size() >= maxParticipants;
    }

    // ── Inner classes ─────────────────────────────────────────────────────────

    @Data
    public static class QueueItem {
        private String videoId;
        private String title;
        private String thumbnail;
        private String addedBy;
        private String channelTitle;
    }
}