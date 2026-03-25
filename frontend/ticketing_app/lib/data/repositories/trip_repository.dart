import '../models/trip_plan_model.dart';
import '../services/api_service.dart';

class TripRepository {
  final ApiService _apiService;

  TripRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  void setAuthToken(String? token) {
    _apiService.setAuthToken(token);
  }

  Future<TripPlan> planFromBooking(
    int bookingId, {
    String? intent,
    bool refresh = false,
  }) async {
    final data = await _apiService.planTripFromBooking(
      bookingId,
      intent: intent,
      refresh: refresh,
    );
    return TripPlan.fromJson(data);
  }
}
