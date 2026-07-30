package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.QuizMatch;

/** Acceso a las cabeceras de partidas de quiz en vivo. */
@Repository
public interface QuizMatchRepository extends JpaRepository<QuizMatch, Long> {
}
