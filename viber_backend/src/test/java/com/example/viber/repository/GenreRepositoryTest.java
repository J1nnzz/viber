package com.example.viber.repository;

import com.example.viber.model.Genre;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GenreRepositoryTest {

    @Mock
    private GenreRepository genreRepository;

    private Genre buildGenre(Long id, String name) {
        Genre genre = new Genre();
        genre.setId(id);
        genre.setName(name);
        return genre;
    }

    @Test
    void findByNameIgnoreCase_existingGenre_returnsGenre() {
        when(genreRepository.findByNameIgnoreCase("rock")).thenReturn(Optional.of(buildGenre(1L, "Rock")));

        Optional<Genre> found = genreRepository.findByNameIgnoreCase("rock");

        assertTrue(found.isPresent());
        assertEquals("Rock", found.get().getName());
    }

    @Test
    void findByNameIgnoreCase_nonExistingGenre_returnsEmpty() {
        when(genreRepository.findByNameIgnoreCase("Metal")).thenReturn(Optional.empty());

        Optional<Genre> found = genreRepository.findByNameIgnoreCase("Metal");

        assertTrue(found.isEmpty());
    }

    @Test
    void findAll_returnsAllGenres() {
        when(genreRepository.findAll()).thenReturn(List.of(buildGenre(1L, "Rock"), buildGenre(2L, "Jazz")));

        List<Genre> result = genreRepository.findAll();

        assertEquals(2, result.size());
    }
}
