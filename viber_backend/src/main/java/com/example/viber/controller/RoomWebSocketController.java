package com.example.viber.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import com.example.viber.dto.RoomListEvent;
import com.example.viber.dto.RoomMessage;
import com.example.viber.dto.RoomResponse;
import com.example.viber.model.RoomState;
import com.example.viber.repository.RoomRepository;
import com.example.viber.service.FirestoreChatService;
import com.example.viber.service.PresenceService;
import com.example.viber.service.RoomStateService;
import com.example.viber.service.UserStatsService;

@Controller
public class RoomWebSocketController {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private RoomStateService roomStateService;

    @Autowired
    private FirestoreChatService firestoreChatService;

    @Autowired
    private PresenceService presenceService;

    @Autowired
    private RoomRepository roomRepository;

    @Autowired
    private UserStatsService userStatsService;

    /**
     * Los clientes envían a : /app/room.{roomId}.control
     * El servidor hace broadcast a : /topic/room.{roomId}
     *
     * Flujo:
     *  1. Añadir timestamp del servidor
     *  2. Verificar permisos — si no tiene autorización, silenciar el mensaje
     *  3. Aplicar el mensaje al estado en memoria
     *  4. Broadcast al canal de la sala
     *  5. Si es CHAT, persistir en Firestore en background (no bloquea)
     *  6. Si es USER_KICKED, enviar además una notificación personal al expulsado
     */
    @MessageMapping("/room.{roomId}.control")
    public void handleRoomControl(
            @DestinationVariable Long roomId,
            @Payload RoomMessage message) {

        // 1. Timestamp del servidor para sincronización precisa
        message.setServerTimestamp(System.currentTimeMillis());

        // 2. Verificar permisos
        if (roomStateService.isUnauthorized(roomId, message)) {
            return;
        }

        // 2b. Verificar aforo al entrar (el host siempre puede)
        if (message.getType() == RoomMessage.Type.USER_JOINED) {
            String sender = message.getSenderUsername();
            if (sender != null && roomStateService.isRoomFull(roomId, sender)) {
                messagingTemplate.convertAndSendToUser(
                    sender, "/queue/full",
                    java.util.Map.of("type", "ROOM_FULL")
                );
                return;
            }
        }

        // 3. Aplicar al estado en memoria
        roomStateService.applyMessage(roomId, message);

        RoomMessage.Type type = message.getType();

        // 3b. NEXT y PREV cambian qué canción suena, y el único que sabe cuál
        // es el estado en memoria de aquí. Se adjunta al mensaje antes de
        // retransmitirlo: si cada cliente dedujera la siguiente de su propia
        // copia de la cola, bastaría una divergencia (un QUEUE_ADD perdido, o
        // haber entrado a la sala a mitad) para que se quedaran en canciones
        // distintas, y el desfase iría creciendo con cada avance.
        if (type == RoomMessage.Type.NEXT || type == RoomMessage.Type.PREV) {
            RoomState state = roomStateService.getState(roomId);
            message.setVideoId(state.getCurrentVideoId());
            message.setVideoTitle(state.getCurrentVideoTitle());
            message.setVideoThumbnail(state.getCurrentVideoThumbnail());
            message.setVideoChannel(state.getCurrentVideoChannel());
            message.setPosition(0.0);
        }

        // 4. Broadcast a todos los suscriptores de la sala
        messagingTemplate.convertAndSend(
            "/topic/room." + roomId,
            message
        );

        // 4b. Si la canción cambió, notificar a la lista de salas para actualizar las tarjetas
        if (type == RoomMessage.Type.PLAY
                || type == RoomMessage.Type.NEXT
                || type == RoomMessage.Type.PREV) {
            roomRepository.findById(roomId).ifPresent(room -> {
                if (!"PUBLIC".equals(room.getPrivacy())) return;
                RoomResponse dto = RoomResponse.from(room, roomStateService.getState(roomId));
                RoomListEvent event = new RoomListEvent();
                event.setType(RoomListEvent.Type.ROOM_UPDATED);
                event.setRoomId(roomId);
                event.setRoom(dto);
                messagingTemplate.convertAndSend("/topic/rooms", event);
            });
        }

        // 5. Persistir mensaje de chat en Firestore (async — no bloquea el broadcast)
        if (message.getType() == RoomMessage.Type.CHAT
                && message.getContent() != null
                && message.getSenderUsername() != null) {
            firestoreChatService.saveMessage(
                roomId,
                message.getSenderUsername(),
                message.getContent(),
                message.getServerTimestamp()
            );
        }

        // 6. Actualizar presencia y estadísticas de uso (salas unidas, tiempo escuchado)
        String sender = message.getSenderUsername();
        if (message.getType() == RoomMessage.Type.USER_JOINED && sender != null) {
            presenceService.setInRoom(sender, roomId);
            userStatsService.recordRoomVisit(sender, roomId);
            userStatsService.startListenSession(sender);
        } else if (message.getType() == RoomMessage.Type.USER_LEFT && sender != null) {
            presenceService.setOffline(sender);
            userStatsService.endListenSession(sender);
        }

        // 7. Notificación personal al usuario expulsado
        //    El cliente Flutter escucha /user/queue/kick para saber que fue expulsado
        //    y puede reaccionar navegando fuera de la sala inmediatamente.
        if (message.getType() == RoomMessage.Type.USER_KICKED
                && message.getTargetUsername() != null) {
            messagingTemplate.convertAndSendToUser(
                message.getTargetUsername(),
                "/queue/kick",
                message
            );
        }
    }
}