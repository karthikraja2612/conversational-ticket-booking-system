import '../models/seat_model.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';

class BookingRepository {
  final ApiService _apiService;

  BookingRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  void setAuthToken(String? token) {
    _apiService.setAuthToken(token);
  }

  Future<List<SeatModel>> getSeats(int eventId) async {
    return await _apiService.fetchSeatsStatus(eventId);
  }

  Future<DateTime> lockSeats(int eventId, int userId, List<int> seatIds) async {
    return await _apiService.lockSeats(eventId, userId, seatIds);
  }

  Future<BookingModel> createBooking(int eventId, int userId, List<int> seatIds) async {
    return await _apiService.confirmBooking(eventId, userId, seatIds);
  }

  Future<void> payForBooking(int eventId, int bookingId) async {
    await _apiService.processPayment(eventId, bookingId);
  }
}