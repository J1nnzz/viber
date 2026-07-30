package com.example.viber.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.Genre;

/**
 * Acceso a la tabla de géneros musicales.
 * {@code findByNameIgnoreCase} se usa al crear géneros para garantizar unicidad
 * independientemente de mayúsculas/minúsculas.
 */
@Repository
public interface GenreRepository extends JpaRepository<Genre, Long> {
    Optional<Genre> findByNameIgnoreCase(String name);
}
