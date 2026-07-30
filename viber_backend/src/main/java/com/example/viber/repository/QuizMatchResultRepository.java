package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.QuizMatch;
import com.example.viber.model.QuizMatchResult;
import com.example.viber.model.User;

/** Acceso a las puntuaciones finales de partidas de quiz. */
@Repository
public interface QuizMatchResultRepository extends JpaRepository<QuizMatchResult, Long> {

    List<QuizMatchResult> findByMatchOrderByPositionAsc(QuizMatch match);

    List<QuizMatchResult> findByUser(User user);
}
