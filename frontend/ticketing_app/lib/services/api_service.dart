import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.92.76.147:8000";

static Future<List<dynamic>> getSeatStatus(int eventId) async {
  final response = await http.get(
    Uri.parse("$baseUrl/events/$eventId/seats-status"),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Failed to load seat status");
  }
}

  static Future<void> lockSeats(int eventId, int userId, List<int> seatIds) async {
  final response = await http.post(
    Uri.parse("$baseUrl/events/$eventId/lock-seats"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "user_id": userId,
      "seat_ids": seatIds,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to lock seats");
  }
}

}
