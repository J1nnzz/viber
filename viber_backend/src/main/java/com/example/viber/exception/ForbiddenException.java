package com.example.viber.exception;

/** Excepción lanzada cuando el usuario no tiene permiso para la operación (HTTP 403). */
public class ForbiddenException extends RuntimeException {
    public ForbiddenException(String message) {
        super(message);
    }
}
