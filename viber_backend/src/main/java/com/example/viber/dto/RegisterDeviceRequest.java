package com.example.viber.dto;

import lombok.Data;

/** DTO para registrar/eliminar un token de dispositivo FCM. */
@Data
public class RegisterDeviceRequest {
    private String token;
    private String platform; // "android", "ios" o "web"
}
