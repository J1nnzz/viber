import 'room.dart';

abstract class RoomRepository {
  Future<List<Room>> getPublicRooms();
  Future<List<Room>> getMyRooms();
  Future<Room> createRoom({
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
  });
  Future<Room> joinByCode(String code);
  Future<Room> updateRoom({
    required int roomId,
    required String name,
    String? description,
    List<String>? genres,
    required String privacy,
    String? accessCode,
    int? maxParticipants,
  });
  Future<void> closeRoom(int roomId);
  Future<bool> isKickedFromRoom(int roomId);
  Future<void> reportRoom({required int roomId, required String reason});
  Future<List<String>> fetchGenres();
}
