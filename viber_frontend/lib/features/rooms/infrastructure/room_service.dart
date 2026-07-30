import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/services/base_api_service.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';
import 'package:viber/core/constants/api_constants.dart';

/// Cliente HTTP para la API REST de salas (/api/rooms).
///
/// Cubre CRUD de salas, unión por código de acceso, comprobación de expulsión
/// (decodificando el JWT localmente para obtener el username), reporte de sala
/// y carga del catálogo de géneros.
class RoomService extends BaseApiService implements RoomRepository {

  // Cloudinary (mismo preset sin firma que avatares y fotos de grupo)
  static const _cloudName = 'dy8tgy9h4';
  static const _preset    = 'profiles_preset';

  // ── Listar salas públicas ─────────────────────────────────────────────────
  Future<List<Room>> getPublicRooms() async {
    final res = await http.get(Uri.parse(ApiConstants.roomsUrl),
        headers: await authHeaders());
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Room.fromJson(j))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar salas');
  }

  // ── Salas recomendadas por el gusto del usuario ───────────────────────────
  Future<List<Room>> getRecommendedRooms() async {
    final res = await http.get(Uri.parse('${ApiConstants.roomsUrl}/recommended'),
        headers: await authHeaders());
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Room.fromJson(j))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar recomendaciones');
  }

  // ── Salas propias del usuario (públicas + privadas) ───────────────────────
  Future<List<Room>> getMyRooms() async {
    final res = await http.get(Uri.parse('${ApiConstants.roomsUrl}/my'),
        headers: await authHeaders());
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Room.fromJson(j))
          .toList();
    }
    throwFromResponse(res, 'Error al cargar tus salas');
  }

  // ── Crear sala ────────────────────────────────────────────────────────────
  Future<Room> createRoom({
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
    bool autoDj = false,
    String? coverImageUrl,
    String? accentColor,
    String? welcomeMessage,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConstants.roomsUrl),
      headers: await authHeaders(),
      body: jsonEncode({
        'name':            name,
        'description':     description,
        'genres':          genres ?? [],
        'privacy':         privacy,
        'accessCode':      accessCode,
        'maxParticipants': maxParticipants,
        'autoDj':          autoDj,
        'coverImageUrl':   coverImageUrl,
        'accentColor':     accentColor,
        'welcomeMessage':  welcomeMessage,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Room.fromJson(data);
    throw Exception(data['error'] ?? 'Error al crear la sala');
  }

  // ── Unirse por código ─────────────────────────────────────────────────────
  Future<Room> joinByCode(String code) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.roomsUrl}/join'),
      headers: await authHeaders(),
      body: jsonEncode({'accessCode': code}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Room.fromJson(data);
    throw Exception(data['error'] ?? 'Código inválido');
  }

  // ── Editar sala ───────────────────────────────────────────────────────────
  Future<Room> updateRoom({
    required int roomId,
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
    bool? autoDj,
    String? coverImageUrl,
    String? accentColor,
    String? welcomeMessage,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.roomsUrl}/$roomId'),
      headers: await authHeaders(),
      body: jsonEncode({
        'name':            name,
        'description':     description,
        'genres':          genres ?? [],
        'privacy':         privacy,
        'accessCode':      accessCode,
        'maxParticipants': maxParticipants,
        'autoDj':          autoDj,
        'coverImageUrl':   coverImageUrl,
        'accentColor':     accentColor,
        'welcomeMessage':  welcomeMessage,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Room.fromJson(data);
    throw Exception(data['error'] ?? 'Error al editar la sala');
  }

  // ── Cerrar sala ───────────────────────────────────────────────────────────
  Future<void> closeRoom(int roomId) async {
    await http.delete(Uri.parse('${ApiConstants.roomsUrl}/$roomId'),
        headers: await authHeaders());
  }

  // ── Comprobar si el usuario fue expulsado ─────────────────────────────────
  Future<bool> isKickedFromRoom(int roomId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.roomsUrl}/$roomId/state'),
        headers: await authHeaders(),
      );
      if (res.statusCode != 200) return false;

      final data        = jsonDecode(res.body) as Map<String, dynamic>;
      final kickedUsers = List<String>.from(data['kickedUsers'] ?? []);
      final token       = await getToken();
      if (token == null) return false;

      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = jsonDecode(
        String.fromCharCodes(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final username = payload['sub'] as String?;
      return username != null && kickedUsers.contains(username);
    } catch (_) {
      return false;
    }
  }

  // ── Reportar sala ─────────────────────────────────────────────────────────
  Future<void> reportRoom({required int roomId, required String reason}) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.roomsUrl}/$roomId/report'),
      headers: await authHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'Error al enviar el reporte');
  }

  // ── Catálogo de géneros ───────────────────────────────────────────────────
  Future<List<String>> fetchGenres() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/genres'));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List)
            .map((g) => g['name'] as String)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Portada de sala (Cloudinary) ──────────────────────────────────────────
  Future<String> uploadRoomCover(Uint8List imageBytes, String filename) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _preset
      ..fields['folder']        = 'salas'
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
    throw Exception('Error al subir la portada de la sala');
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
