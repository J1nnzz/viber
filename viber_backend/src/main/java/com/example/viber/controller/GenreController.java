package com.example.viber.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.model.Genre;
import com.example.viber.service.GenreService;

/**
 * Devuelve el catálogo de géneros musicales disponibles para etiquetar salas.
 * Endpoint público — no requiere JWT. La gestión (crear/borrar) está en AdminController.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Géneros", description = "Catálogo de géneros musicales")
@RestController
@RequestMapping("/api/genres")
@CrossOrigin(origins = "*")
public class GenreController {

    @Autowired
    private GenreService genreService;

    // GET /api/genres — público, devuelve el catálogo de géneros disponibles
    @GetMapping
    public ResponseEntity<List<Genre>> getGenres() {
        return ResponseEntity.ok(genreService.findAll());
    }
}
