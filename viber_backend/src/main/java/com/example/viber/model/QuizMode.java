package com.example.viber.model;

/**
 * Modos del minijuego de adivinar canciones (tipo LoLdle).
 *
 * CLASSIC — intentos ilimitados; cada intento pinta casillas comparando
 *           artista, género, año, duración y explícito con la canción secreta.
 *
 * El resto son "modos de pista": 6 intentos y una pista que crece con cada
 * fallo o salto:
 * AUDIO   — fragmento del preview de 30 s cada vez más largo (1→2→4→7→12→30 s).
 * LYRICS  — una línea más de la letra por intento (título censurado).
 * COVER   — la portada se sirve pixelada y gana resolución por intento.
 * EMOJI   — un emoji más por intento (curados a mano por los admins).
 */
public enum QuizMode {
    CLASSIC,
    AUDIO,
    LYRICS,
    COVER,
    EMOJI;

    /** Modos con pista progresiva y 6 intentos (todos menos el clásico). */
    public boolean isClueMode() {
        return this != CLASSIC;
    }
}
