package com.example.viber.dto;

import java.time.LocalDateTime;

import com.example.viber.model.GroupInvitation;

import lombok.Data;

/** DTO de una invitación de grupo pendiente, tal como la ve el receptor en la campana. */
@Data
public class GroupInvitationResponse {
    private Long id;
    private Long groupId;
    private String groupName;
    private String groupPhotoUrl;
    private String senderName;
    private String senderAvatar;
    private LocalDateTime createdAt;

    public static GroupInvitationResponse from(GroupInvitation inv) {
        GroupInvitationResponse dto = new GroupInvitationResponse();
        dto.setId(inv.getId());
        dto.setGroupId(inv.getGroup().getId());
        dto.setGroupName(inv.getGroup().getName());
        dto.setGroupPhotoUrl(inv.getGroup().getPhotoUrl());
        dto.setSenderName(inv.getSender().getUsername());
        dto.setSenderAvatar(inv.getSender().getAvatarUrl());
        dto.setCreatedAt(inv.getCreatedAt());
        return dto;
    }
}
