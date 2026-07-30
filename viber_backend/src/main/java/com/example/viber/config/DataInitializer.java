package com.example.viber.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import com.example.viber.model.Genre;
import com.example.viber.repository.GenreRepository;

/**
 * Se ejecuta una sola vez al arrancar la aplicación.
 * Si la tabla de géneros está vacía, inserta un catálogo por defecto.
 * A partir de entonces el admin puede añadir/borrar géneros libremente
 * desde el panel de administración.
 */
@Component
public class DataInitializer implements CommandLineRunner {

    @Autowired
    private GenreRepository genreRepository;

    private static final List<String> DEFAULT_GENRES = List.of(
            "Pop", "Rock", "Hip-Hop", "Electronic", "Jazz",
            "Reggaeton", "Metal", "R&B", "Indie", "Latin",
            "Clásica", "Country", "Blues", "Funk", "House",
            "Techno", "Trap", "K-Pop", "Soul", "Folk"
    );

    @Override
    public void run(String... args) {
        if (genreRepository.count() == 0) {
            DEFAULT_GENRES.forEach(name -> {
                Genre g = new Genre();
                g.setName(name);
                genreRepository.save(g);
            });
            System.out.println("[DataInitializer] " + DEFAULT_GENRES.size()
                    + " géneros por defecto insertados.");
        }
    }
}
