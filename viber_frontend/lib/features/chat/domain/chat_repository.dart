import 'chat_message.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<DmResult> getDMs(String username);
  Future<void> sendDM(String username, String text);
  Future<List<ChatMessage>> getGlobalMessages();
  Future<void> sendGlobal(String text);
}
