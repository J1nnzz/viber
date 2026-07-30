package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "reports")
@Data
@NoArgsConstructor
public class Report {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** ID de la sala reportada (se conserva aunque la sala se cierre). */
    @Column(name = "room_id", nullable = false)
    private Long roomId;

    /** Nombre de la sala en el momento del reporte (desnormalizado para trazabilidad). */
    @Column(name = "room_name", nullable = false, length = 100)
    private String roomName;

    /** Usuario que envió el reporte. */
    @Column(name = "reporter_username", nullable = false, length = 50)
    private String reporterUsername;

    /** Descripción del problema. */
    @Column(nullable = false, length = 500)
    private String reason;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    /** El admin marcó este reporte como revisado/resuelto. */
    @Column(nullable = false, columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private boolean resolved = false;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
