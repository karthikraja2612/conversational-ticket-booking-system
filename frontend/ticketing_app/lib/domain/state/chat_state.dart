import 'package:flutter/foundation.dart';
import '../../data/models/chat_message_model.dart';

enum ChatFlowStep {
  welcome,
  selectingSeats,
  seatsLocked,
  confirmed,
  paymentDone,
}

class ChatState extends ChangeNotifier {
  final List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  ChatFlowStep _step = ChatFlowStep.welcome;
  bool _initialized = false;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  ChatFlowStep get step => _step;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _queueBot(
      "Hi! I am TicketBot, your AI booking assistant.",
      delay: 400,
    );
    _queueBot(
      "I will guide you through booking seats for tonight's event. Tap Select Seats when you are ready.",
      delay: 2000,
    );
  }

  void onSelectSeatsOpened() {
    if (_step != ChatFlowStep.welcome) return;
    _step = ChatFlowStep.selectingSeats;
    _addUser("I would like to select seats.");
    _queueBot(
      "Great! Choose your preferred seats from the grid. Available seats are shown in dark grey.",
      delay: 800,
    );
    notifyListeners();
  }

  void onSeatsLocked(int count) {
    _step = ChatFlowStep.seatsLocked;
    _addUser("I have selected $count seat${count > 1 ? 's' : ''}.");
    _queueBot(
      "I have locked $count seat${count > 1 ? 's' : ''} for you for the next 5 minutes.",
      delay: 600,
    );
    _queueBot(
      "Tap Confirm and Pay before the timer runs out!",
      delay: 2200,
    );
    notifyListeners();
  }

  void onBookingConfirmed() {
    _step = ChatFlowStep.confirmed;
    _addUser("Confirmed. Proceeding to payment.");
    _queueBot(
      "Booking confirmed! Complete your payment to receive your QR ticket.",
      delay: 600,
    );
    notifyListeners();
  }

  void onPaymentComplete() {
    _step = ChatFlowStep.paymentDone;
    _queueBot(
      "Payment successful! Your ticket has been generated. Enjoy the show!",
      delay: 400,
    );
    notifyListeners();
  }

  void onLockExpired() {
    _step = ChatFlowStep.selectingSeats;
    _queueBot(
      "Your seat lock expired. Please select your seats again.",
      delay: 200,
    );
    notifyListeners();
  }

  void _addUser(String text) {
    _messages.add(ChatMessageModel(
      content: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void _queueBot(String text, {int delay = 1000}) {
    _isTyping = true;
    notifyListeners();
    Future.delayed(Duration(milliseconds: delay), () {
      _isTyping = false;
      _messages.add(ChatMessageModel(
        content: text,
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    });
  }

  void reset() {
    _messages.clear();
    _isTyping = false;
    _step = ChatFlowStep.welcome;
    _initialized = false;
    notifyListeners();
  }
}
