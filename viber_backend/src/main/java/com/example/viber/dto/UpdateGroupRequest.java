package com.example.viber.dto;

import lombok.Data;

/** DTO para editar la info de un grupo. Campos a null = sin cambios. */
@Data
public class UpdateGroupRequest {
    private String name;
    private String description;
    private String photoUrl;
}
