package com.example.viber.service;

import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import com.example.viber.dto.CreateRoomRequest;
import com.example.viber.dto.RoomListEvent;
import com.example.viber.dto.RoomMessage;
import com.example.viber.dto.RoomResponse;
import com.example.viber.dto.UpdateRoomRequest;
import com.example.viber.exception.ErrorCode;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.Room;
import com.example.viber.model.RoomState;
import com.example.viber.model.User;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.utils.JwtUtil;

/**
 * Lógica de negocio de salas: creación, listado, edición, cierre y moderación.
 *
 * Al crear/cerrar una sala pública se emite un {@link com.example.viber.dto.RoomListEvent}
 * a {@code /topic/rooms} para que los clientes suscritos actualicen su lista sin polling.
 * El chat y la cola de canciones se limpian en Firestore al cerrar la sala para evitar
 * datos huérfanos.
 */
@Service
public class RoomService {

    @Autowired private RoomRepository        roomRepository;
    @Autowired private UserRepository        userRepository;
    @Autowired private JwtUtil               jwtUtil;
    @Autowired private RoomStateService      roomStateService;
    @Autowired private FirestoreChatService  firestoreChatService;
    @Autowired private FirestoreQueueService firestoreQueueService;
    @Autowired private SimpMessagingTemplate messagingTemplate;
    @Autowired private GenreService          genreService;
    @Autowired private UserStatsService      userStatsService;

    // ── Crear sala ────────────────────────────────────────────────────────────

