# Viber — Flutter client

Cross-platform client for [Viber](../README.md): Android, iOS and web from one
codebase. See the root README for what the project is and how the pieces fit.

## Run

```bash
flutter pub get
flutter run             # connected device or emulator
flutter run -d chrome   # web
```

Backend hosts are set in `lib/core/constants/api_constants.dart`: the web build
points at `http://localhost:8080`, while mobile builds point at a LAN address,
since an emulator or a phone cannot reach the host's `localhost`. **Change
`_mobileHost` to your own machine's IP on the network** before running on a
device.

For Android builds you need your own `google-services.json` in `android/app/`
(Firebase Cloud Messaging). There is a `.example` next to it describing what to
download. The web build does not need it.

## Layout

```
lib/
  core/         theme, shared widgets, services, constants, error handling
  features/     one folder per feature, each with presentation + infrastructure
    auth/           JWT + Google Sign-In
    rooms/          room list, synced player, queue, presence
    chat/           room chat, direct messages, global chat
    groups/         group chats with roles and permissions
    quiz/           live matches and daily solo mode
    social/         profiles, friends, stats, liked songs
    youtube/        search and playback integration
    notifications/  FCM handling and in-app notifications
    admin/          quiz catalogue and moderation
assets/
  brand/        logo
  fonts/        Fredoka (display) + Nunito (body), bundled
  translations/ es / en
```

State is managed with `provider`; navigation is handled manually through
`AppRouter`. Theming lives in `lib/core/theme/app_theme.dart` — dark-first, with
the accent colour adapting per brightness.

## Checks

```bash
flutter analyze
flutter test
```
