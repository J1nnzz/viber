package com.example.viber.dto;

import lombok.Data;

/**
 * DTO para crear una partida de quiz en vivo desde un chat.
 *
 * scope = "DM"    → duelo 1v1; {@code otherUsername} es el rival.
 * scope = "GROUP" → todos contra todos; {@code groupId} es el grupo.
 *
 * mode es el modo de pista (EMOJI | LYRICS | COVER | AUDIO).
 */
@Data
public class CreateMatchRequest {
    private String mode;
    private String scope;
    private String otherUsername;   // solo DM
    private Long   groupId;         // solo GROUP
    private Integer totalRounds;
    private Integer secondsPerRound;
}
