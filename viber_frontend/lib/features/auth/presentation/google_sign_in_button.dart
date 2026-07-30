// Exportación condicional: en web usa la implementación GIS, en móvil la nativa
export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';