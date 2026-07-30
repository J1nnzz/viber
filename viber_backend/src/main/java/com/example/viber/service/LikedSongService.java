package com.example.viber.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.dto.LikedSongResponse;
import com.example.viber.model.LikedSong;
import com.example.viber.model.User;
import com.example.viber.repository.LikedSongRepository;

/**
 * Gestión de canciones favoritas: listar, dar/quitar like y comprobar estado.
 */
@Service
public class LikedSongService {

    @Autowired private LikedSongRepository likedSongRepository;

    @Transactional(readOnly = true)
    public List<LikedSongResponse> getLikedSongs(User user) {
        return likedSongRepository.findByUserOrderByLikedAtDesc(user)
            .stream()
            .map(LikedSongResponse::from)
            .collect(Collectors.toList());
    }

    /** Da like a una canción. Si ya estaba marcada, devuelve la existente sin duplicar. */
    @Transactional
    public LikedSongResponse like(User user, String videoId, String title, String thumbnailUrl, String channelTitle) {
        if (videoId == null || videoId.isBlank())
            throw new RuntimeException("videoId es obligatorio");
        if (title == null || title.isBlank())
            throw new RuntimeException("title es obligatorio");

        LikedSong existing = likedSongRepository.findByUserAndVideoId(user, videoId).orElse(null);
        if (existing != null) return LikedSongResponse.from(existing);

        LikedSong likedSong = new LikedSong();
        likedSong.setUser(user);
        likedSong.setVideoId(videoId);
        likedSong.setTitle(title);
        likedSong.setThumbnailUrl(thumbnailUrl);
        likedSong.setChannelTitle(channelTitle);

        return LikedSongResponse.from(likedSongRepository.save(likedSong));
    }

    /** Quita el like. No falla si no existía. */
    @Transactional
    public void unlike(User user, String videoId) {
        likedSongRepository.deleteByUserAndVideoId(user, videoId);
    }

    @Transactional(readOnly = true)
    public boolean isLiked(User user, String videoId) {
        return likedSongRepository.existsByUserAndVideoId(user, videoId);
    }
}
