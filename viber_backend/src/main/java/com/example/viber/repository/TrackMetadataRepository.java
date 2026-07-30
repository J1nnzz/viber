package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.TrackMetadata;

/**
 * Cache de metadatos por canción. La clave primaria es el videoId (String), así que
 * {@code findById}/{@code existsById}/{@code findAllById} ya sirven para todo:
 * lookup individual al enriquecer y lookup en lote al construir perfiles.
 */
@Repository
public interface TrackMetadataRepository extends JpaRepository<TrackMetadata, String> {
}
