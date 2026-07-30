import '../domain/room.dart';
import '../domain/room_repository.dart';

class GetPublicRoomsUseCase {
  final RoomRepository _repository;
  GetPublicRoomsUseCase(this._repository);
  Future<List<Room>> call() => _repository.getPublicRooms();
}

class GetMyRoomsUseCase {
  final RoomRepository _repository;
  GetMyRoomsUseCase(this._repository);
  Future<List<Room>> call() => _repository.getMyRooms();
}

class CreateRoomUseCase {
  final RoomRepository _repository;
  CreateRoomUseCase(this._repository);
  Future<Room> call({
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
  }) =>
      _repository.createRoom(
        name: name,
        description: description,
        genres: genres,
        privacy: privacy,
        accessCode: accessCode,
        maxParticipants: maxParticipants,
      );
}

class JoinRoomByCodeUseCase {
  final RoomRepository _repository;
  JoinRoomByCodeUseCase(this._repository);
  Future<Room> call(String code) => _repository.joinByCode(code);
}

class UpdateRoomUseCase {
  final RoomRepository _repository;
  UpdateRoomUseCase(this._repository);
  Future<Room> call({
    required int roomId,
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
  }) =>
      _repository.updateRoom(
        roomId: roomId,
        name: name,
        description: description,
        genres: genres,
        privacy: privacy,
        accessCode: accessCode,
        maxParticipants: maxParticipants,
      );
}

class CloseRoomUseCase {
  final RoomRepository _repository;
  CloseRoomUseCase(this._repository);
  Future<void> call(int roomId) => _repository.closeRoom(roomId);
}

class ReportRoomUseCase {
  final RoomRepository _repository;
  ReportRoomUseCase(this._repository);
  Future<void> call({required int roomId, required String reason}) =>
      _repository.reportRoom(roomId: roomId, reason: reason);
}

class GetGenresUseCase {
  final RoomRepository _repository;
  GetGenresUseCase(this._repository);
  Future<List<String>> call() => _repository.fetchGenres();
}

class CheckKickedUseCase {
  final RoomRepository _repository;
  CheckKickedUseCase(this._repository);
  Future<bool> call(int roomId) => _repository.isKickedFromRoom(roomId);
}
