package com.example.viber.dto;

import lombok.Data;

/** DTO para crear un grupo. Solo el nombre es obligatorio; foto y descripción son opcionales. */
@Data
public class CreateGroupRequest {
    private String name;
    private String description;
    private String photoUrl;
}
