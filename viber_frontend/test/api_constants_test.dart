import 'package:flutter_test/flutter_test.dart';
import 'package:viber/core/constants/api_constants.dart';

void main() {
  group('ApiConstants', () {
    // `flutter test` corre sin --dart-define, así que VIBER_API_HOST está vacío
    // y debe aplicarse el valor por defecto de móvil: 10.0.2.2, el alias del
    // emulador de Android para el localhost del PC anfitrión.
    test('sin VIBER_API_HOST usa el host por defecto del emulador', () {
      expect(ApiConstants.baseUrl, 'http://10.0.2.2:8080/api');
      expect(ApiConstants.wsUrl, 'http://10.0.2.2:8080/ws');
    });

    test('el WebSocket comparte host con la API pero no cuelga de /api', () {
      expect(ApiConstants.wsUrl, isNot(startsWith(ApiConstants.baseUrl)));
      expect(ApiConstants.wsUrl, endsWith('/ws'));
    });

    test('todos los endpoints cuelgan de baseUrl', () {
      final endpoints = <String, String>{
        'auth': ApiConstants.authUrl,
        'rooms': ApiConstants.roomsUrl,
        'user': ApiConstants.userUrl,
        'youtube': ApiConstants.youtubeUrl,
        'chat': ApiConstants.chatUrl,
        'quiz': ApiConstants.quizUrl,
        'groups': ApiConstants.groupsUrl,
        'push': ApiConstants.pushUrl,
      };

      endpoints.forEach((name, url) {
        expect(url, '${ApiConstants.baseUrl}/$name',
            reason: 'el endpoint $name debe derivarse de baseUrl');
      });
    });

    test('ninguna URL termina en barra', () {
      // Una barra de más produce rutas con // al concatenar y algunos
      // servidores las tratan como recursos distintos.
      expect(ApiConstants.baseUrl, isNot(endsWith('/')));
      expect(ApiConstants.wsUrl, isNot(endsWith('/')));
    });
  });
}
