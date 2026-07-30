package com.example.viber.dto;

import java.util.List;

import lombok.Data;

/** DTO para crear una nueva sala. El accessCode solo es obligatorio si privacy == "PRIVATE". */
@Data
public class CreateRoomRequest {
    private String name;
    private String description;
    private List<String> genres;
    private String privacy; // "PUBLIC" o "PRIVATE"
    private String accessCode; // Solo si privacy == "PRIVATE"
    private Integer maxParticipants;
    private Boolean autoDj; // Sala permanente con auto-DJ (null = false)

    // ── Personalización (todos opcionales) ──
    private String coverImageUrl;  // URL de portada en Cloudinary
    private String accentColor;    // Color de acento "#RRGGBB"
    private String welcomeMessage; // Mensaje de bienvenida
}
