package com.example.viber.dto;

import java.util.List;

import lombok.Data;

/**
 * Respuesta del leaderboard del quiz.
 *
 * scope:  world | friends   (mundial o solo entre amigos)
 * period: daily | month     (hoy o lo que va de mes)
 *
 * {@code entries} ya viene ordenada y con el rango asignado. {@code me} resume
 * la posición del propio usuario (aunque quede fuera del top mostrado) y su
 * racha, que es independiente de la ventana consultada.
 */
@Data
public class LeaderboardResponse {

    private String scope;
    private String period;
    private List<Row> entries;
    private Me me;

    @Data
    public static class Row {
        private int     rank;
        private Long    userId;
        private String  username;
        private String  displayName;
        private String  avatarUrl;
        private long    points;
        private long    solvedCount;
        private boolean me;        // true si es la fila del usuario que consulta
    }

    @Data
    public static class Me {
        private Integer rank;          // null si aún no ha jugado en la ventana
        private boolean ranked;        // false si no tiene partidas puntuadas en la ventana
        private long    points;
        private long    solvedCount;
        private int     currentStreak; // días seguidos resolviendo al menos una diaria
        private int     bestStreak;
    }
}
