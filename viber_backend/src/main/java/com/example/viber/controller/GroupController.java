package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
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
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.CreateGroupRequest;
import com.example.viber.dto.GroupInvitationResponse;
import com.example.viber.dto.GroupResponse;
import com.example.viber.dto.UpdateGroupRequest;
import com.example.viber.dto.UpdatePermissionsRequest;
import com.example.viber.service.GroupService;
import com.example.viber.utils.JwtUtil;

/**
 * Grupos de chat: creación, listado, mensajería, invitaciones y administración.
 *
 * La autenticación se resuelve en cada endpoint a partir del JWT del header
 * (igual que el resto de controllers); la autorización fina (membresía, roles,
 * políticas de permiso) la aplica {@link GroupService}.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Grupos", description = "Grupos de chat con varios miembros")
@RestController
@RequestMapping("/api/groups")
@CrossOrigin(origins = "*")
public class GroupController {

    @Autowired private GroupService groupService;
    @Autowired private JwtUtil      jwtUtil;

    private String extractUsername(String authHeader) {
        return jwtUtil.getUsernameFromToken(authHeader.substring(7));
    }

    // ── CRUD básico ─────────────────────────────────────────────────────────────

    @PostMapping
    public ResponseEntity<GroupResponse> createGroup(
            @RequestBody CreateGroupRequest request,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.createGroup(request, extractUsername(auth)));
    }

    @GetMapping("/my")
    public ResponseEntity<List<GroupResponse>> getMyGroups(
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.getMyGroups(extractUsername(auth)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<GroupResponse> getGroup(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.getGroupDetail(id, extractUsername(auth)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<GroupResponse> updateGroup(
            @PathVariable Long id,
            @RequestBody UpdateGroupRequest request,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.updateInfo(id, extractUsername(auth), request));
    }

    @PutMapping("/{id}/permissions")
    public ResponseEntity<GroupResponse> updatePermissions(
            @PathVariable Long id,
            @RequestBody UpdatePermissionsRequest request,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.updatePermissions(id, extractUsername(auth), request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteGroup(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        groupService.deleteGroup(id, extractUsername(auth));
        return ResponseEntity.ok(Map.of("message", "Grupo eliminado"));
    }

    // ── Mensajería ──────────────────────────────────────────────────────────────

    @GetMapping("/{id}/messages")
    public ResponseEntity<List<Map<String, Object>>> getMessages(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.getMessages(id, extractUsername(auth)));
    }

    @PostMapping("/{id}/messages")
    public ResponseEntity<?> sendMessage(
            @PathVariable Long id,
            @RequestBody Map<String, String> body,
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(
            groupService.sendMessage(id, extractUsername(auth), body.get("text")));
    }

    // ── Invitaciones ────────────────────────────────────────────────────────────

    @PostMapping("/{id}/invite/{username}")
    public ResponseEntity<?> invite(
            @PathVariable Long id,
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        groupService.invite(id, extractUsername(auth), username);
        return ResponseEntity.ok(Map.of("message", "Invitación enviada"));
    }

    @GetMapping("/invitations")
    public ResponseEntity<List<GroupInvitationResponse>> myInvitations(
            @RequestHeader("Authorization") String auth) {
        return ResponseEntity.ok(groupService.myInvitations(extractUsername(auth)));
    }

    @PostMapping("/invitations/{invId}/accept")
    public ResponseEntity<?> acceptInvitation(
            @PathVariable Long invId,
            @RequestHeader("Authorization") String auth) {
        GroupResponse group = groupService.respondInvitation(invId, extractUsername(auth), true);
        return ResponseEntity.ok(group);
    }

    @PostMapping("/invitations/{invId}/reject")
    public ResponseEntity<?> rejectInvitation(
            @PathVariable Long invId,
            @RequestHeader("Authorization") String auth) {
        groupService.respondInvitation(invId, extractUsername(auth), false);
        return ResponseEntity.ok(Map.of("message", "Invitación rechazada"));
    }

    // ── Administración de miembros ──────────────────────────────────────────────

    @DeleteMapping("/{id}/members/{username}")
    public ResponseEntity<?> kick(
            @PathVariable Long id,
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        groupService.kickMember(id, extractUsername(auth), username);
        return ResponseEntity.ok(Map.of("message", "Miembro expulsado"));
    }

    @PutMapping("/{id}/members/{username}/role")
    public ResponseEntity<?> changeRole(
            @PathVariable Long id,
            @PathVariable String username,
            @RequestBody Map<String, String> body,
            @RequestHeader("Authorization") String auth) {
        groupService.changeRole(id, extractUsername(auth), username, body.get("role"));
        return ResponseEntity.ok(Map.of("message", "Rol actualizado"));
    }

    @PostMapping("/{id}/transfer/{username}")
    public ResponseEntity<?> transfer(
            @PathVariable Long id,
            @PathVariable String username,
            @RequestHeader("Authorization") String auth) {
        groupService.transferOwnership(id, extractUsername(auth), username);
        return ResponseEntity.ok(Map.of("message", "Propiedad transferida"));
    }

    @PostMapping("/{id}/leave")
    public ResponseEntity<?> leave(
            @PathVariable Long id,
            @RequestHeader("Authorization") String auth) {
        groupService.leaveGroup(id, extractUsername(auth));
        return ResponseEntity.ok(Map.of("message", "Has salido del grupo"));
    }
}
