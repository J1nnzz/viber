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
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Invitación que un usuario envía a un amigo para unirse a una sala.
 * El destinatario la ve en la campana de notificaciones.
 * Estado posible: PENDING (visible) → DISMISSED (descartada por el receptor).
 */
@Entity
@Table(name = "room_invitations")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoomInvitation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    @Column(nullable = false)
    private Long roomId;

    @Column(nullable = false, length = 100)
    private String roomName;

    // Código de acceso si la sala es privada, null si es pública
    @Column(length = 10)
    private String accessCode;

    // PENDING | DISMISSED
    @Column(nullable = false, length = 10)
    private String status = "PENDING";

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
