package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
 * Grupo de chat con varios miembros (a diferencia de los DM 1-a-1).
 *
 * Los datos relacionales (nombre, foto, descripción, propietario y políticas de
 * permiso) viven aquí en SQL, igual que {@link Room}; los mensajes en sí se
 * persisten en Firestore ({@code group_messages/{groupId}/messages}).
 *
 * La membresía y los roles se modelan en {@link GroupMember}. Cada política de
 * permiso ({@link GroupPermission}) define el rol mínimo necesario para una acción.
 */
@Entity
@Table(name = "chat_groups")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChatGroup {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 80)
    private String name;

    @Column(length = 255)
    private String description;

    // URL de la foto del grupo (Cloudinary). El cliente sube y manda la URL.
    @Column(name = "photo_url", length = 500)
    private String photoUrl;

    // Creador del grupo — siempre tiene rol OWNER en group_members
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    // ── Políticas de permiso (rol mínimo por acción) ───────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "invite_policy", nullable = false, length = 15)
    private GroupPermission invitePolicy = GroupPermission.ALL_MEMBERS;

    @Enumerated(EnumType.STRING)
    @Column(name = "edit_info_policy", nullable = false, length = 15)
    private GroupPermission editInfoPolicy = GroupPermission.ADMINS_ONLY;

    @Enumerated(EnumType.STRING)
    @Column(name = "send_message_policy", nullable = false, length = 15)
    private GroupPermission sendMessagePolicy = GroupPermission.ALL_MEMBERS;

    @Enumerated(EnumType.STRING)
    @Column(name = "start_quiz_policy", nullable = false, length = 15)
    private GroupPermission startQuizPolicy = GroupPermission.ALL_MEMBERS;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
