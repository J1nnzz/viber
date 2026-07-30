package com.example.viber.dto;

import lombok.Data;

/** DTO para el registro clásico de un nuevo usuario. */
@Data
public class RegisterRequest {
    private String username;
    private String email;
    private String password;
}