    public RoomResponse createRoom(CreateRoomRequest request, String token) {
        String username = jwtUtil.getUsernameFromToken(token);
        User host = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND, "Usuario no encontrado"));

        Room room = new Room();
        room.setName(request.getName());
        room.setDescription(request.getDescription());
        if (request.getGenres() != null && !request.getGenres().isEmpty()) {
            validateGenres(request.getGenres());
            room.setGenres(String.join(",", request.getGenres()));
        }
        room.setMaxParticipants(request.getMaxParticipants());
        room.setPrivacy(request.getPrivacy() != null ? request.getPrivacy() : "PUBLIC");
        room.setAutoDj(Boolean.TRUE.equals(request.getAutoDj()));
        room.setCoverImageUrl(blankToNull(request.getCoverImageUrl()));
        room.setAccentColor(blankToNull(request.getAccentColor()));
        room.setWelcomeMessage(blankToNull(request.getWelcomeMessage()));
        room.setHost(host);

        if ("PRIVATE".equals(room.getPrivacy())) {
            String code = request.getAccessCode() != null && !request.getAccessCode().isBlank()
                ? request.getAccessCode()
                : generateCode();
            room.setAccessCode(code);
        }

        Room saved = roomRepository.save(room);
        roomStateService.initRoom(saved.getId(), username, request.getMaxParticipants());

        RoomResponse response = RoomResponse.from(saved, roomStateService.getState(saved.getId()));

        if ("PUBLIC".equals(saved.getPrivacy())) {
            broadcastListEvent(RoomListEvent.Type.ROOM_CREATED, saved.getId(), response);
        }

        return response;
    }

    // ── Listar salas públicas activas ─────────────────────────────────────────

    public List<RoomResponse> getPublicRooms() {
        return roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC")
            .stream()
            .map(room -> RoomResponse.from(room, roomStateService.getState(room.getId())))
            .collect(Collectors.toList());
    }

    // ── Listar salas activas del usuario autenticado (públicas + privadas) ───────

    public List<RoomResponse> getMyRooms(String username) {
        return roomRepository.findByHost_UsernameAndActiveTrue(username)
            .stream()
            .map(room -> RoomResponse.from(room, roomStateService.getState(room.getId())))
            .collect(Collectors.toList());
    }

    // ── Obtener sala por ID ───────────────────────────────────────────────────

    public RoomResponse getRoom(Long roomId, String accessCode) {
        Room room = roomRepository.findById(roomId)
            .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        if (!room.isActive())
            throw new ForbiddenException("La sala está cerrada");
        if (room.isFlagged())
            throw new ForbiddenException("Esta sala no está disponible");

        if ("PRIVATE".equals(room.getPrivacy())) {
            if (accessCode == null || !accessCode.equals(room.getAccessCode()))
                throw new ForbiddenException("Código de acceso incorrecto");
        }

        return RoomResponse.from(room);
    }

    // ── Editar sala ───────────────────────────────────────────────────────────

    public RoomResponse updateRoom(Long roomId, UpdateRoomRequest request, String token) {
        String username = jwtUtil.getUsernameFromToken(token);
        Room room = roomRepository.findById(roomId)
            .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        if (!room.getHost().getUsername().equals(username))
            throw new ForbiddenException("Solo el host puede editar la sala");
        if (!room.isActive())
            throw new RuntimeException("La sala ya está cerrada");
        if (room.isFlagged())
            throw new ForbiddenException("Esta sala está bajo revisión del administrador y no puede editarse");

        if (request.getName() != null && !request.getName().isBlank())
            room.setName(request.getName().trim());
        room.setDescription(request.getDescription() != null
                ? request.getDescription().trim() : null);

        if (request.getGenres() != null) {
            if (!request.getGenres().isEmpty()) validateGenres(request.getGenres());
            room.setGenres(request.getGenres().isEmpty()
                    ? null : String.join(",", request.getGenres()));
        }

        if (request.getMaxParticipants() != null)
            room.setMaxParticipants(request.getMaxParticipants());

        if (request.getAutoDj() != null)
            room.setAutoDj(request.getAutoDj());

        // Personalización: null = no cambiar; cadena vacía = limpiar.
        if (request.getCoverImageUrl() != null)
            room.setCoverImageUrl(blankToNull(request.getCoverImageUrl()));
        if (request.getAccentColor() != null)
            room.setAccentColor(blankToNull(request.getAccentColor()));
        if (request.getWelcomeMessage() != null)
            room.setWelcomeMessage(blankToNull(request.getWelcomeMessage()));

        if (request.getPrivacy() != null) {
            String newPrivacy = request.getPrivacy().toUpperCase();
            room.setPrivacy(newPrivacy);
            if ("PRIVATE".equals(newPrivacy)) {
                if (request.getAccessCode() != null && !request.getAccessCode().isBlank()) {
                    room.setAccessCode(request.getAccessCode().trim());
                } else if (room.getAccessCode() == null) {
                    room.setAccessCode(generateCode());
                }
            } else {
                room.setAccessCode(null);
            }
        }

        Room saved = roomRepository.save(room);
        RoomResponse response = RoomResponse.from(saved, roomStateService.getState(roomId));

        if ("PUBLIC".equals(saved.getPrivacy())) {
            broadcastListEvent(RoomListEvent.Type.ROOM_UPDATED, roomId, response);
        } else {
            broadcastListEvent(RoomListEvent.Type.ROOM_CLOSED, roomId, null);
        }

        return response;
    }

    // ── Cerrar sala ───────────────────────────────────────────────────────────

    public void closeRoom(Long roomId, String token) {
        String username = jwtUtil.getUsernameFromToken(token);
        Room room = roomRepository.findById(roomId)
            .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        if (!room.getHost().getUsername().equals(username))
            throw new ForbiddenException("Solo el host puede cerrar la sala");

        room.setActive(false);
        roomRepository.save(room);

        broadcastListEvent(RoomListEvent.Type.ROOM_CLOSED, roomId, null);

        RoomMessage closedMsg = new RoomMessage();
        closedMsg.setType(RoomMessage.Type.ROOM_CLOSED);
        closedMsg.setSenderUsername(username);
        closedMsg.setServerTimestamp(System.currentTimeMillis());
        messagingTemplate.convertAndSend("/topic/room." + roomId, closedMsg);

        RoomState state = roomStateService.getState(roomId);
        if (state != null) userStatsService.endSessions(state.getOnlineUsers());

        roomStateService.clearState(roomId);
        firestoreChatService.clearMessages(roomId);
        firestoreQueueService.clearQueue(roomId);
    }

    // ── Unirse por código ─────────────────────────────────────────────────────

    public RoomResponse joinByCode(String accessCode, String username) {
        Room room = roomRepository.findByAccessCodeAndActiveTrue(accessCode)
            .orElseThrow(() -> new NotFoundException("Código inválido o sala cerrada"));

        if (room.isFlagged())
            throw new ForbiddenException("Esta sala no está disponible");

        if (room.getMaxParticipants() != null) {
            RoomState state = roomStateService.getOrCreate(room.getId());
            if (state.isFull(username))
                throw new RuntimeException("Sala llena");
        }

        return RoomResponse.from(room);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Devuelve la cadena recortada, o null si es null/vacía. */
    private String blankToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private String generateCode() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        StringBuilder sb = new StringBuilder();
        Random rnd = new Random();
        for (int i = 0; i < 6; i++) {
            sb.append(chars.charAt(rnd.nextInt(chars.length())));
        }
        return sb.toString();
    }

    public void notifyFlagChange(Room room, boolean nowFlagged) {
        if (!"PUBLIC".equals(room.getPrivacy())) return;
        if (nowFlagged) {
            broadcastListEvent(RoomListEvent.Type.ROOM_CLOSED, room.getId(), null);
        } else if (room.isActive()) {
            RoomResponse dto = RoomResponse.from(room, roomStateService.getState(room.getId()));
            broadcastListEvent(RoomListEvent.Type.ROOM_CREATED, room.getId(), dto);
        }
    }

    public void broadcastListEvent(RoomListEvent.Type type, Long roomId, RoomResponse room) {
        RoomListEvent event = new RoomListEvent();
        event.setType(type);
        event.setRoomId(roomId);
        event.setRoom(room);
        messagingTemplate.convertAndSend("/topic/rooms", event);
    }

    // ── Cerrar sala por admin ─────────────────────────────────────────────────

    public void forceCloseRoom(Long roomId) {
        Room room = roomRepository.findById(roomId)
            .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        room.setActive(false);
        roomRepository.save(room);

        broadcastListEvent(RoomListEvent.Type.ROOM_CLOSED, roomId, null);

        RoomMessage closedMsg = new RoomMessage();
        closedMsg.setType(RoomMessage.Type.ROOM_CLOSED);
        closedMsg.setSenderUsername("admin");
        closedMsg.setServerTimestamp(System.currentTimeMillis());
        messagingTemplate.convertAndSend("/topic/room." + roomId, closedMsg);

        RoomState state = roomStateService.getState(roomId);
        if (state != null) userStatsService.endSessions(state.getOnlineUsers());

        roomStateService.clearState(roomId);
        firestoreChatService.clearMessages(roomId);
        firestoreQueueService.clearQueue(roomId);
    }

    // ── Validar géneros ───────────────────────────────────────────────────────

    private void validateGenres(List<String> genres) {
        Set<String> valid = genreService.findAllNamesLowercase();
        if (valid.isEmpty()) return;
        for (String g : genres) {
            if (!valid.contains(g.toLowerCase()))
                throw new RuntimeException("Género no válido: '" + g + "'. Elige uno del catálogo.");
        }
    }
}
