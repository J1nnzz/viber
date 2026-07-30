package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.LikedSong;
import com.example.viber.model.User;

/**
 * Acceso a la tabla de canciones favoritas.
 */
@Repository
public interface LikedSongRepository extends JpaRepository<LikedSong, Long> {
    List<LikedSong> findByUserOrderByLikedAtDesc(User user);
    Optional<LikedSong> findByUserAndVideoId(User user, String videoId);
    boolean existsByUserAndVideoId(User user, String videoId);
    long countByUser(User user);
    void deleteByUserAndVideoId(User user, String videoId);
}
