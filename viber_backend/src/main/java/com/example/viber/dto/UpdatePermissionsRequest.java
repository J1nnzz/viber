package com.example.viber.dto;

import lombok.Data;

/**
 * DTO para cambiar las políticas de permiso del grupo.
 * Cada campo es un {@link com.example.viber.model.GroupPermission}
 * ("ALL_MEMBERS" | "ADMINS_ONLY"); a null = sin cambios.
 */
@Data
public class UpdatePermissionsRequest {
    private String invitePolicy;
    private String editInfoPolicy;
    private String sendMessagePolicy;
    private String startQuizPolicy;
}
