/// Exportación condicional:
///   • En web  → notification_service_web.dart  (Audio API + document.title)
///   • En nativo → notification_service_stub.dart (no-op)
export 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_stub.dart';
