import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SeatGrid extends StatefulWidget {
  final List seats;
  final int eventId;
  final int userId;
  final Function(List<int>) onSelectionChanged;

  const SeatGrid({
  Key? key,
  required this.seats,
  required this.eventId,
  required this.userId,
  required this.onSelectionChanged,
}) : super(key: key);


  @override
  _SeatGridState createState() => _SeatGridState();
}


class _SeatGridState extends State<SeatGrid> {
  Set<int> selectedSeats = {};

  @override
Widget build(BuildContext context) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: widget.seats.map((seat) {
      final seatId = seat['id'];
      final status = seat['status'];
      final isSelected = selectedSeats.contains(seatId);

      Color seatColor;

      if (status == "booked") {
        seatColor = Colors.red;
      } else if (status == "locked") {
        seatColor = Colors.yellow;
      } else if (isSelected) {
        seatColor = Colors.orange;
      } else {
        seatColor = Colors.green;
      }

      return GestureDetector(
       onTap: () {
        if (status != "available") return;

        setState(() {
          if (selectedSeats.contains(seatId)) {
            selectedSeats.remove(seatId);
          } else {
            selectedSeats.add(seatId);
          }
        });

        widget.onSelectionChanged(selectedSeats.toList());
      },


        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: seatColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "${seat['row_number']}-${seat['seat_number']}",
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }).toList(),
  );
}
}
