import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/services/base_api_service.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/user_profile.dart';
import '../domain/social_repository.dart';

/// Cliente HTTP para la API social (/api/user): perfil, amigos, búsqueda,
/// invitaciones a sala y subida de avatar a Cloudinary.
///
/// La subida de avatar usa un upload preset sin firma (_preset) configurado en
/// Cloudinary para no exponer el API secret en el cliente.
class FriendshipService extends BaseApiService implements SocialRepository {
  static const _cloudName = 'dy8tgy9h4';
  static const _preset    = 'profiles_preset';

  @override
  Future<UserProfile> getMe() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/me'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) return UserProfile.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.profile_load'.tr());
  }

  @override
  Future<UserProfile> getProfile(String username) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) return UserProfile.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.user_not_found'.tr());
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/search?q=${Uri.encodeQueryComponent(query.trim())}'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => UserProfile.fromJson(e))
          .toList();
    }
    return [];
  }

  @override
  Future<UserProfile> updatePrivacy({required bool hidden}) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.userUrl}/me'),
      headers: await authHeaders(),
      body: jsonEncode({'profileHidden': hidden.toString()}),
    );
    if (res.statusCode == 200) return UserProfile.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.privacy_update'.tr());
  }

  @override
  Future<UserProfile> updateMe({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, String>{};
    if (username    != null) body['username']    = username;
    if (displayName != null) body['displayName'] = displayName;
    if (bio         != null) body['bio']         = bio;
    if (avatarUrl   != null) body['avatarUrl']   = avatarUrl;

    final res = await http.put(
      Uri.parse('${ApiConstants.userUrl}/me'),
      headers: await authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return UserProfile.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.profile_update'.tr());
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String filename) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _preset
      ..fields['folder']        = 'perfiles'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename:    filename,
        contentType: MediaType('image', _mimeFromFilename(filename)),
      ));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(body)['secure_url'] as String;
    }
    throw Exception('errors.image_upload'.tr());
  }

  String _mimeFromFilename(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'jpeg';
      case 'png':  return 'png';
      case 'webp': return 'webp';
      case 'gif':  return 'gif';
      default:     return 'jpeg';
    }
  }

  @override
  Future<List<UserProfile>> getFriends() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/friends'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => UserProfile.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.friends_load'.tr());
  }

  @override
  Future<void> sendRequest(String username) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.userUrl}/friends/request/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.request_send'.tr());
  }

  @override
  Future<void> acceptRequest(String username) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.userUrl}/friends/accept/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.request_accept'.tr());
  }

  @override
  Future<void> removeFriend(String username) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.userUrl}/friends/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.friend_remove'.tr());
  }

  @override
  Future<List<UserProfile>> getPending() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/friends/pending'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => UserProfile.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.requests_load'.tr());
  }

  // ── Presencia ─────────────────────────────────────────────────────────────

  @override
  Future<List<FriendStatus>> getFriendsStatus() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/friends/status'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => FriendStatus.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.friend_status_load'.tr());
  }

  // ── Invitaciones ──────────────────────────────────────────────────────────

  @override
  Future<void> inviteFriend(String username, int roomId) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.userUrl}/invite/$username'),
      headers: await authHeaders(),
      body: jsonEncode({'roomId': roomId}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.invite_send'.tr());
  }

  @override
  Future<List<RoomInvitation>> getInvitations() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/me/invitations'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => RoomInvitation.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.invites_load'.tr());
  }

  @override
  Future<void> dismissInvitation(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.userUrl}/me/invitations/$id'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.invite_dismiss'.tr());
  }
}
