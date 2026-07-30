package com.example.viber.exception;

/** Excepción lanzada cuando un recurso no se encuentra (HTTP 404). */
public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) {
        super(message);
    }
}
