// Modelos del dominio de grupos de chat.
//
// Reflejan los DTO del backend (GroupResponse, GroupMemberResponse,
// GroupInvitationResponse) y los payloads STOMP de mensajes de grupo.

/// Política de permiso de una acción del grupo (rol mínimo que la permite).
enum GroupPermission { allMembers, adminsOnly }

GroupPermission groupPermissionFromString(String? s) =>
    s == 'ADMINS_ONLY' ? GroupPermission.adminsOnly : GroupPermission.allMembers;

String groupPermissionToString(GroupPermission p) =>
    p == GroupPermission.adminsOnly ? 'ADMINS_ONLY' : 'ALL_MEMBERS';

/// Rol de un miembro dentro del grupo.
enum GroupRole { owner, admin, member }

GroupRole groupRoleFromString(String? s) => switch (s) {
      'OWNER' => GroupRole.owner,
      'ADMIN' => GroupRole.admin,
      _       => GroupRole.member,
    };

extension GroupRoleX on GroupRole {
  int get rank => switch (this) {
        GroupRole.owner  => 2,
        GroupRole.admin  => 1,
        GroupRole.member => 0,
      };

  bool isAtLeast(GroupRole other) => rank >= other.rank;

  String get label => switch (this) {
        GroupRole.owner  => 'Propietario',
        GroupRole.admin  => 'Administrador',
        GroupRole.member => 'Miembro',
      };
}

class GroupMemberModel {
  final String  username;
  final String? displayName;
  final String? avatarUrl;
  final GroupRole role;

  const GroupMemberModel({
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.role,
  });

  String get displayLabel =>
      displayName?.isNotEmpty == true ? displayName! : username;

  factory GroupMemberModel.fromJson(Map<String, dynamic> j) => GroupMemberModel(
        username:    j['username']    as String,
        displayName: j['displayName'] as String?,
        avatarUrl:   j['avatarUrl']   as String?,
        role:        groupRoleFromString(j['role'] as String?),
      );
}

class GroupModel {
  final int     id;
  final String  name;
  final String? description;
  final String? photoUrl;
  final String  ownerUsername;
  final int     memberCount;
  final GroupRole myRole;
  final GroupPermission invitePolicy;
  final GroupPermission editInfoPolicy;
  final GroupPermission sendMessagePolicy;
  final GroupPermission startQuizPolicy;
  final List<GroupMemberModel> members;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.ownerUsername,
    required this.memberCount,
    required this.myRole,
    required this.invitePolicy,
    required this.editInfoPolicy,
    required this.sendMessagePolicy,
    required this.startQuizPolicy,
    this.members = const [],
  });

  bool get isAdmin => myRole.isAtLeast(GroupRole.admin);
  bool get isOwner => myRole == GroupRole.owner;

  /// ¿Puede el usuario actual realizar una acción regida por [policy]?
  bool can(GroupPermission policy) => policy == GroupPermission.allMembers
      ? true
      : myRole.isAtLeast(GroupRole.admin);

  factory GroupModel.fromJson(Map<String, dynamic> j) => GroupModel(
        id:            (j['id'] as num).toInt(),
        name:          j['name'] as String,
        description:   j['description'] as String?,
        photoUrl:      j['photoUrl'] as String?,
        ownerUsername: j['ownerUsername'] as String,
        memberCount:   (j['memberCount'] as num?)?.toInt() ?? 0,
        myRole:        groupRoleFromString(j['myRole'] as String?),
        invitePolicy:      groupPermissionFromString(j['invitePolicy'] as String?),
        editInfoPolicy:    groupPermissionFromString(j['editInfoPolicy'] as String?),
        sendMessagePolicy: groupPermissionFromString(j['sendMessagePolicy'] as String?),
        startQuizPolicy:   groupPermissionFromString(j['startQuizPolicy'] as String?),
        members: (j['members'] as List?)
                ?.map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class GroupInvitationModel {
  final int     id;
  final int     groupId;
  final String  groupName;
  final String? groupPhotoUrl;
  final String  senderName;
  final String? senderAvatar;

  const GroupInvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupPhotoUrl,
    required this.senderName,
    this.senderAvatar,
  });

  factory GroupInvitationModel.fromJson(Map<String, dynamic> j) =>
      GroupInvitationModel(
        id:            (j['id'] as num).toInt(),
        groupId:       (j['groupId'] as num).toInt(),
        groupName:     j['groupName'] as String,
        groupPhotoUrl: j['groupPhotoUrl'] as String?,
        senderName:    j['senderName'] as String,
        senderAvatar:  j['senderAvatar'] as String?,
      );
}

/// Mensaje de grupo (USER, SYSTEM o QUIZ_CHALLENGE).
/// Los de sistema se pintan centrados; los de reto, como tarjeta con "Unirse".
class GroupMessage {
  final String  sender;
  final String  text;
  final int     timestamp;
  final String  type;          // USER | SYSTEM | QUIZ_CHALLENGE | QUIZ_RESULT
  final int?    matchId;
  final String? mode;
  final int?    totalRounds;
  final String? winner;
  final List<dynamic>? standings;

  const GroupMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.type,
    this.matchId,
    this.mode,
    this.totalRounds,
    this.winner,
    this.standings,
  });

  bool get system      => type == 'SYSTEM';
  bool get isChallenge => type == 'QUIZ_CHALLENGE' && matchId != null;
  bool get isResult    => type == 'QUIZ_RESULT';

  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        sender:      j['sender'] as String? ?? '',
        text:        j['text']   as String? ?? '',
        timestamp:   (j['timestamp'] as num?)?.toInt() ?? 0,
        type:        j['type'] as String? ?? 'USER',
        matchId:     (j['matchId']    as num?)?.toInt(),
        mode:        j['mode']        as String?,
        totalRounds: (j['totalRounds'] as num?)?.toInt(),
        winner:      j['winner']      as String?,
        standings:   j['standings']   as List<dynamic>?,
      );

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get timeLabel {
    final dt = dateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
