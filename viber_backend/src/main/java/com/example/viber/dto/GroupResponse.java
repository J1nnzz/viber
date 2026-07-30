package com.example.viber.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.example.viber.model.ChatGroup;
import com.example.viber.model.GroupMember;
import com.example.viber.model.GroupRole;

import lombok.Data;

/**
 * DTO de respuesta de un grupo.
 *
 * {@code myRole} es el rol del usuario que hace la petición, para que el cliente
 * sepa qué botones de administración mostrar. La lista {@code members} solo se
 * rellena en el detalle ({@link #detail}); en el listado ({@link #summary}) va a
 * null y se expone únicamente {@code memberCount}.
 */
@Data
public class GroupResponse {
    private Long id;
    private String name;
    private String description;
    private String photoUrl;
    private String ownerUsername;
    private LocalDateTime createdAt;
    private long memberCount;
    private String myRole;

    // Políticas de permiso (rol mínimo por acción)
    private String invitePolicy;
    private String editInfoPolicy;
    private String sendMessagePolicy;
    private String startQuizPolicy;

    private List<GroupMemberResponse> members;

    /** Versión ligera para el listado de "mis grupos" (sin la lista de miembros). */
    public static GroupResponse summary(ChatGroup g, GroupRole myRole, long memberCount) {
        GroupResponse dto = base(g, myRole);
        dto.setMemberCount(memberCount);
        return dto;
    }

    /** Versión completa para el detalle de un grupo (con todos los miembros). */
    public static GroupResponse detail(ChatGroup g, GroupRole myRole, List<GroupMember> members) {
        GroupResponse dto = base(g, myRole);
        dto.setMemberCount(members.size());
        dto.setMembers(members.stream().map(GroupMemberResponse::from).toList());
        return dto;
    }

    private static GroupResponse base(ChatGroup g, GroupRole myRole) {
        GroupResponse dto = new GroupResponse();
        dto.setId(g.getId());
        dto.setName(g.getName());
        dto.setDescription(g.getDescription());
        dto.setPhotoUrl(g.getPhotoUrl());
        dto.setOwnerUsername(g.getOwner().getUsername());
        dto.setCreatedAt(g.getCreatedAt());
        dto.setMyRole(myRole != null ? myRole.name() : null);
        dto.setInvitePolicy(g.getInvitePolicy().name());
        dto.setEditInfoPolicy(g.getEditInfoPolicy().name());
        dto.setSendMessagePolicy(g.getSendMessagePolicy().name());
        dto.setStartQuizPolicy(g.getStartQuizPolicy().name());
        return dto;
    }
}
