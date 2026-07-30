package com.example.viber.dto;

import java.time.LocalDateTime;

import com.example.viber.model.LikedSong;

import lombok.Data;

/**
 * DTO de respuesta para canciones favoritas — espejo de LikedSong.fromJson (Dart).
 * Evita serializar la relación {@code user} de la entidad.
 */
@Data
public class LikedSongResponse {
    private Long id;
    private String videoId;
    private String title;
    private String thumbnailUrl;
    private String channelTitle;
    private LocalDateTime likedAt;

    public static LikedSongResponse from(LikedSong likedSong) {
        LikedSongResponse dto = new LikedSongResponse();
        dto.setId(likedSong.getId());
        dto.setVideoId(likedSong.getVideoId());
        dto.setTitle(likedSong.getTitle());
        dto.setThumbnailUrl(likedSong.getThumbnailUrl());
        dto.setChannelTitle(likedSong.getChannelTitle());
        dto.setLikedAt(likedSong.getLikedAt());
        return dto;
    }
}
