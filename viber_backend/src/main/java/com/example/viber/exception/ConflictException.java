package com.example.viber.exception;

/** Excepción lanzada ante un conflicto de estado (HTTP 409). */
public class ConflictException extends RuntimeException {

    /** Código estable para que el cliente traduzca; puede ser null. */
    private final ErrorCode code;

    public ConflictException(String message) {
        this(null, message);
    }

    public ConflictException(ErrorCode code, String message) {
        super(message);
        this.code = code;
    }

    public ErrorCode getCode() {
        return code;
    }
}
