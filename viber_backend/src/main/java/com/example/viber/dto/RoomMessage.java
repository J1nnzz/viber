package com.example.viber.dto;

import lombok.Data;

/**
 * Mensaje enviado/recibido por WebSocket STOMP entre clientes y servidor.
 *
 * El cliente envía a: /app/room.{roomId}.control
 * El servidor hace broadcast a: /topic/room.{roomId}
 *
 * Los campos relevantes dependen del {@link Type}:
 *  - Reproducción (PLAY/PAUSE/SEEK): videoId, position, serverTimestamp
 *  - Cola (QUEUE_ADD/REMOVE/MOVE): videoId, videoTitle, videoThumbnail, queueIndex, targetIndex
 *  - Moderación (KICK/MUTE/ROLE): targetUsername, role
 *  - Chat: content
 */
@Data
public class RoomMessage {

    public enum Type {
        // ── Reproductor ───────────────────────────────────────────────────────
        PLAY, PAUSE, SEEK, NEXT, PREV,

        // ── Cola ─────────────────────────────────────────────────────────────
        QUEUE_ADD, QUEUE_REMOVE, QUEUE_MOVE,

        // ── Usuarios ─────────────────────────────────────────────────────────
        USER_JOINED, USER_LEFT,

        // ── Moderación y roles ────────────────────────────────────────────────
        // targetUsername = usuario afectado
        // role           = nuevo rol ("DJ" | "LISTENER") — solo en ROLE_CHANGE
        ROLE_CHANGE,   // Host promueve/degrada a alguien
        USER_KICKED,   // Host expulsa a un usuario
        USER_UNKICKED, // Host levanta el ban a un usuario expulsado
        USER_MUTED,    // Host silencia a un usuario en el chat
        USER_UNMUTED,  // Host quita el silencio

        // ── Sala ─────────────────────────────────────────────────────────────
        ROOM_CLOSED, // El host ha cerrado la sala

        // ── Chat ─────────────────────────────────────────────────────────────
        CHAT
    }

    private Type type;
    private String senderUsername;

    // ── Reproductor ───────────────────────────────────────────────────────────
    private String videoId;
    private Double position;
    private Long   serverTimestamp;

    // ── Cola ─────────────────────────────────────────────────────────────────
    private String  videoTitle;
    private String  videoThumbnail;
    private String  videoChannel; // canal/artista de YouTube (QUEUE_ADD, PLAY)
    private Integer queueIndex;   // índice origen  (QUEUE_REMOVE, QUEUE_MOVE)
    private Integer targetIndex;  // índice destino (QUEUE_MOVE)

    // ── Moderación/roles ──────────────────────────────────────────────────────
    // Usuario sobre el que actúa la acción (kick, mute, role change)
    private String targetUsername;
    // Nuevo rol asignado (usado en ROLE_CHANGE): "DJ" | "LISTENER"
    private String role;

    // ── Chat ─────────────────────────────────────────────────────────────────
    private String content;
}