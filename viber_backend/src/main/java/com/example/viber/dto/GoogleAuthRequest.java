package com.example.viber.dto;

import lombok.Data;

@Data
public class GoogleAuthRequest {
    // ID Token que Flutter obtiene del SDK de Google Sign-In
    // El backend lo verificará contra la API de Google
    private String idToken;
}