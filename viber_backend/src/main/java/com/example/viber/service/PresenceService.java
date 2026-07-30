package com.example.viber.service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

/**
 * Seguimiento en memoria de qué usuarios están actualmente en una sala.
 * Se actualiza cuando el WebSocket recibe USER_JOINED / USER_LEFT.
 * Sin persistencia: si el servidor reinicia, todos aparecen OFFLINE
 * hasta que vuelvan a conectarse a una sala.
 */
@Service
public class PresenceService {

    // username → roomId (Long)
    private final Map<String, Long> userRoomMap = new ConcurrentHashMap<>();

    public void setInRoom(String username, Long roomId) {
        if (username != null && roomId != null) {
            userRoomMap.put(username, roomId);
        }
    }

    public void setOffline(String username) {
        if (username != null) {
            userRoomMap.remove(username);
        }
    }

    /** null = OFFLINE, Long = roomId donde está */
    public Long getRoomId(String username) {
        return username != null ? userRoomMap.get(username) : null;
    }

    public boolean isOnline(String username) {
        return username != null && userRoomMap.containsKey(username);
    }
}
