enum MessageSender { user, bot }

class ChatMessageModel {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessageModel({
    String? id,
    required this.content,
    required this.sender,
    required this.timestamp,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}
