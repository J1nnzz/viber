/// Perfil completo de un usuario tal como lo devuelve /api/user/{username}.
/// El campo [relation] indica la relación del usuario autenticado con este perfil:
/// SELF, NONE, FRIENDS, PENDING_SENT o PENDING_RECEIVED.
class UserProfile {
  final int     id;
  final String  username;
  final String  email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? createdAt;
  final int     friendCount;
  final String  relation;
  final String  authProvider;
  final bool    profileHidden;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.createdAt,
    this.friendCount   = 0,
    this.relation      = 'NONE',
    this.authProvider  = 'LOCAL',
    this.profileHidden = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id:            j['id'] as int,
        username:      j['username'] as String,
        email:         j['email'] as String,
        displayName:   j['displayName']   as String?,
        avatarUrl:     j['avatarUrl']     as String?,
        bio:           j['bio']           as String?,
        createdAt:     j['createdAt']     as String?,
        friendCount:   (j['friendCount']  as num?)?.toInt() ?? 0,
        relation:      j['relation']      as String? ?? 'NONE',
        authProvider:  j['authProvider']  as String? ?? 'LOCAL',
        profileHidden: j['profileHidden'] as bool?  ?? false,
      );

  String get displayLabel =>
      displayName?.isNotEmpty == true ? displayName! : username;
}

class FriendStatus {
  final String  username;
  final String? displayName;
  final String? avatarUrl;
  final String  status;
  final int?    roomId;
  final String? roomName;

  const FriendStatus({
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.roomId,
    this.roomName,
  });

  factory FriendStatus.fromJson(Map<String, dynamic> j) => FriendStatus(
        username:    j['username']    as String,
        displayName: j['displayName'] as String?,
        avatarUrl:   j['avatarUrl']   as String?,
        status:      j['status']      as String? ?? 'OFFLINE',
        roomId:      (j['roomId']     as num?)?.toInt(),
        roomName:    j['roomName']    as String?,
      );

  bool get isInRoom => status == 'IN_ROOM';

  String get displayLabel =>
      displayName?.isNotEmpty == true ? displayName! : username;
}

class RoomInvitation {
  final int     id;
  final int     roomId;
  final String  roomName;
  final String? accessCode;
  final String  senderName;
  final String? senderAvatar;
  final String  createdAt;

  const RoomInvitation({
    required this.id,
    required this.roomId,
    required this.roomName,
    this.accessCode,
    required this.senderName,
    this.senderAvatar,
    required this.createdAt,
  });

  factory RoomInvitation.fromJson(Map<String, dynamic> j) => RoomInvitation(
        id:           (j['id']     as num).toInt(),
        roomId:       (j['roomId'] as num).toInt(),
        roomName:     j['roomName']     as String,
        accessCode:   j['accessCode']   as String?,
        senderName:   j['senderName']   as String,
        senderAvatar: j['senderAvatar'] as String?,
        createdAt:    j['createdAt']    as String,
      );
}
