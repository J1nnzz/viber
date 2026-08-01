package com.example.viber.exception;

/**
 * Código estable de error, independiente del idioma.
 *
 * <p>El backend no sabe en qué idioma tiene la app el usuario: la app permite
 * elegirlo y puede no coincidir con el locale del dispositivo ni con la
 * cabecera {@code Accept-Language}. Por eso el servidor no traduce, sino que
 * identifica <em>qué</em> ha fallado y deja que el cliente decida cómo
 * contarlo.
 *
 * <p>La respuesta de error sigue llevando el campo {@code error} con el texto
 * en castellano, que actúa de reserva para clientes que no conozcan un código
 * concreto. El cliente traduce con la clave {@code errors.api.<CODE>} y, si no
 * la tiene, muestra ese texto tal cual.
 */
public enum ErrorCode {

    // ── Genéricos ────────────────────────────────────────────────────────────
    USER_NOT_FOUND,
    NO_PERMISSION,

    // ── Perfil y cuenta ──────────────────────────────────────────────────────
    USERNAME_EMPTY,
    USERNAME_LENGTH,
    USERNAME_TAKEN,
    NAME_TOO_LONG,
    BIO_TOO_LONG,

    // ── Amistad ──────────────────────────────────────────────────────────────
    CANNOT_REQUEST_SELF,
    RELATION_EXISTS,
    RELATION_NOT_FOUND,
    REQUEST_NOT_FOUND,

    // ── Grupos ───────────────────────────────────────────────────────────────
    GROUP_NOT_FOUND,
    NOT_GROUP_MEMBER,
    GROUP_NAME_EMPTY,
    GROUP_NAME_TOO_LONG,
    GROUP_DESC_TOO_LONG,
    GROUP_FULL,
    ALREADY_IN_GROUP,
    CANNOT_INVITE_SELF,
    ONLY_FRIENDS_CAN_BE_INVITED,
    INVITE_ALREADY_PENDING,
    INVITE_NOT_FOUND,
    INVITE_NOT_YOURS,
    INVITE_ALREADY_ANSWERED,
    CANNOT_KICK_OWNER,
    CANNOT_KICK_SAME_OR_HIGHER,
    USE_TRANSFER_OWNERSHIP,
    CANNOT_CHANGE_OWNER_ROLE,
    ALREADY_OWNER,
    TRANSFER_BEFORE_LEAVING,
    INVALID_ROLE,
    INVALID_PERMISSION,

    // ── Mensajes ─────────────────────────────────────────────────────────────
    MESSAGE_EMPTY,
    MESSAGE_TOO_LONG,

    // ── Salas ────────────────────────────────────────────────────────────────
    ROOM_NOT_FOUND,
    ROOM_FULL,
    INVALID_ACCESS_CODE,
    ALREADY_INVITED_TO_ROOM;
}
