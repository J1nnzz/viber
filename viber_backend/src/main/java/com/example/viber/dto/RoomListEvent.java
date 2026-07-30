package com.example.viber.dto;

import lombok.Data;

/**
 * Evento broadcast a /topic/rooms cuando la lista pública de salas cambia.
 * Los clientes suscritos actualizan su lista en tiempo real sin polling.
 */
@Data
public class RoomListEvent {

    public enum Type {
        ROOM_CREATED,  // sala pública nueva
        ROOM_UPDATED,  // sala editada (nombre, géneros, etc.)
        ROOM_CLOSED,   // sala eliminada o cambiada a privada
    }

    private Type type;
    private Long roomId;
    private RoomResponse room; // null en ROOM_CLOSED
}
