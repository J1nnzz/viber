package com.example.viber.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Par (nombre, contador) usado tanto para géneros como para artistas
 * en las estadísticas del perfil — espejo de GenreStat (Dart).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class GenreStat {
    private String name;
    private int count;
}
