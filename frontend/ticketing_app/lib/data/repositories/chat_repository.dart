import '../services/chat_service.dart';

class ChatRepository {
  final ChatService _chatService;

  ChatRepository({ChatService? chatService})
      : _chatService = chatService ?? ChatService();

  Future<Map<String, dynamic>> sendMessage(String message, String token) async {
    return await _chatService.sendMessage(message, token);
  }
}