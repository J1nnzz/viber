package com.example.viber.dto;

import com.example.viber.model.QuizSong;

import lombok.Data;

/**
 * Vistas de una canción del pool del quiz.
 *
 * - {@link #forAutocomplete}: lo mínimo para el buscador de intentos
 *   (sin año/género/duración para no regalar pistas).
 * - {@link #forAdmin}: todos los campos editables del panel.
 * - {@link #forReveal}: la respuesta completa al terminar una partida.
 */
@Data
public class QuizSongResponse {
    private Long id;
    private String title;
    private String artistName;
    private String coverUrl;

    // Solo admin / reveal
    private String videoId;
    private String albumTitle;
    private Integer releaseYear;
    private String genre;
    private Integer durationSec;
    private Boolean explicit;
    private Boolean active;
    private Boolean hasPreview;
    private Boolean hasLyrics;
    private String lyrics;      // solo admin (editable en el panel)
    private String emojis;      // solo admin (curado a mano)

    public static QuizSongResponse forAutocomplete(QuizSong s) {
        QuizSongResponse dto = new QuizSongResponse();
        dto.setId(s.getId());
        dto.setTitle(s.getTitle());
        dto.setArtistName(s.getArtistName());
        dto.setCoverUrl(s.getCoverUrl());
        return dto;
    }

    public static QuizSongResponse forReveal(QuizSong s) {
        QuizSongResponse dto = forAutocomplete(s);
        dto.setVideoId(s.getVideoId());
        dto.setAlbumTitle(s.getAlbumTitle());
        dto.setReleaseYear(s.getReleaseYear());
        dto.setGenre(s.getGenre());
        dto.setDurationSec(s.getDurationSec());
        dto.setExplicit(s.getExplicit());
        return dto;
    }

    public static QuizSongResponse forAdmin(QuizSong s) {
        QuizSongResponse dto = forReveal(s);
        dto.setActive(s.isActive());
        dto.setHasPreview(s.getPreviewUrl() != null && !s.getPreviewUrl().isBlank());
        dto.setHasLyrics(s.isLyricsEligible());
        dto.setLyrics(s.getLyrics());
        dto.setEmojis(s.getEmojis());
        return dto;
    }
}
