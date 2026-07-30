package com.example.viber.exception;

/** Excepción lanzada cuando existe un conflicto de datos (HTTP 409). */
public class ConflictException extends RuntimeException {
    public ConflictException(String message) {
        super(message);
    }
}
