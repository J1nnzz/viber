# Viber — Spring Boot backend

REST API, WebSocket broker and domain services for [Viber](../README.md).
See the root README for the overall architecture.

## Run

```bash
./mvnw spring-boot:run
```

Requires MySQL 8 with a `viber_db` schema in `utf8mb4`, and an
`application-local.properties` with your keys — copy the template first:

```bash
cp src/main/resources/application-local.properties.example \
   src/main/resources/application-local.properties
```

Interactive API docs: `http://localhost:8080/swagger-ui/index.html`.

## Configuration

`application.properties` is committed and contains **no secrets** — every
sensitive value is an environment-variable placeholder. Real values come from
either:

- `application-local.properties` (gitignored) for local development, or
- environment variables in production, with `SPRING_PROFILES_ACTIVE=prod`.

Firebase credentials are resolved from the `firebase.credentials` property, which
accepts `classpath:` and `file:` locations. Default is
`classpath:serviceAccountKey.json`, which is gitignored.

## Layout

```
src/main/java/com/example/viber/
  config/       security, WebSocket broker, Firebase, OpenAPI
  controller/   REST endpoints and STOMP message mappings
  service/      domain logic — rooms, quiz, taste profiles, auto-DJ, push
  repository/   Spring Data JPA repositories
  model/        JPA entities and enums
  dto/          request and response payloads
  exception/    handlers and domain exceptions
  utils/        helpers
```

Notable services:

| Service | Role |
|---|---|
| `RoomStateService` | Server-authoritative playback position per room |
| `RoomRecommendationService` | Ranks rooms by cosine similarity to a taste vector |
| `TasteProfileService` | Builds taste vectors with exponential time decay |
| `AutoDjService` | Keeps permanent rooms playing when the queue runs dry |
| `SimilarArtistService` | Artist graph from Deezer, enriched with Last.fm |
| `QuizMatchService` / `QuizGameService` | Live competitive matches and daily mode |
| `Firestore*Service` | Chat, direct messages, group messages, playback queues |

## Checks

```bash
./mvnw test
```
