import 'dart:async';
import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  final List<int> selectedSeats;

  const PaymentScreen({required this.selectedSeats});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Timer? _timer;
  int remainingSeconds = 300;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payment")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Seats Reserved"),
          Text(widget.selectedSeats.toString()),
          SizedBox(height: 20),
          Text(
            "Time Remaining: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}
