package com.example.viber.dto;

import lombok.Data;

@Data
public class ChangePasswordRequest {
    // Null si la cuenta es Google sin contraseña previa
    private String currentPassword;
    private String newPassword;
}