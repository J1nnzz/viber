import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';

class GetConversationsUseCase {
  final ChatRepository _repository;
  GetConversationsUseCase(this._repository);
  Future<List<Conversation>> call() => _repository.getConversations();
}

class GetDirectMessagesUseCase {
  final ChatRepository _repository;
  GetDirectMessagesUseCase(this._repository);
  Future<DmResult> call(String username) => _repository.getDMs(username);
}

class SendDirectMessageUseCase {
  final ChatRepository _repository;
  SendDirectMessageUseCase(this._repository);
  Future<void> call(String username, String text) =>
      _repository.sendDM(username, text);
}

class GetGlobalMessagesUseCase {
  final ChatRepository _repository;
  GetGlobalMessagesUseCase(this._repository);
  Future<List<ChatMessage>> call() => _repository.getGlobalMessages();
}

class SendGlobalMessageUseCase {
  final ChatRepository _repository;
  SendGlobalMessageUseCase(this._repository);
  Future<void> call(String text) => _repository.sendGlobal(text);
}
