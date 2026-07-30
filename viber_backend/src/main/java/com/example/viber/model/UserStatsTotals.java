package com.example.viber.model;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Contadores acumulados de estadísticas de un usuario.
 * La PK es el mismo id que User (relación 1:1 sin FK explícita); la fila se
 * crea de forma perezosa la primera vez que hay algo que registrar.
 */
@Entity
@Table(name = "user_stats")
@Data
@NoArgsConstructor
public class UserStatsTotals {

    @Id
    private Long userId;

    private long totalListenSeconds = 0L;

    private int songsAdded = 0;

    private int songsPlayed = 0;
}
