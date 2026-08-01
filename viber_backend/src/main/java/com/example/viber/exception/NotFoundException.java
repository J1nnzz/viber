package com.example.viber.exception;

/** Excepción lanzada cuando un recurso no se encuentra (HTTP 404). */
public class NotFoundException extends RuntimeException {

    /** Código estable para que el cliente traduzca; puede ser null. */
    private final ErrorCode code;

    public NotFoundException(String message) {
        this(null, message);
    }

    public NotFoundException(ErrorCode code, String message) {
        super(message);
        this.code = code;
    }

    public ErrorCode getCode() {
        return code;
    }
}
