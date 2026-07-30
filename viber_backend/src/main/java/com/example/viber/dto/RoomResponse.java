package com.example.viber.dto;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import com.example.viber.model.Room;
import com.example.viber.model.RoomState;

import lombok.Data;

/**
 * DTO de respuesta para operaciones de sala.
 * Combina datos persistidos (Room) con estado en tiempo real (RoomState).
 * Los métodos de fábrica estáticos {@code from(Room)} y {@code from(Room, RoomState)}
 * centralizan la conversión para evitar duplicar lógica en los controllers.
 */
@Data
public class RoomResponse {
    private Long id;
    private String name;
    private String description;
    private List<String> genres;
    private String privacy;
    private String hostUsername;
    private LocalDateTime createdAt;
    private boolean active;
    private boolean flagged;
    private boolean autoDj;
    private String flagReason;
    private Integer maxParticipants;
    private String accessCode;
    private int onlineUserCount;

    // Personalización de la sala
    private String coverImageUrl;
    private String accentColor;
    private String welcomeMessage;

    // Datos de reproducción en tiempo real (null si la sala no tiene nada sonando)
    private String currentVideoTitle;
    private String currentVideoThumbnail;
    private int listenerCount;

    public static RoomResponse from(Room room) {
        RoomResponse dto = new RoomResponse();
        dto.setId(room.getId());
        dto.setName(room.getName());
        dto.setDescription(room.getDescription());
        dto.setGenres(parseGenres(room.getGenres()));
        dto.setPrivacy(room.getPrivacy());
        dto.setHostUsername(room.getHost().getUsername());
        dto.setCreatedAt(room.getCreatedAt());
        dto.setActive(room.isActive());
        dto.setFlagged(room.isFlagged());
        dto.setAutoDj(room.isAutoDj());
        dto.setFlagReason(room.getFlagReason());
        dto.setMaxParticipants(room.getMaxParticipants());
        dto.setAccessCode(room.getAccessCode());
        dto.setCoverImageUrl(room.getCoverImageUrl());
        dto.setAccentColor(room.getAccentColor());
        dto.setWelcomeMessage(room.getWelcomeMessage());
        return dto;
    }

    public static RoomResponse from(Room room, RoomState state) {
        RoomResponse dto = from(room);
        if (state != null) {
            dto.setCurrentVideoTitle(state.getCurrentVideoTitle());
            dto.setCurrentVideoThumbnail(state.getCurrentVideoThumbnail());
            dto.setListenerCount(state.getOnlineUsers().size());
            dto.setOnlineUserCount(state.getOnlineUsers().size());
        }
        return dto;
    }

    private static List<String> parseGenres(String raw) {
        if (raw == null || raw.isBlank()) return Collections.emptyList();
        return Arrays.asList(raw.split(","));
    }
}
