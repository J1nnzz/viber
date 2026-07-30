package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.YoutubeResolution;

/** Caché de resolución consulta→videoId para el auto-DJ (ahorra cuota de YouTube). */
@Repository
public interface YoutubeResolutionRepository extends JpaRepository<YoutubeResolution, String> {
}
