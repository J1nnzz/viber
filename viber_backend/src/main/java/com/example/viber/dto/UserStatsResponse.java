package com.example.viber.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Respuesta de /api/user/stats/* — espejo exacto de UserStats.fromJson (Dart).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserStatsResponse {
    private long roomsCreated;
    private long roomsJoined;
    private long totalListenSeconds;
    private List<GenreStat> topGenres;
    private List<GenreStat> topArtists;
    private int songsAdded;
    private int songsPlayed;
    private long likedSongsCount;
}
