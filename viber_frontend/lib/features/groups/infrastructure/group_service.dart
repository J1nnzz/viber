import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../../../core/services/base_api_service.dart';
import '../domain/group_models.dart';

/// Cliente HTTP para la API de grupos (/api/groups): CRUD, mensajería,
/// invitaciones y administración. La foto del grupo se sube a Cloudinary con el
/// mismo preset sin firma que los avatares.
class GroupService extends BaseApiService {
  static const _cloudName = 'dy8tgy9h4';
  static const _preset    = 'profiles_preset';

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<List<GroupModel>> getMyGroups() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.groupsUrl}/my'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar grupos');
  }

  Future<GroupModel> getGroup(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.groupsUrl}/$id'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return GroupModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.group_load'.tr());
  }

  Future<GroupModel> createGroup({
    required String name,
    String? description,
    String? photoUrl,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConstants.groupsUrl),
      headers: await authHeaders(),
      body: jsonEncode({
        'name': name,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photoUrl': photoUrl,
      }),
    );
    if (res.statusCode == 200) {
      return GroupModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.group_create'.tr());
  }

  Future<GroupModel> updateGroup(int id, {
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.groupsUrl}/$id'),
      headers: await authHeaders(),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photoUrl': photoUrl,
      }),
    );
    if (res.statusCode == 200) {
      return GroupModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.group_update'.tr());
  }

  Future<GroupModel> updatePermissions(int id, {
    GroupPermission? invitePolicy,
    GroupPermission? editInfoPolicy,
    GroupPermission? sendMessagePolicy,
    GroupPermission? startQuizPolicy,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.groupsUrl}/$id/permissions'),
      headers: await authHeaders(),
      body: jsonEncode({
        if (invitePolicy != null)      'invitePolicy':      groupPermissionToString(invitePolicy),
        if (editInfoPolicy != null)    'editInfoPolicy':    groupPermissionToString(editInfoPolicy),
        if (sendMessagePolicy != null) 'sendMessagePolicy': groupPermissionToString(sendMessagePolicy),
        if (startQuizPolicy != null)   'startQuizPolicy':   groupPermissionToString(startQuizPolicy),
      }),
    );
    if (res.statusCode == 200) {
      return GroupModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.perms_update'.tr());
  }

  Future<void> deleteGroup(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.groupsUrl}/$id'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.group_delete'.tr());
  }

  // ── Mensajería ──────────────────────────────────────────────────────────────

  Future<List<GroupMessage>> getMessages(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.groupsUrl}/$id/messages'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => GroupMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar mensajes');
  }

  Future<void> sendMessage(int id, String text) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/$id/messages'),
      headers: await authHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al enviar mensaje');
  }

  // ── Invitaciones ────────────────────────────────────────────────────────────

  Future<void> invite(int id, String username) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/$id/invite/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al invitar');
  }

  Future<List<GroupInvitationModel>> getInvitations() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.groupsUrl}/invitations'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => GroupInvitationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar invitaciones de grupo');
  }

  Future<void> acceptInvitation(int invId) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/invitations/$invId/accept'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al aceptar la invitación');
  }

  Future<void> rejectInvitation(int invId) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/invitations/$invId/reject'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al rechazar la invitación');
  }

  // ── Administración ──────────────────────────────────────────────────────────

  Future<void> kick(int id, String username) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.groupsUrl}/$id/members/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al expulsar');
  }

  Future<void> changeRole(int id, String username, GroupRole role) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.groupsUrl}/$id/members/$username/role'),
      headers: await authHeaders(),
      body: jsonEncode({'role': role.name.toUpperCase()}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.role_change'.tr());
  }

  Future<void> transferOwnership(int id, String username) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/$id/transfer/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al transferir la propiedad');
  }

  Future<void> leave(int id) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.groupsUrl}/$id/leave'),
      headers: await authHeaders(),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.group_leave'.tr());
  }

  // ── Foto de grupo (Cloudinary) ──────────────────────────────────────────────

  Future<String> uploadGroupPhoto(Uint8List imageBytes, String filename) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _preset
      ..fields['folder']        = 'grupos'
      ..files.add(http.MultipartFile.fromBytes(
        'file', imageBytes,
        filename:    filename,
        contentType: MediaType('image', _mimeFromFilename(filename)),
      ));
    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      return jsonDecode(body)['secure_url'] as String;
    }
    throw Exception('Error al subir la imagen del grupo');
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
}
