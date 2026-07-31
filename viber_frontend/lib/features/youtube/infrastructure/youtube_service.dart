import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/base_api_service.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/youtube_result.dart';
import '../domain/youtube_repository.dart';

/// Cliente HTTP para la API de YouTube del backend (/api/youtube).
/// Delega la lógica al backend para no exponer la API key de YouTube en el cliente.
class YoutubeService extends BaseApiService implements YoutubeRepository {

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  @override
  Future<List<YoutubeSearchResult>> search(String query) async {
    final uri = Uri.parse('${ApiConstants.youtubeUrl}/search')
        .replace(queryParameters: {'q': query});
    final res = await http.get(uri, headers: await authHeaders());

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => YoutubeSearchResult.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'Error en la búsqueda');
  }

  // ── Importar playlist ─────────────────────────────────────────────────────

  @override
  Future<List<YoutubeSearchResult>> fetchPlaylist(
      String urlOrId, {int max = 50}) async {
    final uri = Uri.parse('${ApiConstants.youtubeUrl}/playlist').replace(
      queryParameters: {'url': urlOrId, 'max': max.toString()},
    );
    final res = await http.get(uri, headers: await authHeaders());

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => YoutubeSearchResult.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.playlist_import'.tr());
  }
}
