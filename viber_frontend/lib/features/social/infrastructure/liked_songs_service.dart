import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/base_api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/liked_song.dart';

class LikedSongsService extends BaseApiService {
  Future<List<LikedSong>> getLikedSongs() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/liked-songs'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => LikedSong.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar favoritos');
  }

  Future<LikedSong> likeSong({
    required String videoId,
    required String title,
    String? thumbnailUrl,
    String? channelTitle,
  }) async {
    final body = <String, String>{'videoId': videoId, 'title': title};
    if (thumbnailUrl != null) body['thumbnailUrl'] = thumbnailUrl;
    if (channelTitle != null) body['channelTitle'] = channelTitle;

    final res = await http.post(
      Uri.parse('${ApiConstants.userUrl}/liked-songs'),
      headers: await authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return LikedSong.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.like_add'.tr());
  }

  Future<void> unlikeSong(String videoId) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.userUrl}/liked-songs/$videoId'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al eliminar de favoritos');
  }

  Future<bool> isLiked(String videoId) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/liked-songs/$videoId/status'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['liked'] as bool? ?? false;
    }
    return false;
  }
}
