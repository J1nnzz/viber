package com.example.viber.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.RoomMessage;
import com.example.viber.dto.RoomResponse;
import com.example.viber.exception.ErrorCode;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.Genre;
import com.example.viber.model.Report;
import com.example.viber.model.Room;
import com.example.viber.model.RoomState;
import com.example.viber.model.User;
import com.example.viber.repository.ReportRepository;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.GenreService;
import com.example.viber.service.RoomService;
import com.example.viber.service.RoomStateService;

/**
 * Todos los endpoints de este controlador están bajo /api/admin/**.
 * Spring Security (SecurityConfig) garantiza que solo llegan peticiones
 * con un JWT válido cuyo role sea ADMIN.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Admin", description = "Panel de administración (requiere rol ADMIN)")
@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    @Autowired private GenreService          genreService;
    @Autowired private RoomService           roomService;
    @Autowired private RoomRepository        roomRepository;
    @Autowired private UserRepository        userRepository;
    @Autowired private RoomStateService      roomStateService;
    @Autowired private ReportRepository      reportRepository;
    @Autowired private SimpMessagingTemplate messagingTemplate;

    // ── Géneros ───────────────────────────────────────────────────────────────

    @PostMapping("/genres")
    public ResponseEntity<?> addGenre(@RequestBody Map<String, String> body) {
        Genre genre = genreService.create(body.get("name"));
        return ResponseEntity.ok(genre);
    }

    @DeleteMapping("/genres/{id}")
    public ResponseEntity<?> deleteGenre(@PathVariable Long id) {
        genreService.delete(id);
        return ResponseEntity.ok(Map.of("message", "Género eliminado"));
    }

    // ── Salas ─────────────────────────────────────────────────────────────────

    @GetMapping("/rooms")
    public ResponseEntity<List<RoomResponse>> getAllRooms() {
        List<RoomResponse> rooms = roomRepository.findAll().stream()
                .map(room -> RoomResponse.from(room, roomStateService.getState(room.getId())))
                .collect(Collectors.toList());
        return ResponseEntity.ok(rooms);
    }

    @DeleteMapping("/rooms/{id}")
    public ResponseEntity<?> forceCloseRoom(@PathVariable Long id) {
        roomService.forceCloseRoom(id);
        return ResponseEntity.ok(Map.of("message", "Sala cerrada por administrador"));
    }

    @PostMapping("/rooms/{id}/kick-all")
    public ResponseEntity<?> kickAllUsers(@PathVariable Long id) {
        Room room = roomRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        if (!room.isActive())
            throw new RuntimeException("La sala ya está cerrada");

        RoomState state = roomStateService.getState(id);
        if (state == null || state.getOnlineUsers().isEmpty())
            return ResponseEntity.ok(Map.of("message", "No hay usuarios conectados en esta sala"));

        Set<String> users = Set.copyOf(state.getOnlineUsers());

        RoomMessage kickMsg = new RoomMessage();
        kickMsg.setType(RoomMessage.Type.USER_KICKED);
        kickMsg.setSenderUsername("admin");
        kickMsg.setServerTimestamp(System.currentTimeMillis());

        for (String username : users) {
            kickMsg.setTargetUsername(username);
            messagingTemplate.convertAndSendToUser(username, "/queue/kick", kickMsg);
            state.getOnlineUsers().remove(username);
        }

        return ResponseEntity.ok(Map.of(
                "message", "Usuarios echados de la sala",
                "kicked",  users.size()
        ));
    }

    @PutMapping("/rooms/{id}/flag")
    public ResponseEntity<?> toggleFlag(@PathVariable Long id,
                                        @RequestBody(required = false) Map<String, Object> body) {
        Room room = roomRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Sala no encontrada"));

        boolean nowFlagged = !room.isFlagged();
        room.setFlagged(nowFlagged);

        if (nowFlagged && body != null) {
            Object reasonObj = body.get("reason");
            if (reasonObj instanceof String s && !s.isBlank()) {
                room.setFlagReason(s.trim());
            }
        } else if (!nowFlagged) {
            room.setFlagReason(null);
        }

        roomRepository.save(room);
        roomService.notifyFlagChange(room, nowFlagged);

        int kicked = 0;
        if (nowFlagged && body != null && room.isActive()) {
            boolean kickAll   = Boolean.TRUE.equals(body.get("kickAll"));
            boolean closeRoom = Boolean.TRUE.equals(body.get("closeRoom"));

            RoomState state = roomStateService.getState(id);

            if (kickAll && state != null && !state.getOnlineUsers().isEmpty()) {
                Set<String> users = Set.copyOf(state.getOnlineUsers());
                RoomMessage kickMsg = new RoomMessage();
                kickMsg.setType(RoomMessage.Type.USER_KICKED);
                kickMsg.setSenderUsername("admin");
                kickMsg.setServerTimestamp(System.currentTimeMillis());
                for (String username : users) {
                    kickMsg.setTargetUsername(username);
                    messagingTemplate.convertAndSendToUser(username, "/queue/kick", kickMsg);
                    state.getOnlineUsers().remove(username);
                }
                kicked = users.size();
            }

            if (closeRoom) roomService.forceCloseRoom(id);
        }

        var responseMap = new HashMap<String, Object>();
        responseMap.put("id",      id);
        responseMap.put("flagged", nowFlagged);
        responseMap.put("message", nowFlagged ? "Sala marcada con incidencia" : "Incidencia retirada");
        if (kicked > 0) responseMap.put("kicked", kicked);
        return ResponseEntity.ok(responseMap);
    }

    @PutMapping("/rooms/{id}/flag/reason")
    public ResponseEntity<?> updateFlagReason(@PathVariable Long id,
                                               @RequestBody Map<String, String> body) {
        Room room = roomRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Sala no encontrada"));
        if (!room.isFlagged())
            throw new RuntimeException("La sala no tiene una incidencia activa");

        String reason = body.getOrDefault("reason", "").trim();
        room.setFlagReason(reason.isEmpty() ? null : reason);
        roomRepository.save(room);
        return ResponseEntity.ok(Map.of("message", "Nota actualizada"));
    }

    @GetMapping("/rooms/{id}")
    public ResponseEntity<?> getRoomFull(@PathVariable Long id) {
        Room room = roomRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Sala no encontrada"));
        RoomState state = roomStateService.getState(id);
        return ResponseEntity.ok(RoomResponse.from(room, state));
    }

    // ── Reportes ──────────────────────────────────────────────────────────────

    @GetMapping("/reports")
    public ResponseEntity<List<Report>> getReports(
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "false") boolean pending) {
        List<Report> reports = pending
                ? reportRepository.findByResolvedFalseOrderByCreatedAtDesc()
                : reportRepository.findAllByOrderByCreatedAtDesc();
        return ResponseEntity.ok(reports);
    }

    @PutMapping("/reports/{id}/resolve")
    public ResponseEntity<?> resolveReport(@PathVariable Long id) {
        Report report = reportRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Reporte no encontrado"));
        report.setResolved(true);
        reportRepository.save(report);
        return ResponseEntity.ok(Map.of("message", "Reporte marcado como resuelto"));
    }

    // ── Usuarios ──────────────────────────────────────────────────────────────

    @GetMapping("/users")
    public ResponseEntity<List<Map<String, Object>>> getAllUsers() {
        List<Map<String, Object>> users = userRepository.findAll().stream()
                .map(u -> Map.<String, Object>of(
                        "id",          u.getId(),
                        "username",    u.getUsername(),
                        "email",       u.getEmail(),
                        "role",        u.getRole().name(),
                        "displayName", u.getDisplayName() != null ? u.getDisplayName() : "",
                        "createdAt",   u.getCreatedAt() != null ? u.getCreatedAt().toString() : ""
                ))
                .collect(Collectors.toList());
        return ResponseEntity.ok(users);
    }

    @PutMapping("/users/{username}/role")
    public ResponseEntity<?> changeUserRole(@PathVariable String username,
                                             @RequestBody Map<String, String> body) {
        String newRoleStr = body.get("role");
        if (newRoleStr == null)
            throw new RuntimeException("El campo 'role' es obligatorio");

        User.UserRole newRole;
        try {
            newRole = User.UserRole.valueOf(newRoleStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new RuntimeException("Rol inválido. Usa 'ADMIN' o 'USER'");
        }

        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND, "Usuario no encontrado"));

        user.setRole(newRole);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "username", username,
                "role",     newRole.name(),
                "message",  "Rol actualizado correctamente"
        ));
    }
}
