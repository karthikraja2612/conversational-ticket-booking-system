import '../services/chat_service.dart';

class ChatRepository {
  final ChatService _chatService;

  ChatRepository({ChatService? chatService})
      : _chatService = chatService ?? ChatService();

  Future<Map<String, dynamic>> sendMessage(String message, String token) async {
    return await _chatService.sendMessage(message, token);
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String token, {int limit = 20}) async {
    return await _chatService.fetchHistory(token, limit: limit);
  }

  Future<void> clearHistory(String token) async {
    await _chatService.clearHistory(token);
  }
}