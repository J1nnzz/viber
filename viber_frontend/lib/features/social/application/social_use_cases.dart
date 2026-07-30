import 'dart:typed_data';
import '../domain/user_profile.dart';
import '../domain/social_repository.dart';

class GetMyProfileUseCase {
  final SocialRepository _repository;
  GetMyProfileUseCase(this._repository);
  Future<UserProfile> call() => _repository.getMe();
}

class GetUserProfileUseCase {
  final SocialRepository _repository;
  GetUserProfileUseCase(this._repository);
  Future<UserProfile> call(String username) => _repository.getProfile(username);
}

class SearchUsersUseCase {
  final SocialRepository _repository;
  SearchUsersUseCase(this._repository);
  Future<List<UserProfile>> call(String query) => _repository.searchUsers(query);
}

class UpdateProfileUseCase {
  final SocialRepository _repository;
  UpdateProfileUseCase(this._repository);
  Future<UserProfile> call({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) =>
      _repository.updateMe(
        username: username,
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
      );
}

class UpdatePrivacyUseCase {
  final SocialRepository _repository;
  UpdatePrivacyUseCase(this._repository);
  Future<UserProfile> call({required bool hidden}) =>
      _repository.updatePrivacy(hidden: hidden);
}

class UploadAvatarUseCase {
  final SocialRepository _repository;
  UploadAvatarUseCase(this._repository);
  Future<String> call(Uint8List imageBytes, String filename) =>
      _repository.uploadAvatar(imageBytes, filename);
}

class GetFriendsUseCase {
  final SocialRepository _repository;
  GetFriendsUseCase(this._repository);
  Future<List<UserProfile>> call() => _repository.getFriends();
}

class GetPendingRequestsUseCase {
  final SocialRepository _repository;
  GetPendingRequestsUseCase(this._repository);
  Future<List<UserProfile>> call() => _repository.getPending();
}

class SendFriendRequestUseCase {
  final SocialRepository _repository;
  SendFriendRequestUseCase(this._repository);
  Future<void> call(String username) => _repository.sendRequest(username);
}

class AcceptFriendRequestUseCase {
  final SocialRepository _repository;
  AcceptFriendRequestUseCase(this._repository);
  Future<void> call(String username) => _repository.acceptRequest(username);
}

class RemoveFriendUseCase {
  final SocialRepository _repository;
  RemoveFriendUseCase(this._repository);
  Future<void> call(String username) => _repository.removeFriend(username);
}

class GetFriendsStatusUseCase {
  final SocialRepository _repository;
  GetFriendsStatusUseCase(this._repository);
  Future<List<FriendStatus>> call() => _repository.getFriendsStatus();
}

class InviteFriendUseCase {
  final SocialRepository _repository;
  InviteFriendUseCase(this._repository);
  Future<void> call(String username, int roomId) =>
      _repository.inviteFriend(username, roomId);
}

class GetInvitationsUseCase {
  final SocialRepository _repository;
  GetInvitationsUseCase(this._repository);
  Future<List<RoomInvitation>> call() => _repository.getInvitations();
}

class DismissInvitationUseCase {
  final SocialRepository _repository;
  DismissInvitationUseCase(this._repository);
  Future<void> call(int id) => _repository.dismissInvitation(id);
}
