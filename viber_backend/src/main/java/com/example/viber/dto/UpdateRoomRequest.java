package com.example.viber.dto;

import java.util.List;

import lombok.Data;

/**
 * DTO para editar una sala existente.
 * Si accessCode es null y la sala pasa a PRIVATE, el backend genera un código aleatorio.
 */
@Data
public class UpdateRoomRequest {
    private String name;
    private String description;
    private List<String> genres;
    private String privacy;      // "PUBLIC" | "PRIVATE"
    private String accessCode;   // Solo si privacy == "PRIVATE"; null = regenerar
    private Integer maxParticipants;
    private Boolean autoDj;      // null = no cambiar; true/false = activar/desactivar auto-DJ

    // ── Personalización (null = no cambiar; "" = limpiar) ──
    private String coverImageUrl;  // URL de portada en Cloudinary
    private String accentColor;    // Color de acento "#RRGGBB"
    private String welcomeMessage; // Mensaje de bienvenida
}
