package com.example.viber.dto;

import lombok.Data;

/** DTO para el login clásico con username y contraseña. */
@Data
public class LoginRequest {
    private String username;
    private String password;
}