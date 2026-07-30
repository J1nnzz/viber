import 'dart:typed_data';
import 'user_profile.dart';

/// Contrato de la capa de datos social.
/// Cubre: perfil propio/ajeno, búsqueda de usuarios, edición de perfil,
/// subida de avatar a Cloudinary, gestión de amigos (enviar/aceptar/eliminar solicitudes),
/// presencia de amigos en tiempo real, e invitaciones a sala.
abstract class SocialRepository {
  Future<UserProfile> getMe();
  Future<UserProfile> getProfile(String username);
  Future<List<UserProfile>> searchUsers(String query);
  Future<UserProfile> updateMe({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
  });
  Future<UserProfile> updatePrivacy({required bool hidden});
  Future<String> uploadAvatar(Uint8List imageBytes, String filename);
  Future<List<UserProfile>> getFriends();
  Future<List<UserProfile>> getPending();
  Future<void> sendRequest(String username);
  Future<void> acceptRequest(String username);
  Future<void> removeFriend(String username);
  Future<List<FriendStatus>> getFriendsStatus();
  Future<void> inviteFriend(String username, int roomId);
  Future<List<RoomInvitation>> getInvitations();
  Future<void> dismissInvitation(int id);
}
