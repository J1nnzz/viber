package com.example.viber;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableAsync // Habilita @Async para FirestoreChatService, FirestoreQueueService y TrackMetadataService
@EnableScheduling // Habilita @Scheduled para el auto-DJ de salas permanentes (AutoDjService)
public class ViberApplication {

	public static void main(String[] args) {
		SpringApplication.run(ViberApplication.class, args);
	}
}