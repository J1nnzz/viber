package com.example.viber.dto;

import lombok.Getter;

/**
 * Fila agregada del leaderboard tal y como la devuelve la query JPQL
 * (proyección por constructor). Una por usuario: suma de puntos y nº de
 * aciertos en la ventana consultada. El rango (posición) lo asigna el
 * {@code QuizLeaderboardService} al ordenar, no la base de datos.
 */
@Getter
public class LeaderboardEntry {

    private final Long   userId;
    private final String username;
    private final String displayName;
    private final String avatarUrl;
    private final long   points;
    private final long   solvedCount;

    // Las sumas de JPQL llegan como Long (y serían null si el grupo no tuviera
    // filas, cosa que aquí no pasa, pero las protegemos por si acaso).
    public LeaderboardEntry(Long userId, String username, String displayName,
                            String avatarUrl, Long points, Long solvedCount) {
        this.userId      = userId;
        this.username    = username;
        this.displayName = displayName;
        this.avatarUrl   = avatarUrl;
        this.points      = points      == null ? 0L : points;
        this.solvedCount = solvedCount == null ? 0L : solvedCount;
    }
}
