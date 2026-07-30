package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.UserStatsTotals;

/**
 * Acceso a los contadores acumulados de estadísticas por usuario (PK = userId).
 */
@Repository
public interface UserStatsTotalsRepository extends JpaRepository<UserStatsTotals, Long> {
}
