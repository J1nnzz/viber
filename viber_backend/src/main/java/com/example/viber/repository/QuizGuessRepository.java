package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.QuizGame;
import com.example.viber.model.QuizGuess;

/**
 * Acceso a los intentos de las partidas del quiz.
 */
@Repository
public interface QuizGuessRepository extends JpaRepository<QuizGuess, Long> {

    List<QuizGuess> findByGameOrderByGuessOrderAsc(QuizGame game);

    int countByGame(QuizGame game);

    boolean existsByGameAndGuessedSongId(QuizGame game, Long guessedSongId);
}
