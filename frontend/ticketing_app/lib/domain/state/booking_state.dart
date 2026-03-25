import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/seat_model.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/services/notification_service.dart';

enum BookingPhase { idle, loading, locked, confirmed, paid, error }

class BookingState extends ChangeNotifier {
  final BookingRepository _repository;

  List<SeatModel> _seats = [];
  BookingModel? _currentBooking;
  DateTime? _lockExpiration;
  BookingPhase _phase = BookingPhase.idle;
  String? _errorMessage;
  bool _lockExpiredNotice = false;
  Timer? _countdownTimer;
  List<int> _lockedSeatIds = [];
  int? _currentUserId;
  int? _currentEventId;  // null until user selects an event
  int _desiredSeatCount = 1;
  bool _resumePayment = false;
  List<int> _selectionOrder = [];

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
  bool get lockExpiredNotice => _lockExpiredNotice;
  int get desiredSeatCount => _desiredSeatCount;
  bool get isLoading => _phase == BookingPhase.loading;
  bool get isLocked => _phase == BookingPhase.locked;
  bool get hasSeats => _seats.isNotEmpty;
  bool get shouldResumePayment => _resumePayment;

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

  void setCurrentEventId(int eventId) {
    _currentEventId = eventId;
  }

  bool consumeResumePayment() {
    if (!_resumePayment) return false;
    _resumePayment = false;
    return true;
  }

  void setDesiredSeatCount(int count) {
    _desiredSeatCount = count.clamp(1, 8);
    notifyListeners();
  }

