package com.example.viber.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.dto.CreateGroupRequest;
import com.example.viber.dto.GroupInvitationResponse;
import com.example.viber.dto.GroupResponse;
import com.example.viber.dto.UpdateGroupRequest;
import com.example.viber.dto.UpdatePermissionsRequest;
import com.example.viber.exception.ErrorCode;
import com.example.viber.exception.ConflictException;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.ChatGroup;
import com.example.viber.model.Friendship;
import com.example.viber.model.GroupInvitation;
import com.example.viber.model.GroupMember;
import com.example.viber.model.GroupPermission;
import com.example.viber.model.GroupRole;
import com.example.viber.model.User;
import com.example.viber.repository.ChatGroupRepository;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.GroupInvitationRepository;
import com.example.viber.repository.GroupMemberRepository;
import com.example.viber.repository.UserRepository;

/**
 * Lógica de grupos de chat: creación/listado/detalle, mensajería (entrega en
 * vivo por colas personales), invitaciones y administración (roles y permisos).
 *
 * Lo relacional (grupo, miembros, roles, invitaciones) vive en SQL; los mensajes
 * en Firestore vía {@link FirestoreGroupMessageService}, igual que los DM.
 *
 * La entrega en tiempo real se hace a {@code /user/{username}/queue/group} para
 * cada miembro (fan-out), de forma que un no-miembro no pueda escuchar el grupo
 * suscribiéndose a un topic abierto.
 */
@Service
public class GroupService {

    private static final int MAX_NAME_LEN = 80;
    private static final int MAX_DESC_LEN = 255;
    private static final int MAX_MSG_LEN  = 500;
    private static final int MAX_MEMBERS  = 100;

    private static final String PENDING = "PENDING";

    @Autowired private ChatGroupRepository        groupRepository;
    @Autowired private GroupMemberRepository      memberRepository;
    @Autowired private GroupInvitationRepository  invitationRepository;
    @Autowired private UserRepository             userRepository;
    @Autowired private FriendshipRepository       friendshipRepository;
    @Autowired private FirestoreGroupMessageService groupMessages;
    @Autowired private SimpMessagingTemplate      messagingTemplate;
    @Autowired private PushNotificationService    pushService;

    // ── Helpers de carga / validación ───────────────────────────────────────────

