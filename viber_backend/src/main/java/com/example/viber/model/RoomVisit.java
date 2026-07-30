package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Registra que un usuario se ha conectado alguna vez a una sala ajena.
 * El par (user, room) es único: solo cuenta la primera visita para las
 * estadísticas de "salas unidas" y "géneros más escuchados".
 */
@Entity
@Table(
    name = "room_visits",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "room_id"})
)
@Data
@NoArgsConstructor
public class RoomVisit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id", nullable = false)
    private Room room;

    @Column(name = "first_visited_at", updatable = false)
    private LocalDateTime firstVisitedAt;

    @PrePersist
    protected void onCreate() {
        this.firstVisitedAt = LocalDateTime.now();
    }
}
