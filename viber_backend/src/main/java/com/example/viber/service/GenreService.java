package com.example.viber.service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.example.viber.model.Genre;
import com.example.viber.repository.GenreRepository;

/**
 * Gestión del catálogo de géneros musicales.
 * Valida unicidad (case-insensitive) antes de crear. El método
 * {@code findAllNamesLowercase()} lo usa {@link RoomService} para validar
 * los géneros que el usuario asigna a una sala.
 */
@Service
public class GenreService {

    @Autowired
    private GenreRepository genreRepository;

    public List<Genre> findAll() {
        return genreRepository.findAll();
    }

    public Genre create(String name) {
        if (name == null || name.isBlank()) {
            throw new RuntimeException("El nombre del género no puede estar vacío");
        }
        String trimmed = name.trim();
        if (genreRepository.findByNameIgnoreCase(trimmed).isPresent()) {
            throw new RuntimeException("El género '" + trimmed + "' ya existe");
        }
        Genre genre = new Genre();
        genre.setName(trimmed);
        return genreRepository.save(genre);
    }

    public void delete(Long id) {
        if (!genreRepository.existsById(id)) {
            throw new RuntimeException("Género no encontrado");
        }
        genreRepository.deleteById(id);
    }

    /** Devuelve el conjunto de nombres en minúscula para validar géneros de salas. */
    public Set<String> findAllNamesLowercase() {
        return genreRepository.findAll().stream()
                .map(g -> g.getName().toLowerCase())
                .collect(Collectors.toSet());
    }
}
