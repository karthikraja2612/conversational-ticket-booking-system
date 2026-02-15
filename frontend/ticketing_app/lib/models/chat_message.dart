enum MessageType {
  text,
  seatList,
}

class ChatMessage {
  final String sender; // "bot" or "user"
  final MessageType type;
  final dynamic data;

  ChatMessage({
    required this.sender,
    required this.type,
    this.data,
  });
}
