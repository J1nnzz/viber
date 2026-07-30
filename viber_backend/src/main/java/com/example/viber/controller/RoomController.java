package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.CreateRoomRequest;
import com.example.viber.dto.UpdateRoomRequest;
import com.example.viber.dto.RoomResponse;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.Report;
import com.example.viber.model.RoomState;
import com.example.viber.repository.ReportRepository;
import com.example.viber.repository.RoomRepository;
import com.example.viber.service.FirestoreChatService;
import com.example.viber.service.RoomRecommendationService;
import com.example.viber.service.RoomService;
import com.example.viber.service.RoomStateService;
import com.example.viber.utils.JwtUtil;

/**
 * CRUD de salas y endpoint de estado en tiempo real.
 * El endpoint GET /{id}/state calcula la posición virtual del reproductor
 * para que los usuarios que entran puedan hacer seek al punto correcto.
 * El sistema de roles (HOST/DJ/LISTENER) y moderación se gestiona desde aquí
 * y desde el WebSocket (RoomWebSocketController).
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Salas", description = "Gestión de salas de música")
@RestController
@RequestMapping("/api/rooms")
@CrossOrigin(origins = "*")
public class RoomController {

    @Autowired private RoomService         roomService;
    @Autowired private RoomRepository      roomRepository;
    @Autowired private RoomStateService    roomStateService;
    @Autowired private FirestoreChatService firestoreChatService;
    @Autowired private JwtUtil             jwtUtil;
    @Autowired private ReportRepository    reportRepository;
    @Autowired private RoomRecommendationService recommendationService;

    // ── Helper ────────────────────────────────────────────────────────────────

    private String extractUsername(String authHeader) {
        return jwtUtil.getUsernameFromToken(authHeader.substring(7));
    }

    // ── POST /api/rooms — Crear sala ──────────────────────────────────────────

    @PostMapping
    public ResponseEntity<?> createRoom(
            @RequestBody CreateRoomRequest request,
            @RequestHeader("Authorization") String authHeader) {
        RoomResponse room = roomService.createRoom(request, authHeader.substring(7));
        return ResponseEntity.ok(room);
    }

    // ── GET /api/rooms — Listar salas públicas ────────────────────────────────

    @GetMapping
    public ResponseEntity<List<RoomResponse>> getPublicRooms() {
        return ResponseEntity.ok(roomService.getPublicRooms());
    }

    // ── GET /api/rooms/my — Salas del usuario autenticado (incluye privadas) ──

    @GetMapping("/my")
    public ResponseEntity<List<RoomResponse>> getMyRooms(
            @RequestHeader("Authorization") String authHeader) {
        String username = extractUsername(authHeader);
        return ResponseEntity.ok(roomService.getMyRooms(username));
    }

    // ── GET /api/rooms/recommended — Salas afines al gusto del usuario ────────

    @GetMapping("/recommended")
    public ResponseEntity<List<RoomResponse>> getRecommendedRooms(
            @RequestHeader("Authorization") String authHeader) {
        String username = extractUsername(authHeader);
        return ResponseEntity.ok(recommendationService.recommendFor(username));
    }

    // ── GET /api/rooms/{id} ───────────────────────────────────────────────────

    @GetMapping("/{id}")
    public ResponseEntity<?> getRoom(
            @PathVariable Long id,
            @RequestParam(required = false) String accessCode) {
        return ResponseEntity.ok(roomService.getRoom(id, accessCode));
    }

    // ── GET /api/rooms/{id}/state ─────────────────────────────────────────────

    @GetMapping("/{id}/state")
    public ResponseEntity<?> getRoomState(@PathVariable Long id) {
        RoomState state = roomStateService.getState(id);

        if (state == null) {
            roomRepository.findById(id).ifPresent(room -> {
                if (room.isActive()) {
                    roomStateService.initRoom(id, room.getHost().getUsername(), room.getMaxParticipants());
                }
            });
            state = roomStateService.getState(id);
        }

        RoomState snapshot = new RoomState();

        if (state != null) {
            snapshot.setCurrentVideoId(state.getCurrentVideoId());
            snapshot.setCurrentVideoTitle(state.getCurrentVideoTitle());
            snapshot.setCurrentVideoThumbnail(state.getCurrentVideoThumbnail());
            snapshot.setPlaying(state.isPlaying());
            snapshot.setLastUpdateTimestamp(state.getLastUpdateTimestamp());
            snapshot.setQueue(state.getQueue());
            snapshot.setHistory(state.getHistory());
            snapshot.setUserRoles(state.getUserRoles());
            snapshot.setMutedUsers(state.getMutedUsers());
            snapshot.setKickedUsers(state.getKickedUsers());
            snapshot.setOnlineUsers(state.getOnlineUsers());

            if (state.isPlaying() && state.getLastUpdateTimestamp() != null) {
                long refTimestamp = state.getLastEmptyTimestamp() != null
                        ? state.getLastEmptyTimestamp()
                        : state.getLastUpdateTimestamp();
                double elapsed = (System.currentTimeMillis() - refTimestamp) / 1000.0;
                snapshot.setCurrentPosition(state.getCurrentPosition() + elapsed);
            } else {
                snapshot.setCurrentPosition(state.getCurrentPosition());
            }
        }

        List<Map<String, Object>> chatHistory = firestoreChatService.loadHistory(id);
        snapshot.setChatHistory(chatHistory);

        return ResponseEntity.ok(snapshot);
    }

    // ── POST /api/rooms/join ──────────────────────────────────────────────────

    @PostMapping("/join")
    public ResponseEntity<?> joinByCode(
            @RequestBody Map<String, String> body,
            @RequestHeader("Authorization") String authHeader) {
        String username = extractUsername(authHeader);
        RoomResponse room = roomService.joinByCode(body.get("accessCode"), username);
        return ResponseEntity.ok(room);
    }

    // ── PUT /api/rooms/{id} ───────────────────────────────────────────────────

    @PutMapping("/{id}")
    public ResponseEntity<?> updateRoom(
            @PathVariable Long id,
            @RequestHeader("Authorization") String authHeader,
            @RequestBody UpdateRoomRequest request) {
        RoomResponse updated = roomService.updateRoom(id, request, authHeader.substring(7));
        return ResponseEntity.ok(updated);
    }

    // ── DELETE /api/rooms/{id} ────────────────────────────────────────────────

    @DeleteMapping("/{id}")
    public ResponseEntity<?> closeRoom(
            @PathVariable Long id,
            @RequestHeader("Authorization") String authHeader) {
        roomService.closeRoom(id, authHeader.substring(7));
        return ResponseEntity.ok(Map.of("message", "Sala cerrada"));
    }

    // ── POST /api/rooms/{id}/report ───────────────────────────────────────────

    @PostMapping("/{id}/report")
    public ResponseEntity<?> reportRoom(
            @PathVariable Long id,
            @RequestHeader("Authorization") String authHeader,
            @RequestBody Map<String, String> body) {
        String username = extractUsername(authHeader);

        String reason = body.getOrDefault("reason", "").trim();
        if (reason.isEmpty())
            throw new RuntimeException("El motivo no puede estar vacío");

        String roomName = roomRepository.findById(id)
                .map(r -> r.getName())
                .orElse("Sala desconocida");

        Report report = new Report();
        report.setRoomId(id);
        report.setRoomName(roomName);
        report.setReporterUsername(username);
        report.setReason(reason);
        reportRepository.save(report);

        return ResponseEntity.ok(Map.of("message", "Reporte enviado correctamente"));
    }

    // ── POST /api/rooms/{id}/roles ────────────────────────────────────────────

    @PostMapping("/{id}/roles")
    public ResponseEntity<?> changeRole(
            @PathVariable Long id,
            @RequestHeader("Authorization") String authHeader,
            @RequestBody Map<String, String> body) {
        String callerUsername = extractUsername(authHeader);
        String targetUsername = body.get("targetUsername");
        String newRole        = body.get("role");

        if (targetUsername == null || targetUsername.isBlank())
            throw new RuntimeException("targetUsername es obligatorio");
        if (!"DJ".equals(newRole) && !"LISTENER".equals(newRole))
            throw new RuntimeException("Rol inválido. Usa 'DJ' o 'LISTENER'");

        RoomState state = roomStateService.getState(id);
        if (state == null)
            throw new NotFoundException("Sala no encontrada o sin estado activo");
        if (!state.isHost(callerUsername))
            throw new ForbiddenException("Solo el host puede cambiar roles");
        if (state.isHost(targetUsername))
            throw new RuntimeException("No se puede cambiar el rol del host");

        state.getUserRoles().put(targetUsername, newRole);

        return ResponseEntity.ok(Map.of(
            "targetUsername", targetUsername,
            "role",           newRole,
            "message",        "Rol actualizado correctamente"
        ));
    }
}
