package com.example.viber.model;

/**
 * Política de permiso de una acción del grupo, expresada como el rol mínimo
 * que puede ejecutarla. Cada grupo guarda una de estas por acción configurable
 * (invitar, editar info, enviar mensajes, lanzar quiz).
 *
 * ALL_MEMBERS — cualquier miembro puede.
 * ADMINS_ONLY — solo ADMIN y OWNER.
 */
public enum GroupPermission {
    ALL_MEMBERS,
    ADMINS_ONLY;

    /** Rol mínimo que satisface esta política. */
    public GroupRole minRole() {
        return this == ADMINS_ONLY ? GroupRole.ADMIN : GroupRole.MEMBER;
    }

    /** true si un miembro con {@code role} cumple esta política. */
    public boolean allows(GroupRole role) {
        return role.isAtLeast(minRole());
    }
}
