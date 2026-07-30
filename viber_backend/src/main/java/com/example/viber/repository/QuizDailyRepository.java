package com.example.viber.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.QuizDaily;
import com.example.viber.model.QuizMode;

/**
 * Acceso a las canciones del día del quiz.
 */
@Repository
public interface QuizDailyRepository extends JpaRepository<QuizDaily, Long> {

    Optional<QuizDaily> findByDateAndMode(LocalDate date, QuizMode mode);

    /** Dailies recientes de un modo — para no repetir canción en días seguidos. */
    List<QuizDaily> findByModeAndDateAfter(QuizMode mode, LocalDate after);

    /** Todos los retos de un día — para que cada modo tenga una canción DISTINTA. */
    List<QuizDaily> findByDate(LocalDate date);
}