  Future<void> fetchSeats() async {
    if (_currentEventId == null) {
      _errorMessage = 'No event selected';
      _phase = BookingPhase.error;
      notifyListeners();
      return;
    }
    _phase = BookingPhase.loading;
    _errorMessage = null;
    _lockExpiredNotice = false;
    notifyListeners();
    try {
      final freshSeats = await _repository.getSeats(_currentEventId!);
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

    if (seat.isSelected) {
      updated[idx] = seat.copyWith(isSelected: false);
      _selectionOrder.remove(seatId);
      _seats = updated;
      notifyListeners();
      return;
    }

    if (selectedSeats.length >= _desiredSeatCount) {
      final oldestId = _selectionOrder.isNotEmpty ? _selectionOrder.first : null;
      if (oldestId != null) {
        final oldestIdx = updated.indexWhere((s) => s.id == oldestId);
        if (oldestIdx != -1) {
          updated[oldestIdx] = updated[oldestIdx].copyWith(isSelected: false);
        }
        _selectionOrder.removeAt(0);
      }
    }

    updated[idx] = seat.copyWith(isSelected: true);
    _selectionOrder.add(seatId);
    _seats = updated;
    notifyListeners();
  }

  /// Pre-selects seats recommended by the chatbot.
  void applyRecommendedSeats(List<int> recommendedIds) {
    if (_phase == BookingPhase.loading || isLocked || _seats.isEmpty) return;
    final allowedIds = recommendedIds.take(_desiredSeatCount).toList();
    final allowedSet = allowedIds.toSet();
    final updated = _seats.map((seat) {
      if (allowedSet.contains(seat.id) && seat.isInteractable) {
        return seat.copyWith(isSelected: true);
      }
      return seat;
    }).toList();
    _seats = updated;
    _selectionOrder = List<int>.from(allowedIds);
    notifyListeners();
  }

  Future<bool> lockSelection() async {
    final tolock = selectedSeats;
    if (tolock.isEmpty) return false;
    if (tolock.length != _desiredSeatCount) {
      _errorMessage = 'Select exactly $_desiredSeatCount seat${_desiredSeatCount > 1 ? 's' : ''} to continue.';
      _phase = BookingPhase.error;
      notifyListeners();
      return false;
    }
    if (_currentEventId == null) return false;
    final ids = tolock.map((s) => s.id).toList();
    final userId = _currentUserId ?? 1;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    _lockExpiredNotice = false;
    notifyListeners();

    try {
      _lockExpiration = await _repository.lockSeats(
        _currentEventId!,
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
      // Schedule expiry warning notification 2 min before lock expires
      NotificationService.instance.scheduleLockExpiryWarning(_lockExpiration!);
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
    if (_currentEventId == null) return false;
    final userId = _currentUserId ?? 1;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    _lockExpiredNotice = false;
    notifyListeners();

    try {
      _currentBooking = await _repository.createBooking(
        _currentEventId!,
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
        _currentBooking!.id!,
      );
      _currentBooking = _currentBooking?.copyWith(status: 'confirmed');
      _countdownTimer?.cancel();
      _lockExpiration = null;
      _phase = BookingPhase.paid;
      NotificationService.instance.cancelLockWarning();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _currentBooking = _currentBooking?.copyWith(status: 'payment_failed');
      _phase = BookingPhase.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelBooking() async {
    if (_currentBooking?.id == null) return false;

    _phase = BookingPhase.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.cancelBooking(_currentBooking!.id!);
      _currentBooking = updated;
      _phase = BookingPhase.idle;
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
    _selectionOrder = [];
    final updated = _seats.map((s) {
      if (s.isSelected || s.status == SeatStatus.locked) {
        return s.copyWith(isSelected: false, status: SeatStatus.available);
      }
      return s;
    }).toList();
    _seats = updated;
    _errorMessage = 'Seats released. Please retry.';
    _lockExpiredNotice = true;
    _phase = BookingPhase.idle;
    notifyListeners();
    Future.microtask(fetchSeats);
  }

  void clearError() {
    _errorMessage = null;
    _lockExpiredNotice = false;
    if (_phase == BookingPhase.error) _phase = BookingPhase.idle;
    notifyListeners();
  }

  void clearSelection() {
    _lockedSeatIds = [];
    _seats = _seats.map((s) => s.copyWith(isSelected: false)).toList();
    _selectionOrder = [];
    notifyListeners();
  }

  void reset() {
    _countdownTimer?.cancel();
    _seats = [];
    _currentBooking = null;
    _lockExpiration = null;
    _lockedSeatIds = [];
    _currentEventId = null;
    _desiredSeatCount = 1;
    _phase = BookingPhase.idle;
    _errorMessage = null;
    _lockExpiredNotice = false;
    _resumePayment = false;
    _selectionOrder = [];
    notifyListeners();
  }

  Future<void> resumeFromPayload(Map<String, dynamic> payload) async {
    final kind = payload['kind'] as String?;
    final eventId = payload['event_id'] as int?;
    final seatIdsRaw = payload['seat_ids'] as List<dynamic>? ?? [];
    final seatIds = seatIdsRaw.map((e) => (e as num).toInt()).toList();
    final bookingId = payload['booking_id'] as int?;
    final totalAmount = (payload['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = payload['status'] as String? ?? 'pending';
    final expiresAtRaw = payload['expires_at'] as String?;

    if (eventId == null) return;

    _currentEventId = eventId;
    _lockedSeatIds = seatIds;
    _selectionOrder = List<int>.from(seatIds);
    _lockExpiredNotice = false;
    _errorMessage = null;
    _resumePayment = false;

    await fetchSeats();

    final updated = _seats.map((seat) {
      if (seatIds.contains(seat.id)) {
        return seat.copyWith(isSelected: true, status: SeatStatus.locked);
      }
      return seat;
    }).toList();
    _seats = updated;

    if (kind == 'payment' && bookingId != null) {
      final userId = _currentUserId ?? 1;
      _currentBooking = BookingModel(
        id: bookingId,
        userId: userId,
        eventId: eventId,
        seatIds: seatIds,
        totalAmount: totalAmount,
        status: status,
      );
      _phase = BookingPhase.confirmed;
      _resumePayment = true;
      notifyListeners();
      return;
    }

    if (expiresAtRaw != null) {
      _lockExpiration = DateTime.tryParse(expiresAtRaw)?.toLocal();
    }
    if (_lockExpiration != null) {
      _phase = BookingPhase.locked;
      _startCountdown();
      NotificationService.instance.scheduleLockExpiryWarning(_lockExpiration!);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}