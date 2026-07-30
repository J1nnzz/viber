package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Canción del catálogo del quiz (pool cerrado, estilo LoLdle).
 *
 * Se siembra desde playlists de YouTube (videoId, título bruto) y se enriquece
 * con metadata estructurada de la API pública de Deezer (artista, año, género,
 * duración, explícito, preview MP3 de 30 s y portada). Los campos de metadata
 * son nullable: una canción sin matchear en Deezer queda "incompleta" y no
 * entra en juego hasta que un admin la complete (ver elegibilidad en QuizGameService).
 */
@Entity
@Table(
    name = "quiz_songs",
    uniqueConstraints = @UniqueConstraint(columnNames = {"video_id"})
)
@Data
@NoArgsConstructor
public class QuizSong {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** ID del vídeo de YouTube — permite reproducir la canción con el player existente. */
    @Column(name = "video_id", nullable = false, length = 50)
    private String videoId;

    /** Título limpio de la canción (sin "(Official Video)" y similares). */
    @Column(nullable = false, length = 255)
    private String title;

    @Column(name = "artist_name", nullable = false, length = 150)
    private String artistName;

    @Column(name = "album_title", length = 255)
    private String albumTitle;

    @Column(name = "release_year")
    private Integer releaseYear;

    @Column(length = 80)
    private String genre;

    @Column(name = "duration_sec")
    private Integer durationSec;

    @Column
    private Boolean explicit;

    /** URL del preview MP3 de 30 s de Deezer (modo audio). */
    @Column(name = "preview_url", length = 500)
    private String previewUrl;

    @Column(name = "cover_url", length = 500)
    private String coverUrl;

    @Column(name = "deezer_track_id")
    private Long deezerTrackId;

    /** Letra en texto plano (lrclib.net) — modo letra. */
    @Column(columnDefinition = "TEXT")
    private String lyrics;

    /** Emojis que describen la canción, separados por espacios — modo emoji (curado a mano). */
    @Column(length = 120)
    private String emojis;

    /** Interruptor del admin: false = fuera del pool sin borrar el historial. */
    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    /** Metadata completa para jugar en modo clásico (las casillas necesitan estos campos). */
    public boolean isClassicEligible() {
        return active && releaseYear != null && genre != null && durationSec != null;
    }

    /** El modo audio solo necesita el preview de 30 s. */
    public boolean isAudioEligible() {
        return active && previewUrl != null && !previewUrl.isBlank();
    }

    /** Mínimo de líneas útiles para que el modo letra tenga 6 pistas con margen. */
    public static final int MIN_LYRICS_LINES = 8;

    /** El modo letra necesita una letra con suficientes líneas no vacías. */
    public boolean isLyricsEligible() {
        return active && lyrics != null && usableLyricsLines() >= MIN_LYRICS_LINES;
    }

    public int usableLyricsLines() {
        if (lyrics == null) return 0;
        return (int) lyrics.lines().filter(l -> !l.isBlank()).count();
    }

    /** El modo portada solo necesita la carátula. */
    public boolean isCoverEligible() {
        return active && coverUrl != null && !coverUrl.isBlank();
    }

    /** El modo emoji necesita que un admin haya curado los emojis. */
    public boolean isEmojiEligible() {
        return active && emojis != null && !emojis.isBlank();
    }
}
