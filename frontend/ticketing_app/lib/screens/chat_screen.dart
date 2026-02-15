import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../widgets/seat_grid.dart';
import '../screens/payment_screen.dart';


class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> messages = [];
  List<int> selectedSeats = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    addBotMessage("Welcome to Ticket Booking!");
  }

  void addBotMessage(String text) {
    setState(() {
      messages.add(ChatMessage(
        sender: "bot",
        type: MessageType.text,
        data: text,
      ));
    });
  }

  void addUserMessage(String text) {
    setState(() {
      messages.add(ChatMessage(
        sender: "user",
        type: MessageType.text,
        data: text,
      ));
    });
  }

  Future<void> fetchSeats() async {
  setState(() {
    isLoading = true;
  });

  final seats = await ApiService.getSeatStatus(1);

  setState(() {
    // Remove old seatList message
    messages.removeWhere(
        (message) => message.type == MessageType.seatList);

    messages.add(ChatMessage(
      sender: "bot",
      type: MessageType.seatList,
      data: seats,
    ));

    isLoading = false;
  });
}

Future<void> lockAndProceed() async {
  try {
    await ApiService.lockSeats(1, 1, selectedSeats);

    if (!mounted) return;
  
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          selectedSeats: selectedSeats,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Some seats are already locked")),
    );

    fetchSeats(); // refresh seat status
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat Booking"),
          actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchSeats,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                if (message.type == MessageType.text) {
                  return ListTile(
                    title: Align(
                      alignment: message.sender == "bot"
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        color: message.sender == "bot"
                            ? Colors.grey[300]
                            : Colors.blue[200],
                        child: Text(message.data),
                      ),
                    ),
                  );
                }

                if (message.type == MessageType.seatList) {
                  final seats = message.data as List;
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SeatGrid(
                      seats: seats,
                      eventId: 1,
                      userId: 1,
                      onSelectionChanged: (seats) {
                        setState(() {
                          selectedSeats = seats;
                        });
                      },
                    ),
                  );
                }

                return SizedBox();
              },
            ),
          ),
          if (isLoading) CircularProgressIndicator(),
          if (selectedSeats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: lockAndProceed,
                child: Text("Proceed to Booking"),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: fetchSeats,
              child: Text("Show Seats"),
            ),
          )
        ],
      ),
    );
  }
}
