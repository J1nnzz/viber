package com.example.viber.repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.viber.dto.LeaderboardEntry;
import com.example.viber.model.QuizDaily;
import com.example.viber.model.QuizGame;
import com.example.viber.model.QuizMode;
import com.example.viber.model.User;

/**
 * Acceso a las partidas del quiz.
 */
@Repository
public interface QuizGameRepository extends JpaRepository<QuizGame, Long> {

    Optional<QuizGame> findByUserAndDaily(User user, QuizDaily daily);

    /** Cuántos jugadores han acertado ya la canción del día. */
    long countByDailyAndSolvedTrue(QuizDaily daily);

    // ── Estadísticas del usuario ──────────────────────────────────────────────
    long countByUserAndModeAndPracticeAndFinishedTrue(User user, QuizMode mode, boolean practice);
    long countByUserAndModeAndPracticeAndSolvedTrue(User user, QuizMode mode, boolean practice);

    // ── Leaderboard ───────────────────────────────────────────────────────────
    // Suma de puntos por usuario sobre las diarias terminadas de la ventana
    // [from, to] (diario = hoy..hoy; mensual = día 1..hoy). La práctica nunca
    // cuenta. Empate: más aciertos. Solo partidas con points (las legacy sin
    // puntuar se ignoran). El ranking se calcula al leer: a esta escala sobra.

    @Query("""
        SELECT new com.example.viber.dto.LeaderboardEntry(
            u.id, u.username, u.displayName, u.avatarUrl,
            SUM(g.points), SUM(CASE WHEN g.solved = true THEN 1 ELSE 0 END))
        FROM QuizGame g JOIN g.user u
        WHERE g.practice = false AND g.finished = true AND g.points IS NOT NULL
          AND g.daily.date BETWEEN :from AND :to
        GROUP BY u.id, u.username, u.displayName, u.avatarUrl
        ORDER BY SUM(g.points) DESC, SUM(CASE WHEN g.solved = true THEN 1 ELSE 0 END) DESC
        """)
    List<LeaderboardEntry> leaderboard(@Param("from") LocalDate from,
                                       @Param("to") LocalDate to,
                                       Pageable pageable);

    /** Igual que {@link #leaderboard} pero acotado a un conjunto de usuarios (amigos). */
    @Query("""
        SELECT new com.example.viber.dto.LeaderboardEntry(
            u.id, u.username, u.displayName, u.avatarUrl,
            SUM(g.points), SUM(CASE WHEN g.solved = true THEN 1 ELSE 0 END))
        FROM QuizGame g JOIN g.user u
        WHERE g.practice = false AND g.finished = true AND g.points IS NOT NULL
          AND u.id IN :userIds
          AND g.daily.date BETWEEN :from AND :to
        GROUP BY u.id, u.username, u.displayName, u.avatarUrl
        ORDER BY SUM(g.points) DESC, SUM(CASE WHEN g.solved = true THEN 1 ELSE 0 END) DESC
        """)
    List<LeaderboardEntry> leaderboardForUsers(@Param("from") LocalDate from,
                                               @Param("to") LocalDate to,
                                               @Param("userIds") Collection<Long> userIds,
                                               Pageable pageable);

    /** Agregado del propio usuario en la ventana (para su fila aunque esté fuera del top). */
    @Query("""
        SELECT new com.example.viber.dto.LeaderboardEntry(
            u.id, u.username, u.displayName, u.avatarUrl,
            SUM(g.points), SUM(CASE WHEN g.solved = true THEN 1 ELSE 0 END))
        FROM QuizGame g JOIN g.user u
        WHERE g.user = :user AND g.practice = false AND g.finished = true
          AND g.points IS NOT NULL
          AND g.daily.date BETWEEN :from AND :to
        GROUP BY u.id, u.username, u.displayName, u.avatarUrl
        """)
    Optional<LeaderboardEntry> myAggregate(@Param("user") User user,
                                           @Param("from") LocalDate from,
                                           @Param("to") LocalDate to);

    // ── Racha ──────────────────────────────────────────────────────────────────

    /** Diarias resueltas por el usuario en una fecha concreta (para el bonus de racha). */
    @Query("""
        SELECT COUNT(g) FROM QuizGame g
        WHERE g.user = :user AND g.practice = false AND g.solved = true
          AND g.daily.date = :date
        """)
    long countSolvedDailyOn(@Param("user") User user, @Param("date") LocalDate date);

    /** Fechas (distintas) en que el usuario resolvió al menos una diaria. */
    @Query("""
        SELECT DISTINCT g.daily.date FROM QuizGame g
        WHERE g.user = :user AND g.practice = false AND g.solved = true
        """)
    List<LocalDate> solvedDailyDates(@Param("user") User user);
}
