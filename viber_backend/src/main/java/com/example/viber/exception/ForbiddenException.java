package com.example.viber.exception;

/** Excepción lanzada cuando el usuario no tiene permiso (HTTP 403). */
public class ForbiddenException extends RuntimeException {

    /** Código estable para que el cliente traduzca; puede ser null. */
    private final ErrorCode code;

    public ForbiddenException(String message) {
        this(null, message);
    }

    public ForbiddenException(ErrorCode code, String message) {
        super(message);
        this.code = code;
    }

    public ErrorCode getCode() {
        return code;
    }
}
