import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import '../../../core/services/base_api_service.dart';

/// Cliente HTTP para crear partidas de quiz en vivo. El juego en sí va por STOMP
/// (ver QuizMatchSocket); este servicio solo arranca la partida e invita.
class QuizMatchService extends BaseApiService {

  /// Crea una partida y devuelve su id. [scope] = "DM" o "GROUP".
  Future<int> createMatch({
    required String mode,
    required String scope,
    String? otherUsername,
    int?    groupId,
    int     totalRounds = 5,
    int     secondsPerRound = 15,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.quizUrl}/match'),
      headers: await authHeaders(),
      body: jsonEncode({
        'mode': mode,
        'scope': scope,
        if (otherUsername != null) 'otherUsername': otherUsername,
        if (groupId != null) 'groupId': groupId,
        'totalRounds': totalRounds,
        'secondsPerRound': secondsPerRound,
      }),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['matchId'] as num).toInt();
    }
    throwFromResponse(res, 'errors.match_create'.tr());
  }
}
