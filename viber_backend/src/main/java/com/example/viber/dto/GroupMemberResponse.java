package com.example.viber.dto;

import java.time.LocalDateTime;

import com.example.viber.model.GroupMember;
import com.example.viber.model.User;

import lombok.Data;

/** DTO de un miembro de grupo: identidad pública del usuario + su rol. */
@Data
public class GroupMemberResponse {
    private String username;
    private String displayName;
    private String avatarUrl;
    private String role;            // OWNER / ADMIN / MEMBER
    private LocalDateTime joinedAt;

    public static GroupMemberResponse from(GroupMember m) {
        User u = m.getUser();
        GroupMemberResponse dto = new GroupMemberResponse();
        dto.setUsername(u.getUsername());
        dto.setDisplayName(u.getDisplayName());
        dto.setAvatarUrl(u.getAvatarUrl());
        dto.setRole(m.getRole().name());
        dto.setJoinedAt(m.getJoinedAt());
        return dto;
    }
}
