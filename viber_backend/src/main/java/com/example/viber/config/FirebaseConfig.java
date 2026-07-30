package com.example.viber.config;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.firestore.Firestore;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.cloud.FirestoreClient;

/**
 * Inicializa el SDK de Firebase Admin y expone el cliente Firestore como bean de Spring.
 * Las credenciales se cargan de la ruta que indique {@code firebase.credentials}
 * ({@code classpath:} para un archivo en resources, {@code file:} para una ruta del
 * servidor). El JSON de la service account no está en git: ver
 * {@code FIREBASE_PUSH_SETUP.md}.
 * El bean se recrea limpiando instancias previas para que el hot-reload de Spring
 * no deje un cliente Firestore cerrado en memoria.
 */
@Configuration
public class FirebaseConfig {

    private final ResourceLoader resourceLoader;

    @Value("${firebase.credentials}")
    private String credentialsLocation;

    public FirebaseConfig(ResourceLoader resourceLoader) {
        this.resourceLoader = resourceLoader;
    }

    @Bean
    public Firestore firestore() throws IOException {
        // En hot-reload el FirebaseApp sobrevive al contexto de Spring pero
        // su cliente Firestore queda cerrado. Borramos las instancias previas
        // para obtener siempre un cliente fresco.
        for (FirebaseApp app : FirebaseApp.getApps()) {
            app.delete();
        }

        Resource credentials = resourceLoader.getResource(credentialsLocation);
        if (!credentials.exists()) {
            // Sin credenciales el chat, las colas y las push no pueden funcionar,
            // así que fallamos con un mensaje que diga qué falta en lugar de dejar
            // que reviente más abajo con un stack trace opaco.
            throw new FileNotFoundException(
                "No se encontraron las credenciales de Firebase en '" + credentialsLocation
                + "'. Descarga el JSON de la service account desde Firebase Console "
                + "(Configuración del proyecto → Cuentas de servicio) y guárdalo en "
                + "src/main/resources/serviceAccountKey.json, o apunta a otra ruta con "
                + "la propiedad firebase.credentials / la variable FIREBASE_CREDENTIALS. "
                + "Detalles en FIREBASE_PUSH_SETUP.md.");
        }

        try (InputStream serviceAccount = credentials.getInputStream()) {
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                .build();

            FirebaseApp.initializeApp(options);
        }
        return FirestoreClient.getFirestore();
    }
}