enum MessageSender { user, bot }

enum MessageType { text, eventList, bookingHistory, itinerary, movieList, theatreList, showtimeList }

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

  factory ChatMessageModel.fromHistory(Map<String, dynamic> json) {
    final senderRaw = (json['sender'] as String?)?.toLowerCase() ?? 'bot';
    return ChatMessageModel(
      content: json['content'] as String? ?? '',
      sender: senderRaw == 'user' ? MessageSender.user : MessageSender.bot,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}