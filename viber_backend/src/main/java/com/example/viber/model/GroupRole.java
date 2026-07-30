package com.example.viber.model;

/**
 * Rol de un usuario dentro de un grupo de chat.
 *
 * OWNER  — creador del grupo. Control total; no se le puede expulsar ni degradar.
 *          Solo puede dejar de serlo transfiriendo la propiedad a otro miembro.
 * ADMIN  — moderador. Puede invitar, expulsar miembros y editar el grupo según
 *          las políticas de permisos del propio grupo.
 * MEMBER — miembro normal.
 *
 * El {@link #rank()} permite comparar jerarquías (mayor número = más poder) sin
 * repartir condicionales por todo el código.
 */
public enum GroupRole {
    OWNER,
    ADMIN,
    MEMBER;

    /** Peso jerárquico del rol: a mayor valor, más privilegios. */
    public int rank() {
        return switch (this) {
            case OWNER  -> 2;
            case ADMIN  -> 1;
            case MEMBER -> 0;
        };
    }

    /** true si este rol tiene al menos tanto poder como {@code other}. */
    public boolean isAtLeast(GroupRole other) {
        return this.rank() >= other.rank();
    }
}
