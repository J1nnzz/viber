package com.example.viber.repository;

import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.viber.model.QuizSong;

/**
 * Acceso al catálogo de canciones del quiz.
 */
@Repository
public interface QuizSongRepository extends JpaRepository<QuizSong, Long> {

    boolean existsByVideoId(String videoId);

    List<QuizSong> findAllByOrderByCreatedAtDesc();

    /** Autocompletado del buscador de intentos: solo canciones activas. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND (LOWER(s.title) LIKE %:q% OR LOWER(s.artistName) LIKE %:q%)
        ORDER BY s.artistName ASC, s.title ASC
        """)
    List<QuizSong> searchActive(@Param("q") String lowercaseQuery, Pageable pageable);

    /**
     * Autocompletado del modo clásico: solo canciones con metadata completa,
     * porque cada intento debe poder pintar todas las casillas.
     */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.releaseYear IS NOT NULL
          AND s.genre IS NOT NULL
          AND s.durationSec IS NOT NULL
          AND (LOWER(s.title) LIKE %:q% OR LOWER(s.artistName) LIKE %:q%)
        ORDER BY s.artistName ASC, s.title ASC
        """)
    List<QuizSong> searchClassicEligible(@Param("q") String lowercaseQuery, Pageable pageable);

    /** Canciones jugables en modo clásico: metadata completa para las casillas. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.releaseYear IS NOT NULL
          AND s.genre IS NOT NULL
          AND s.durationSec IS NOT NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findClassicEligible();

    /** Canciones jugables en modo audio: con preview MP3 de Deezer. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.previewUrl IS NOT NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findAudioEligible();

    /**
     * Candidatas para el modo letra (con letra guardada).
     * El recuento mínimo de líneas se filtra en el servicio (isLyricsEligible).
     */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.lyrics IS NOT NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findLyricsCandidates();

    /** Canciones jugables en modo portada: con carátula. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.coverUrl IS NOT NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findCoverEligible();

    /** Canciones jugables en modo emoji: con emojis curados por un admin. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.emojis IS NOT NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findEmojiEligible();

    /** Canciones matcheadas en Deezer a las que aún les falta la letra. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.deezerTrackId IS NOT NULL
          AND s.lyrics IS NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findMissingLyrics();

    /** Canciones activas sin emojis curados ni generados todavía. */
    @Query("""
        SELECT s FROM QuizSong s
        WHERE s.active = true
          AND s.emojis IS NULL
        ORDER BY s.id ASC
        """)
    List<QuizSong> findMissingEmojis();
}
