import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/seat_model.dart';
import '../../data/repositories/booking_repository.dart';

enum BookingPhase { idle, loading, locked, confirmed, paid, error }

class BookingState extends ChangeNotifier {
  final BookingRepository _repository;

  List<SeatModel> _seats = [];
  BookingModel? _currentBooking;
  DateTime? _lockExpiration;
  BookingPhase _phase = BookingPhase.idle;
  String? _errorMessage;
  Timer? _countdownTimer;
  List<int> _lockedSeatIds = [];
  int? _currentUserId;

  BookingState({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  List<SeatModel> get seats => _seats;
  List<SeatModel> get selectedSeats =>
      _seats.where((s) => s.isSelected).toList();
  List<int> get lockedSeatIds => List.unmodifiable(_lockedSeatIds);
  int get lockedCount => _lockedSeatIds.length;
  BookingModel? get currentBooking => _currentBooking;
  DateTime? get lockExpiration => _lockExpiration;
  BookingPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _phase == BookingPhase.loading;
  bool get isLocked => _phase == BookingPhase.locked;
  bool get hasSeats => _seats.isNotEmpty;

  Duration get remainingLockTime {
    if (_lockExpiration == null) return Duration.zero;
    final remaining = _lockExpiration!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void setAuthToken(String? token) {
    _repository.setAuthToken(token);
  }

  void setCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  Future<void> fetchSeats() async {
    _phase = BookingPhase.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final freshSeats = await _repository.getSeats(AppConstants.defaultEventId);
      // Reset all selections when fetching fresh seat data
      _seats = freshSeats.map((s) => s.copyWith(isSelected: false)).toList();
      _phase = BookingPhase.idle;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _phase = BookingPhase.error;
    }
    notifyListeners();
  }

  void toggleSeat(int seatId) {
    if (_phase == BookingPhase.loading || isLocked) return;
    final idx = _seats.indexWhere((s) => s.id == seatId);
    if (idx == -1) return;
    final seat = _seats[idx];
    if (!seat.isInteractable) return;
    final updated = List<SeatModel>.from(_seats);
    updated[idx] = seat.copyWith(isSelected: !seat.isSelected);
    _seats = updated;
    notifyListeners();
  }

  /// Pre-selects seats recommended by the chatbot.
  void applyRecommendedSeats(List<int> recommendedIds) {
    if (_phase == BookingPhase.loading || isLocked || _seats.isEmpty) return;
    final updated = _seats.map((seat) {
      if (recommendedIds.contains(seat.id) && seat.isInteractable) {
        return seat.copyWith(isSelected: true);
      }
      return seat;
    }).toList();
    _seats = updated;
    notifyListeners();
  }

  Future<bool> lockSelection() async {
    final tolock = selectedSeats;
    if (tolock.isEmpty) return false;
    final ids = tolock.map((s) => s.id).toList();
    final userId = _currentUserId ?? 1;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _lockExpiration = await _repository.lockSeats(
        AppConstants.defaultEventId,
        userId,
        ids,
      );
      _lockedSeatIds = List<int>.from(ids);
      final updated = List<SeatModel>.from(_seats);
      for (var i = 0; i < updated.length; i++) {
        if (ids.contains(updated[i].id)) {
          updated[i] = updated[i].copyWith(
            status: SeatStatus.locked,
            isSelected: true,
          );
        }
      }
      _seats = updated;
      _phase = BookingPhase.locked;
      _startCountdown();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _phase = BookingPhase.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmBooking() async {
    final ids = _lockedSeatIds;
    if (ids.isEmpty) return false;
    final userId = _currentUserId ?? 1;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentBooking = await _repository.createBooking(
        AppConstants.defaultEventId,
        userId,
        ids,
      );
      _phase = BookingPhase.confirmed;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _phase = BookingPhase.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> processPayment() async {
    if (_currentBooking?.id == null) return false;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.payForBooking(
        AppConstants.defaultEventId,
        _currentBooking!.id!,
      );
      _countdownTimer?.cancel();
      _lockExpiration = null;
      _phase = BookingPhase.paid;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _phase = BookingPhase.error;
      notifyListeners();
      return false;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lockExpiration != null &&
          DateTime.now().isAfter(_lockExpiration!)) {
        _handleExpiration();
      } else {
        notifyListeners();
      }
    });
  }

  void _handleExpiration() {
    _countdownTimer?.cancel();
    _lockExpiration = null;
    _currentBooking = null;
    _lockedSeatIds = [];
    final updated = _seats.map((s) {
      if (s.isSelected || s.status == SeatStatus.locked) {
        return s.copyWith(isSelected: false, status: SeatStatus.available);
      }
      return s;
    }).toList();
    _seats = updated;
    _errorMessage = 'Seat lock expired. Please select again.';
    _phase = BookingPhase.idle;
    notifyListeners();
    Future.microtask(fetchSeats);
  }

  void clearError() {
    _errorMessage = null;
    if (_phase == BookingPhase.error) _phase = BookingPhase.idle;
    notifyListeners();
  }

  void clearSelection() {
    _lockedSeatIds = [];
    _seats = _seats.map((s) => s.copyWith(isSelected: false)).toList();
    notifyListeners();
  }

  void reset() {
    _countdownTimer?.cancel();
    _seats = [];
    _currentBooking = null;
    _lockExpiration = null;
    _lockedSeatIds = [];
    _phase = BookingPhase.idle;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}