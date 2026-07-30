package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.ArtistPlayCount;
import com.example.viber.model.User;

/**
 * Acceso al tally de reproducciones por artista/canal de cada usuario.
 */
@Repository
public interface ArtistPlayCountRepository extends JpaRepository<ArtistPlayCount, Long> {
    Optional<ArtistPlayCount> findByUserAndArtistName(User user, String artistName);
    List<ArtistPlayCount> findTop5ByUserOrderByPlayCountDesc(User user);
}
