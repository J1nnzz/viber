package com.example.viber.dto;

import java.util.List;

import lombok.Data;

/**
 * Estado completo de una partida del quiz tal y como lo ve el cliente.
 * La canción secreta solo aparece en {@code answer} cuando finished = true.
 *
 * Convenciones de las casillas (modo clásico):
 *   status:    CORRECT (verde) | CLOSE (amarillo) | WRONG (rojo)
 *   direction: HIGHER → el valor de la respuesta es MAYOR que el del intento (↑),
 *              LOWER → menor (↓), EQUAL → igual. Solo en año y duración.
 */
@Data
public class QuizGameStateResponse {

    private Long gameId;
    private String mode;            // CLASSIC | AUDIO
    private boolean practice;
    private String date;            // solo partidas diarias (yyyy-MM-dd)

    private boolean finished;
    private boolean solved;
    private int attemptsUsed;

    // ── Modos de pista (audio, letra, portada, emoji) ─────────────────────────
    private Integer maxAttempts;        // 6 en modos de pista, null en clásico

    // Audio
    private Integer unlockedSeconds;    // segundos de preview desbloqueados
    private List<Integer> snippetSteps; // [1, 2, 4, 7, 12, 30]

    // Letra: líneas visibles, con el título censurado hasta terminar
    private List<String> lyricsLines;

    // Emoji: pista visible ("🌧️ 🔥") y total de emojis de la canción
    private String emojisVisible;
    private Integer emojisTotal;

    // Portada: no viaja en el estado — se sirve pixelada por GET /games/{id}/cover

    // ── Pistas (modo clásico) ─────────────────────────────────────────────────
    private Hints hints;

    private List<GuessView> guesses;

    /** Respuesta revelada — solo cuando finished = true. */
    private QuizSongResponse answer;

    /** Cuántos jugadores han acertado ya el reto diario (null en práctica). */
    private Long dailySolvedCount;

    /** Puntos de ranking ganados en esta partida — solo diaria terminada. */
    private Integer pointsEarned;

    // ── Tipos anidados ────────────────────────────────────────────────────────

    @Data
    public static class Hints {
        private int coverUnlockAt;      // nº de fallos para desbloquear la portada
        private int titleUnlockAt;      // nº de fallos para desbloquear la inicial
        private String coverUrl;        // null hasta desbloquear
        private String titleHint;       // p.ej. "B······· R·······" — null hasta desbloquear
    }

    @Data
    public static class GuessView {
        private QuizSongResponse song;  // null si fue un "saltar"
        private boolean skipped;
        private boolean correct;
        private Boolean artistMatch;    // modo audio: mismo artista (amarillo)
        private FieldView artist;       // modo clásico ↓
        private FieldView genre;
        private FieldView year;
        private FieldView duration;
        private FieldView explicit;
    }

    @Data
    public static class FieldView {
        private String value;           // valor del intento, ya formateado
        private String status;          // CORRECT | CLOSE | WRONG
        private String direction;       // HIGHER | LOWER | EQUAL | null

        public static FieldView of(String value, String status, String direction) {
            FieldView f = new FieldView();
            f.setValue(value);
            f.setStatus(status);
            f.setDirection(direction);
            return f;
        }
    }
}
