package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.Report;

/**
 * Acceso a la tabla de reportes enviados por usuarios sobre salas.
 * El admin puede filtrar por reportes pendientes (resolved=false) desde el panel.
 */
@Repository
public interface ReportRepository extends JpaRepository<Report, Long> {

    /** Todos los reportes, más recientes primero. */
    List<Report> findAllByOrderByCreatedAtDesc();

    /** Solo reportes pendientes (no resueltos). */
    List<Report> findByResolvedFalseOrderByCreatedAtDesc();

    /** Reportes de una sala concreta. */
    List<Report> findByRoomIdOrderByCreatedAtDesc(Long roomId);
}