    public User requireUser(String username) {
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND, "Usuario no encontrado"));
    }

    public ChatGroup requireGroup(Long groupId) {
        return groupRepository.findById(groupId)
            .orElseThrow(() -> new NotFoundException(ErrorCode.GROUP_NOT_FOUND, "Grupo no encontrado"));
    }

    /** Devuelve la membresía del usuario o lanza 403 si no pertenece al grupo. */
    public GroupMember requireMembership(ChatGroup group, User user) {
        return memberRepository.findByGroupAndUser(group, user)
            .orElseThrow(() -> new ForbiddenException(ErrorCode.NOT_GROUP_MEMBER, "No perteneces a este grupo"));
    }

    /** Exige que el miembro cumpla una política de permiso del grupo. */
    private void requirePolicy(GroupMember member, GroupPermission policy, String action) {
        if (!policy.allows(member.getRole()))
            throw new ForbiddenException("No tienes permiso para " + action);
    }

    /** Exige que el miembro tenga al menos el rol indicado. */
    private void requireRole(GroupMember member, GroupRole min, String action) {
        if (!member.getRole().isAtLeast(min))
            throw new ForbiddenException("No tienes permiso para " + action);
    }

    private boolean areFriends(User a, User b) {
        return friendshipRepository.findBetween(a, b)
            .map(f -> f.getStatus() == Friendship.Status.ACCEPTED)
            .orElse(false);
    }

    // ── Crear / listar / detalle ────────────────────────────────────────────────

    @Transactional
    public GroupResponse createGroup(CreateGroupRequest req, String username) {
        User owner = requireUser(username);

        String name = req.getName() == null ? "" : req.getName().trim();
        if (name.isBlank())
            throw new RuntimeException("El nombre del grupo no puede estar vacío");
        if (name.length() > MAX_NAME_LEN)
            throw new RuntimeException("El nombre es demasiado largo (máx. " + MAX_NAME_LEN + ")");

        String description = req.getDescription() == null ? null : req.getDescription().trim();
        if (description != null && description.length() > MAX_DESC_LEN)
            throw new RuntimeException("La descripción es demasiado larga (máx. " + MAX_DESC_LEN + ")");

        ChatGroup group = new ChatGroup();
        group.setName(name);
        group.setDescription(description);
        group.setPhotoUrl(req.getPhotoUrl());
        group.setOwner(owner);
        group = groupRepository.save(group);

        GroupMember ownerMember = new GroupMember();
        ownerMember.setGroup(group);
        ownerMember.setUser(owner);
        ownerMember.setRole(GroupRole.OWNER);
        memberRepository.save(ownerMember);

        return GroupResponse.detail(group, GroupRole.OWNER, List.of(ownerMember));
    }

    @Transactional(readOnly = true)
    public List<GroupResponse> getMyGroups(String username) {
        User me = requireUser(username);
        return memberRepository.findByUser(me).stream()
            .map(m -> GroupResponse.summary(
                m.getGroup(),
                m.getRole(),
                memberRepository.countByGroup(m.getGroup())))
            .toList();
    }

    @Transactional(readOnly = true)
    public GroupResponse getGroupDetail(Long groupId, String username) {
        User me = requireUser(username);
        ChatGroup group = requireGroup(groupId);
        GroupMember mine = requireMembership(group, me);
        return GroupResponse.detail(group, mine.getRole(), memberRepository.findByGroup(group));
    }

    // ── Mensajería ──────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getMessages(Long groupId, String username) {
        ChatGroup group = requireGroup(groupId);
        requireMembership(group, requireUser(username));
        return groupMessages.getGroupMessages(groupId);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> sendMessage(Long groupId, String username, String rawText) {
        User me = requireUser(username);
        ChatGroup group = requireGroup(groupId);
        GroupMember member = requireMembership(group, me);
        requirePolicy(member, group.getSendMessagePolicy(), "enviar mensajes en este grupo");

        String text = rawText == null ? "" : rawText.trim();
        if (text.isEmpty()) throw new RuntimeException("El mensaje no puede estar vacío");
        if (text.length() > MAX_MSG_LEN)
            throw new RuntimeException("Mensaje demasiado largo (máx. " + MAX_MSG_LEN + ")");

        long ts = System.currentTimeMillis();
        groupMessages.sendGroupMessage(groupId, me.getUsername(), text);

        Map<String, Object> payload = new HashMap<>();
        payload.put("groupId",   groupId);
        payload.put("sender",    me.getUsername());
        payload.put("text",      text);
        payload.put("timestamp", ts);
        payload.put("type",      "USER");

        deliverToMembers(group, "/queue/group", payload);
        return payload;
    }

    /** Entrega un payload a la cola personal de cada miembro del grupo. */
    private void deliverToMembers(ChatGroup group, String destination, Object payload) {
        for (GroupMember m : memberRepository.findByGroup(group)) {
            messagingTemplate.convertAndSendToUser(
                m.getUser().getUsername(), destination, payload);
        }
    }

    /** Postea un mensaje de sistema en un grupo por id (usado p. ej. por el quiz en vivo). */
    @Transactional(readOnly = true)
    public void postSystemMessage(Long groupId, String text) {
        systemMessage(requireGroup(groupId), text);
    }

    /** Postea el resultado final de un quiz como tarjeta del grupo (con clasificación). */
    @Transactional(readOnly = true)
    public void postQuizResult(Long groupId, long matchId, String winner,
                               List<Map<String, Object>> standings) {
        ChatGroup group = requireGroup(groupId);
        groupMessages.sendResult(groupId, matchId, winner, standings);

        Map<String, Object> payload = new HashMap<>();
        payload.put("groupId",   group.getId());
        payload.put("sender",    "system");
        payload.put("text",      "Quiz terminado — ganó " + winner);
        payload.put("timestamp", System.currentTimeMillis());
        payload.put("type",      "QUIZ_RESULT");
        payload.put("matchId",   matchId);
        payload.put("winner",    winner);
        payload.put("standings", standings);
        deliverToMembers(group, "/queue/group", payload);
    }

    /** Postea un reto de quiz como mensaje del grupo (persistido + entregado en vivo). */
    @Transactional(readOnly = true)
    public void postQuizChallenge(Long groupId, String host, Long matchId, String mode, int rounds) {
        ChatGroup group = requireGroup(groupId);
        groupMessages.sendChallenge(groupId, host, matchId, mode, rounds);

        Map<String, Object> payload = new HashMap<>();
        payload.put("groupId",     group.getId());
        payload.put("sender",      host);
        payload.put("text",        host + " ha lanzado un duelo de quiz");
        payload.put("timestamp",   System.currentTimeMillis());
        payload.put("type",        "QUIZ_CHALLENGE");
        payload.put("matchId",     matchId);
        payload.put("mode",        mode);
        payload.put("totalRounds", rounds);
        deliverToMembers(group, "/queue/group", payload);
    }

    /** Mensaje de sistema persistido + entregado en vivo (altas, bajas, resultados…). */
    private void systemMessage(ChatGroup group, String text) {
        long ts = System.currentTimeMillis();
        groupMessages.sendSystemMessage(group.getId(), text);

        Map<String, Object> payload = new HashMap<>();
        payload.put("groupId",   group.getId());
        payload.put("sender",    "system");
        payload.put("text",      text);
        payload.put("timestamp", ts);
        payload.put("type",      "SYSTEM");
        deliverToMembers(group, "/queue/group", payload);
    }

    // ── Invitaciones ────────────────────────────────────────────────────────────

    @Transactional
    public void invite(Long groupId, String inviterUsername, String inviteeUsername) {
        User inviter = requireUser(inviterUsername);
        ChatGroup group = requireGroup(groupId);
        GroupMember inviterMember = requireMembership(group, inviter);
        requirePolicy(inviterMember, group.getInvitePolicy(), "invitar a este grupo");

        User invitee = requireUser(inviteeUsername);
        if (invitee.getId().equals(inviter.getId()))
            throw new RuntimeException("No puedes invitarte a ti mismo");
        if (!areFriends(inviter, invitee))
            throw new ForbiddenException(ErrorCode.ONLY_FRIENDS_CAN_BE_INVITED, "Solo puedes invitar a tus amigos");
        if (memberRepository.existsByGroupAndUser(group, invitee))
            throw new ConflictException(ErrorCode.ALREADY_IN_GROUP, "Ese usuario ya está en el grupo");
        if (invitationRepository.existsByGroupAndReceiverAndStatus(group, invitee, PENDING))
            throw new ConflictException(ErrorCode.INVITE_ALREADY_PENDING, "Ya hay una invitación pendiente para ese usuario");
        if (memberRepository.countByGroup(group) >= MAX_MEMBERS)
            throw new ConflictException(ErrorCode.GROUP_FULL, "El grupo ha alcanzado el máximo de miembros");

        GroupInvitation inv = new GroupInvitation();
        inv.setGroup(group);
        inv.setSender(inviter);
        inv.setReceiver(invitee);
        inv.setStatus(PENDING);
        invitationRepository.save(inv);

        pushService.sendToUser(invitee,
            "Invitación a un grupo",
            inviter.getUsername() + " te ha invitado al grupo \"" + group.getName() + "\"",
            java.util.Map.of("type", "group_invite", "groupId", group.getId().toString()));
    }

    @Transactional(readOnly = true)
    public List<GroupInvitationResponse> myInvitations(String username) {
        User me = requireUser(username);
        return invitationRepository.findByReceiverAndStatus(me, PENDING).stream()
            .map(GroupInvitationResponse::from)
            .toList();
    }

    /** Acepta o rechaza una invitación. Devuelve el grupo si se aceptó, null si no. */
    @Transactional
    public GroupResponse respondInvitation(Long invitationId, String username, boolean accept) {
        User me = requireUser(username);
        GroupInvitation inv = invitationRepository.findById(invitationId)
            .orElseThrow(() -> new NotFoundException(ErrorCode.INVITE_NOT_FOUND, "Invitación no encontrada"));
        if (!inv.getReceiver().getId().equals(me.getId()))
            throw new ForbiddenException(ErrorCode.INVITE_NOT_YOURS, "Esta invitación no es tuya");
        if (!PENDING.equals(inv.getStatus()))
            throw new ConflictException(ErrorCode.INVITE_ALREADY_ANSWERED, "La invitación ya fue respondida");

        if (!accept) {
            inv.setStatus("REJECTED");
            invitationRepository.save(inv);
            return null;
        }

        ChatGroup group = inv.getGroup();
        inv.setStatus("ACCEPTED");
        invitationRepository.save(inv);

        if (!memberRepository.existsByGroupAndUser(group, me)) {
            GroupMember member = new GroupMember();
            member.setGroup(group);
            member.setUser(me);
            member.setRole(GroupRole.MEMBER);
            memberRepository.save(member);
            systemMessage(group, me.getUsername() + " se ha unido al grupo");
        }

        return GroupResponse.detail(group, GroupRole.MEMBER, memberRepository.findByGroup(group));
    }

    // ── Administración ──────────────────────────────────────────────────────────

    @Transactional
    public void kickMember(Long groupId, String actorUsername, String targetUsername) {
        ChatGroup group = requireGroup(groupId);
        GroupMember actor  = requireMembership(group, requireUser(actorUsername));
        requireRole(actor, GroupRole.ADMIN, "expulsar miembros");

        GroupMember target = memberRepository
            .findByGroupAndUser(group, requireUser(targetUsername))
            .orElseThrow(() -> new NotFoundException(ErrorCode.NOT_GROUP_MEMBER, "Ese usuario no está en el grupo"));

        if (target.getRole() == GroupRole.OWNER)
            throw new ForbiddenException(ErrorCode.CANNOT_KICK_OWNER, "No se puede expulsar al propietario");
        if (!actor.getRole().isAtLeast(target.getRole()) ||
                actor.getRole().rank() == target.getRole().rank())
            throw new ForbiddenException(ErrorCode.CANNOT_KICK_SAME_OR_HIGHER, "No puedes expulsar a alguien con tu mismo rango o superior");

        memberRepository.delete(target);
        systemMessage(group, targetUsername + " fue expulsado del grupo");

        // Aviso personal al expulsado para que su cliente cierre el grupo
        Map<String, Object> ev = new HashMap<>();
        ev.put("groupId",   group.getId());
        ev.put("groupName", group.getName());
        messagingTemplate.convertAndSendToUser(targetUsername, "/queue/group-kick", ev);
    }

    @Transactional
    public void changeRole(Long groupId, String actorUsername, String targetUsername, String newRoleRaw) {
        ChatGroup group = requireGroup(groupId);
        GroupMember actor = requireMembership(group, requireUser(actorUsername));
        requireRole(actor, GroupRole.OWNER, "cambiar roles");

        GroupRole newRole = parseRole(newRoleRaw);
        if (newRole == GroupRole.OWNER)
            throw new RuntimeException("Usa transferir propiedad para asignar OWNER");

        GroupMember target = memberRepository
            .findByGroupAndUser(group, requireUser(targetUsername))
            .orElseThrow(() -> new NotFoundException(ErrorCode.NOT_GROUP_MEMBER, "Ese usuario no está en el grupo"));
        if (target.getRole() == GroupRole.OWNER)
            throw new ForbiddenException(ErrorCode.CANNOT_CHANGE_OWNER_ROLE, "No puedes cambiar el rol del propietario");

        target.setRole(newRole);
        memberRepository.save(target);

        String label = newRole == GroupRole.ADMIN ? "ahora es administrador" : "ya no es administrador";
        systemMessage(group, targetUsername + " " + label);
    }

    @Transactional
    public void transferOwnership(Long groupId, String ownerUsername, String targetUsername) {
        ChatGroup group = requireGroup(groupId);
        GroupMember owner = requireMembership(group, requireUser(ownerUsername));
        requireRole(owner, GroupRole.OWNER, "transferir la propiedad");

        GroupMember target = memberRepository
            .findByGroupAndUser(group, requireUser(targetUsername))
            .orElseThrow(() -> new NotFoundException(ErrorCode.NOT_GROUP_MEMBER, "Ese usuario no está en el grupo"));
        if (target.getId().equals(owner.getId()))
            throw new RuntimeException("Ya eres el propietario");

        owner.setRole(GroupRole.ADMIN);
        target.setRole(GroupRole.OWNER);
        group.setOwner(target.getUser());
        memberRepository.save(owner);
        memberRepository.save(target);
        groupRepository.save(group);

        systemMessage(group, targetUsername + " es ahora el propietario del grupo");
    }

    @Transactional
    public GroupResponse updateInfo(Long groupId, String actorUsername, UpdateGroupRequest req) {
        ChatGroup group = requireGroup(groupId);
        GroupMember actor = requireMembership(group, requireUser(actorUsername));
        requirePolicy(actor, group.getEditInfoPolicy(), "editar la información del grupo");

        if (req.getName() != null) {
            String name = req.getName().trim();
            if (name.isBlank())
                throw new RuntimeException("El nombre del grupo no puede estar vacío");
            if (name.length() > MAX_NAME_LEN)
                throw new RuntimeException("El nombre es demasiado largo (máx. " + MAX_NAME_LEN + ")");
            group.setName(name);
        }
        if (req.getDescription() != null) {
            String desc = req.getDescription().trim();
            if (desc.length() > MAX_DESC_LEN)
                throw new RuntimeException("La descripción es demasiado larga (máx. " + MAX_DESC_LEN + ")");
            group.setDescription(desc.isEmpty() ? null : desc);
        }
        if (req.getPhotoUrl() != null) {
            group.setPhotoUrl(req.getPhotoUrl().isBlank() ? null : req.getPhotoUrl());
        }
        groupRepository.save(group);
        return GroupResponse.detail(group, actor.getRole(), memberRepository.findByGroup(group));
    }

    @Transactional
    public GroupResponse updatePermissions(Long groupId, String actorUsername, UpdatePermissionsRequest req) {
        ChatGroup group = requireGroup(groupId);
        GroupMember actor = requireMembership(group, requireUser(actorUsername));
        requireRole(actor, GroupRole.ADMIN, "cambiar los permisos del grupo");

        if (req.getInvitePolicy() != null)
            group.setInvitePolicy(parsePermission(req.getInvitePolicy()));
        if (req.getEditInfoPolicy() != null)
            group.setEditInfoPolicy(parsePermission(req.getEditInfoPolicy()));
        if (req.getSendMessagePolicy() != null)
            group.setSendMessagePolicy(parsePermission(req.getSendMessagePolicy()));
        if (req.getStartQuizPolicy() != null)
            group.setStartQuizPolicy(parsePermission(req.getStartQuizPolicy()));

        groupRepository.save(group);
        return GroupResponse.detail(group, actor.getRole(), memberRepository.findByGroup(group));
    }

    @Transactional
    public void leaveGroup(Long groupId, String username) {
        ChatGroup group = requireGroup(groupId);
        User me = requireUser(username);
        GroupMember member = requireMembership(group, me);

        if (member.getRole() == GroupRole.OWNER) {
            long remaining = memberRepository.countByGroup(group);
            if (remaining > 1)
                throw new ConflictException(
                    "Transfiere la propiedad a otro miembro antes de salir del grupo");
            // El propietario es el último miembro → se borra el grupo
            deleteGroupInternal(group);
            return;
        }

        memberRepository.delete(member);
        systemMessage(group, username + " ha salido del grupo");
    }

    @Transactional
    public void deleteGroup(Long groupId, String username) {
        ChatGroup group = requireGroup(groupId);
        GroupMember actor = requireMembership(group, requireUser(username));
        requireRole(actor, GroupRole.OWNER, "borrar el grupo");
        deleteGroupInternal(group);
    }

    private void deleteGroupInternal(ChatGroup group) {
        Long groupId = group.getId();
        invitationRepository.deleteAll(invitationRepository.findByGroup(group));
        memberRepository.deleteAll(memberRepository.findByGroup(group));
        groupRepository.delete(group);
        groupMessages.deleteGroupMessages(groupId);   // limpia el historial en Firestore
    }

    // ── Parsers ─────────────────────────────────────────────────────────────────

    private static GroupRole parseRole(String raw) {
        try {
            return GroupRole.valueOf(raw.trim().toUpperCase());
        } catch (Exception e) {
            throw new RuntimeException("Rol no válido: " + raw);
        }
    }

    private static GroupPermission parsePermission(String raw) {
        try {
            return GroupPermission.valueOf(raw.trim().toUpperCase());
        } catch (Exception e) {
            throw new RuntimeException("Permiso no válido: " + raw);
        }
    }
}
