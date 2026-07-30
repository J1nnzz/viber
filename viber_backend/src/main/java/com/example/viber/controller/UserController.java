package com.example.viber.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.Friendship;
import com.example.viber.model.Friendship.Status;
import com.example.viber.model.Room;
import com.example.viber.model.RoomInvitation;
import com.example.viber.model.User;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.RoomInvitationRepository;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.LikedSongService;
import com.example.viber.service.PresenceService;
import com.example.viber.service.PushNotificationService;
import com.example.viber.service.UserStatsService;
import com.example.viber.utils.JwtUtil;

/**
 * Gestión de perfiles de usuario, sistema de amigos e invitaciones a sala.
 * Todos los endpoints requieren JWT. Los métodos helper privados (userFromHeader, toMap,
 * getRelation) centralizan la lógica repetida de extracción de usuario y serialización.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Usuarios", description = "Perfiles, amigos e invitaciones")
@RestController
@RequestMapping("/api/user")
@CrossOrigin(origins = "*")
public class UserController {

    @Autowired private JwtUtil                  jwtUtil;
    @Autowired private UserRepository           userRepository;
    @Autowired private FriendshipRepository     friendshipRepository;
    @Autowired private PresenceService          presenceService;
    @Autowired private RoomRepository           roomRepository;
    @Autowired private RoomInvitationRepository invitationRepository;
    @Autowired private UserStatsService         userStatsService;
    @Autowired private LikedSongService         likedSongService;
    @Autowired private PushNotificationService  pushService;

    // ── Helpers ───────────────────────────────────────────────────────────────

    private User userFromHeader(String authHeader) {
        String token    = authHeader.substring(7);
        String username = jwtUtil.getUsernameFromToken(token);
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
    }

    private Map<String, Object> toMap(User u) {
        Map<String, Object> m = new HashMap<>();
        m.put("id",            u.getId());
        m.put("username",      u.getUsername());
        m.put("email",         u.getEmail());
        m.put("displayName",   u.getDisplayName());
        m.put("avatarUrl",     u.getAvatarUrl());
        m.put("bio",           u.getBio());
        m.put("createdAt",     u.getCreatedAt() != null ? u.getCreatedAt().toString() : null);
        m.put("profileHidden", u.isProfileHidden());
        return m;
    }

    private String getRelation(User caller, User target) {
        if (caller.getId().equals(target.getId())) return "SELF";
        var f = friendshipRepository.findBetween(caller, target);
        if (f.isEmpty()) return "NONE";
        if (f.get().getStatus() == Status.ACCEPTED) return "FRIENDS";
        return f.get().getRequester().getId().equals(caller.getId())
                ? "PENDING_SENT" : "PENDING_RECEIVED";
    }

    // ── GET /api/user/me ──────────────────────────────────────────────────────

    @GetMapping("/me")
    public ResponseEntity<?> getMe(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        Map<String, Object> resp = toMap(user);
        resp.put("friendCount",
            friendshipRepository.findAcceptedByUser(user, Status.ACCEPTED).size());
        return ResponseEntity.ok(resp);
    }

    // ── PUT /api/user/me ──────────────────────────────────────────────────────

    @PutMapping("/me")
    public ResponseEntity<?> updateMe(
            @RequestHeader("Authorization") String auth,
            @RequestBody Map<String, String> body) {
        User user = userFromHeader(auth);

        if (body.containsKey("username")) {
            String newUsername = body.get("username");
            if (newUsername == null || newUsername.isBlank())
                throw new RuntimeException("El nombre de usuario no puede estar vacío");
            if (newUsername.length() < 3 || newUsername.length() > 50)
                throw new RuntimeException("El nombre de usuario debe tener entre 3 y 50 caracteres");
            if (!newUsername.equals(user.getUsername())) {
                if (userRepository.findByUsername(newUsername).isPresent())
                    throw new RuntimeException("Ese nombre de usuario ya está en uso");
                user.setUsername(newUsername);
            }
        }

        if (body.containsKey("displayName")) {
            String dn = body.get("displayName");
            if (dn != null && dn.length() > 80)
                throw new RuntimeException("El nombre no puede superar 80 caracteres");
            user.setDisplayName(dn == null || dn.isBlank() ? null : dn.trim());
        }

        if (body.containsKey("bio")) {
            String bio = body.get("bio");
            if (bio != null && bio.length() > 150)
                throw new RuntimeException("La bio no puede superar 150 caracteres");
            user.setBio(bio == null || bio.isBlank() ? null : bio.trim());
        }

        if (body.containsKey("avatarUrl"))
            user.setAvatarUrl(body.get("avatarUrl"));

        if (body.containsKey("profileHidden"))
            user.setProfileHidden("true".equalsIgnoreCase(body.get("profileHidden")));

        userRepository.save(user);
        return ResponseEntity.ok(toMap(user));
    }

    // ── GET /api/user/search?q=xxx ────────────────────────────────────────────

    @GetMapping("/search")
    public ResponseEntity<?> searchUsers(
            @RequestParam String q,
            @RequestHeader("Authorization") String auth) {
        if (q == null || q.isBlank() || q.length() < 2) return ResponseEntity.ok(List.of());
        User caller = userFromHeader(auth);
        List<User> users = userRepository.searchByUsernameOrDisplayName(
            q.trim(), PageRequest.of(0, 10));

        List<Map<String, Object>> result = users.stream().map(target -> {
            Map<String, Object> m = toMap(target);
            m.put("relation", getRelation(caller, target));
            return m;
        }).collect(Collectors.toList());

        return ResponseEntity.ok(result);
    }

    // ── GET /api/user/{username} — Perfil público ────────────────────────────

    @GetMapping("/{username}")
    public ResponseEntity<?> getProfile(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        User caller = userFromHeader(auth);
        User target = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Map<String, Object> resp = toMap(target);
        resp.put("friendCount",
            friendshipRepository.findAcceptedByUser(target, Status.ACCEPTED).size());
        resp.put("relation", getRelation(caller, target));
        return ResponseEntity.ok(resp);
    }

    // ── GET /api/user/friends ─────────────────────────────────────────────────

    @GetMapping("/friends")
    public ResponseEntity<?> getFriends(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(
            friendshipRepository.findAcceptedByUser(user, Status.ACCEPTED)
                .stream()
                .map(f -> {
                    User friend = f.getRequester().getId().equals(user.getId())
                        ? f.getAddressee() : f.getRequester();
                    return toMap(friend);
                })
                .collect(Collectors.toList())
        );
    }

    // ── GET /api/user/friends/pending ─────────────────────────────────────────

    @GetMapping("/friends/pending")
    public ResponseEntity<?> getPending(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(
            friendshipRepository.findByAddresseeAndStatus(user, Status.PENDING)
                .stream()
                .map(f -> {
                    Map<String, Object> m = toMap(f.getRequester());
                    m.put("friendshipId", f.getId());
                    return m;
                })
                .collect(Collectors.toList())
        );
    }

    // ── POST /api/user/friends/request/{username} ─────────────────────────────

    @PostMapping("/friends/request/{username}")
    public ResponseEntity<?> sendRequest(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        User requester = userFromHeader(auth);
        User addressee = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        if (requester.getId().equals(addressee.getId()))
            throw new RuntimeException("No puedes enviarte una solicitud a ti mismo");
        if (addressee.isProfileHidden())
            throw new ForbiddenException("Este usuario no acepta solicitudes de amistad");
        if (friendshipRepository.findBetween(requester, addressee).isPresent())
            throw new RuntimeException("Ya existe una relación con este usuario");

        Friendship f = new Friendship();
        f.setRequester(requester);
        f.setAddressee(addressee);
        f.setStatus(Status.PENDING);
        friendshipRepository.save(f);

        pushService.sendToUser(addressee,
            "Nueva solicitud de amistad",
            requester.getUsername() + " quiere ser tu amigo",
            Map.of("type", "friend_request", "from", requester.getUsername()));

        return ResponseEntity.ok(Map.of("message", "Solicitud enviada"));
    }

    // ── POST /api/user/friends/accept/{username} ──────────────────────────────

    @PostMapping("/friends/accept/{username}")
    public ResponseEntity<?> acceptRequest(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        User addressee = userFromHeader(auth);
        User requester = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Friendship f = friendshipRepository.findBetween(requester, addressee)
            .orElseThrow(() -> new NotFoundException("Solicitud no encontrada"));

        if (f.getStatus() != Status.PENDING)
            throw new RuntimeException("La solicitud no está pendiente");
        if (!f.getAddressee().getId().equals(addressee.getId()))
            throw new ForbiddenException("No puedes aceptar esta solicitud");

        f.setStatus(Status.ACCEPTED);
        friendshipRepository.save(f);
        return ResponseEntity.ok(Map.of("message", "Solicitud aceptada"));
    }

    // ── DELETE /api/user/friends/{username} ───────────────────────────────────

    @DeleteMapping("/friends/{username}")
    public ResponseEntity<?> removeFriend(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        User caller = userFromHeader(auth);
        User other  = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Friendship f = friendshipRepository.findBetween(caller, other)
            .orElseThrow(() -> new NotFoundException("No existe relación con este usuario"));

        friendshipRepository.delete(f);
        return ResponseEntity.ok(Map.of("message", "Relación eliminada"));
    }

    // ── GET /api/user/friends/status ─────────────────────────────────────────

    @GetMapping("/friends/status")
    public ResponseEntity<?> getFriendsStatus(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        List<Map<String, Object>> result = friendshipRepository
            .findAcceptedByUser(user, Status.ACCEPTED)
            .stream()
            .map(f -> {
                User friend = f.getRequester().getId().equals(user.getId())
                    ? f.getAddressee() : f.getRequester();

                Map<String, Object> m = new HashMap<>();
                m.put("username",    friend.getUsername());
                m.put("displayName", friend.getDisplayName());
                m.put("avatarUrl",   friend.getAvatarUrl());

                Long roomId = presenceService.getRoomId(friend.getUsername());
                if (roomId != null) {
                    m.put("status", "IN_ROOM");
                    m.put("roomId", roomId);
                    roomRepository.findById(roomId).ifPresent(room ->
                        m.put("roomName", room.getName()));
                } else {
                    m.put("status", "OFFLINE");
                }
                return m;
            })
            .collect(Collectors.toList());

        return ResponseEntity.ok(result);
    }

    // ── POST /api/user/invite/{username} ──────────────────────────────────────

    @PostMapping("/invite/{username}")
    public ResponseEntity<?> inviteFriend(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth,
            @RequestBody Map<String, Object> body) {
        User sender   = userFromHeader(auth);
        User receiver = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Long roomId = body.get("roomId") != null
            ? Long.valueOf(body.get("roomId").toString()) : null;
        if (roomId == null)
            throw new RuntimeException("roomId es obligatorio");

        Room room = roomRepository.findById(roomId)
            .orElseThrow(() -> new NotFoundException("Sala no encontrada"));
        if (!room.isActive())
            throw new RuntimeException("La sala ya no está activa");

        if (invitationRepository.existsBySenderAndReceiverAndRoomIdAndStatus(
                sender, receiver, roomId, "PENDING")) {
            throw new RuntimeException("Ya existe una invitación pendiente para este usuario");
        }

        RoomInvitation inv = new RoomInvitation();
        inv.setSender(sender);
        inv.setReceiver(receiver);
        inv.setRoomId(roomId);
        inv.setRoomName(room.getName());
        inv.setAccessCode(room.getAccessCode());
        inv.setStatus("PENDING");
        invitationRepository.save(inv);

        pushService.sendToUser(receiver,
            "Invitación a una sala",
            sender.getUsername() + " te ha invitado a \"" + room.getName() + "\"",
            Map.of("type", "room_invite", "roomId", roomId.toString()));

        return ResponseEntity.ok(Map.of("message", "Invitación enviada a " + username));
    }

    // ── GET /api/user/me/invitations ──────────────────────────────────────────

    @GetMapping("/me/invitations")
    public ResponseEntity<?> getInvitations(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        List<Map<String, Object>> result = invitationRepository
            .findByReceiverAndStatus(user, "PENDING")
            .stream()
            .map(inv -> {
                Map<String, Object> m = new HashMap<>();
                m.put("id",           inv.getId());
                m.put("roomId",       inv.getRoomId());
                m.put("roomName",     inv.getRoomName());
                m.put("accessCode",   inv.getAccessCode());
                m.put("senderName",   inv.getSender().getUsername());
                m.put("senderAvatar", inv.getSender().getAvatarUrl());
                m.put("createdAt",    inv.getCreatedAt().toString());
                return m;
            })
            .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    // ── DELETE /api/user/me/invitations/{id} ──────────────────────────────────

    @DeleteMapping("/me/invitations/{id}")
    public ResponseEntity<?> dismissInvitation(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        RoomInvitation inv = invitationRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("Invitación no encontrada"));

        if (!inv.getReceiver().getId().equals(user.getId()))
            throw new ForbiddenException("No autorizado");

        inv.setStatus("DISMISSED");
        invitationRepository.save(inv);
        return ResponseEntity.ok(Map.of("message", "Invitación descartada"));
    }

    // ── GET /api/user/stats/me ────────────────────────────────────────────────

    @GetMapping("/stats/me")
    public ResponseEntity<?> getMyStats(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(userStatsService.getStats(user));
    }

    // ── GET /api/user/stats/{username} ────────────────────────────────────────

    @GetMapping("/stats/{username}")
    public ResponseEntity<?> getUserStats(
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        userFromHeader(auth);
        User target = userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));
        return ResponseEntity.ok(userStatsService.getStats(target));
    }

    // ── GET /api/user/liked-songs ─────────────────────────────────────────────

    @GetMapping("/liked-songs")
    public ResponseEntity<?> getLikedSongs(@RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(likedSongService.getLikedSongs(user));
    }

    // ── POST /api/user/liked-songs ────────────────────────────────────────────

    @PostMapping("/liked-songs")
    public ResponseEntity<?> likeSong(
            @RequestHeader("Authorization") String auth,
            @RequestBody Map<String, String> body) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(likedSongService.like(
            user,
            body.get("videoId"),
            body.get("title"),
            body.get("thumbnailUrl"),
            body.get("channelTitle")
        ));
    }

    // ── DELETE /api/user/liked-songs/{videoId} ────────────────────────────────

    @DeleteMapping("/liked-songs/{videoId}")
    public ResponseEntity<?> unlikeSong(
            @PathVariable String videoId,
            @RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        likedSongService.unlike(user, videoId);
        return ResponseEntity.ok(Map.of("message", "Eliminado de favoritos"));
    }

    // ── GET /api/user/liked-songs/{videoId}/status ────────────────────────────

    @GetMapping("/liked-songs/{videoId}/status")
    public ResponseEntity<?> getLikedStatus(
            @PathVariable String videoId,
            @RequestHeader("Authorization") String auth) {
        User user = userFromHeader(auth);
        return ResponseEntity.ok(Map.of("liked", likedSongService.isLiked(user, videoId)));
    }
}
