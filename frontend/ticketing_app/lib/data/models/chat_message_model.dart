enum MessageSender { user, bot }

enum MessageType { text, eventList, bookingHistory }

class ChatMessageModel {
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final Map<String, dynamic>? extraData;
  final MessageType messageType;

  const ChatMessageModel({
    required this.content,
    required this.sender,
    required this.timestamp,
    this.extraData,
    this.messageType = MessageType.text,
  });
}