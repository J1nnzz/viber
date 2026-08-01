package com.example.viber.exception;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Manejador global de excepciones: convierte las excepciones de dominio en
 * respuestas HTTP con el código de estado apropiado.
 *
 * <p>El cuerpo es {@code {"error": "...", "code": "..."}}. El campo
 * {@code error} lleva el texto en castellano y se mantiene siempre, de modo que
 * un cliente que no reconozca el código pueda mostrarlo tal cual. El campo
 * {@code code} solo aparece si la excepción trae uno (ver {@link ErrorCode}) y
 * es lo que permite al cliente traducir el mensaje a su propio idioma: el
 * servidor no sabe qué idioma tiene elegido el usuario en la app.
 *
 * <p>RuntimeException genérica devuelve 400; las excepciones específicas su
 * propio código de estado.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<?> handleNotFound(NotFoundException e) {
        return build(404, e.getMessage(), e.getCode());
    }

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<?> handleForbidden(ForbiddenException e) {
        return build(403, e.getMessage(), e.getCode());
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<?> handleConflict(ConflictException e) {
        return build(409, e.getMessage(), e.getCode());
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<?> handleRuntime(RuntimeException e) {
        return build(400, e.getMessage(), null);
    }

    /**
     * LinkedHashMap y no Map.of: hace falta orden estable en la respuesta y
     * Map.of no admite valores nulos.
     */
    private ResponseEntity<?> build(int status, String message, ErrorCode code) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", message);
        if (code != null) {
            body.put("code", code.name());
        }
        return ResponseEntity.status(status).body(body);
    }
}
