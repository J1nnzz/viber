package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.QuizSongResponse;
import com.example.viber.model.QuizSong;
import com.example.viber.service.QuizPoolService;

/**
 * Gestión del pool de canciones del quiz.
 * Bajo /api/admin/** — Spring Security exige rol ADMIN (ver SecurityConfig).
 *
 * El flujo del admin: importar una playlist de YouTube (cuesta ~1-2 unidades
 * de cuota por cada 50 vídeos), revisar las que Deezer no matcheó, corregir
 * título/artista y re-matchear, o completar la metadata a mano.
 */
@io.swagger.v3.oas.annotations.tags.Tag(name = "Admin Quiz", description = "Pool de canciones del quiz (requiere rol ADMIN)")
@RestController
@RequestMapping("/api/admin/quiz")
@CrossOrigin(origins = "*")
public class QuizAdminController {

    @Autowired private QuizPoolService quizPoolService;

    // POST /api/admin/quiz/import-playlist  body: {"url": "...", "max": 50}
    @PostMapping("/import-playlist")
    public ResponseEntity<?> importPlaylist(@RequestBody Map<String, Object> body) {
        String url = body.get("url") instanceof String s ? s.trim() : "";
        if (url.isEmpty()) throw new RuntimeException("Falta la URL de la playlist");

        int max = body.get("max") instanceof Number n ? n.intValue() : 50;
        return ResponseEntity.ok(quizPoolService.importPlaylist(url, max));
    }

    // POST /api/admin/quiz/songs  body: {"videoId": "...", "title": "...", "channel": "..."}
    @PostMapping("/songs")
    public ResponseEntity<QuizSongResponse> addSong(@RequestBody Map<String, String> body) {
        QuizSong song = quizPoolService.addSong(
            body.get("videoId"), body.get("title"), body.get("channel"));
        return ResponseEntity.ok(QuizSongResponse.forAdmin(song));
    }

    // GET /api/admin/quiz/songs — todo el pool, las más recientes primero
    @GetMapping("/songs")
    public ResponseEntity<List<QuizSongResponse>> songs() {
        return ResponseEntity.ok(
            quizPoolService.findAll().stream().map(QuizSongResponse::forAdmin).toList());
    }

    // PUT /api/admin/quiz/songs/{id} — editar metadata / activar / desactivar
    @PutMapping("/songs/{id}")
    public ResponseEntity<QuizSongResponse> update(
            @PathVariable Long id,
            @RequestBody Map<String, Object> changes) {
        return ResponseEntity.ok(QuizSongResponse.forAdmin(quizPoolService.update(id, changes)));
    }

    // POST /api/admin/quiz/songs/{id}/rematch — reintentar el match en Deezer
    @PostMapping("/songs/{id}/rematch")
    public ResponseEntity<QuizSongResponse> rematch(@PathVariable Long id) {
        return ResponseEntity.ok(QuizSongResponse.forAdmin(quizPoolService.rematch(id)));
    }

    // POST /api/admin/quiz/fetch-lyrics — buscar en lrclib las letras que faltan
    @PostMapping("/fetch-lyrics")
    public ResponseEntity<?> fetchLyrics() {
        return ResponseEntity.ok(quizPoolService.fetchMissingLyrics());
    }

    // POST /api/admin/quiz/suggest-emojis — generar con Claude los emojis que faltan
    @PostMapping("/suggest-emojis")
    public ResponseEntity<?> suggestEmojis() {
        return ResponseEntity.ok(quizPoolService.suggestMissingEmojis());
    }

    // DELETE /api/admin/quiz/songs/{id}
    @DeleteMapping("/songs/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        quizPoolService.delete(id);
        return ResponseEntity.ok(Map.of("message", "Canción eliminada del pool"));
    }
}
