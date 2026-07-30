# Notificaciones push (FCM) — Pasos de configuración

El código de notificaciones push ya está implementado en frontend y backend.
Para **activarlas** solo falta conectar la app Android al proyecto Firebase que
**ya usa el backend** (el mismo de Firestore). No hace falta crear un proyecto nuevo.

## 1. Añadir la app Android al proyecto Firebase existente

1. Abre la [consola de Firebase](https://console.firebase.google.com/) y entra en
   el proyecto que ya usa este backend (el de `serviceAccountKey.json`).
2. **Project settings → Your apps → Add app → Android**.
3. **Android package name**: `com.example.viber` (debe coincidir con el
   `applicationId` de `viber_frontend/android/app/build.gradle.kts`).
4. Descarga el **`google-services.json`** que genera.
5. Cópialo en:

   ```
   viber_frontend/android/app/google-services.json
   ```

   En cuanto el archivo exista, el plugin de Gradle se aplica solo (es
   condicional) y FCM queda activo. Sin el archivo, la app compila igual pero
   sin push.

## 2. Comprobar que Cloud Messaging está habilitado

En la consola de Firebase: **Project settings → Cloud Messaging**. La
**Firebase Cloud Messaging API (V1)** debe estar *Enabled* (lo está por defecto
en proyectos nuevos). El backend usa esta API con las credenciales que ya tiene.

## 3. (Opcional) iOS

Si vas a compilar para iPhone:
1. Añade también una app **iOS** en Firebase con el mismo bundle id.
2. Descarga `GoogleService-Info.plist` y añádelo al proyecto con Xcode
   (`Runner/`).
3. Sube una **APNs Authentication Key** en Firebase → Cloud Messaging.

## 4. Probar

1. `cd viber_frontend && flutter pub get`
2. Compila e instala en un móvil real (el emulador necesita Google Play):
   `flutter run` (en Android físico) o `flutter build apk`.
3. Inicia sesión: la app pedirá permiso de notificaciones y registrará el token.
4. Desde **otra cuenta**, envíale una solicitud de amistad o invitación a sala.
5. Con la app en segundo plano verás la notificación en la bandeja del sistema;
   en primer plano aparece como aviso dentro de la app.

## Qué se notifica

El backend envía push en estos eventos (`PushNotificationService`):
- **Solicitud de amistad** (`UserController.sendRequest`)
- **Invitación a sala** (`UserController.inviteFriend`)
- **Invitación a grupo** (`GroupService.invite`)

Cada notificación incluye un campo `data.type` (`friend_request`, `room_invite`,
`group_invite`) por si más adelante quieres enrutar a una pantalla concreta al
tocarla.

## Resumen de archivos tocados

**Frontend**
- `pubspec.yaml` — `firebase_core`, `firebase_messaging`
- `android/settings.gradle.kts` — plugin Google Services (classpath)
- `android/app/build.gradle.kts` — aplica el plugin si existe `google-services.json`; `minSdk` ≥ 23
- `android/app/src/main/AndroidManifest.xml` — permiso `POST_NOTIFICATIONS`
- `lib/core/services/push_notification_service.dart` — servicio FCM (solo móvil)
- `lib/main.dart` — init FCM, registro al iniciar sesión, baja al cerrar sesión

**Backend** (Firebase ya estaba configurado para Firestore)
- `model/DeviceToken.java`, `repository/DeviceTokenRepository.java`
- `dto/RegisterDeviceRequest.java`
- `service/PushNotificationService.java`
- `controller/PushController.java` — `POST /api/push/register` y `/unregister`
- `UserController.java` y `GroupService.java` — envían el push en cada evento
