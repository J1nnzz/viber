package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.SimilarArtistCache;

/** Caché del grafo de artistas similares, indexada por el nombre normalizado. */
@Repository
public interface SimilarArtistCacheRepository extends JpaRepository<SimilarArtistCache, String> {
}
