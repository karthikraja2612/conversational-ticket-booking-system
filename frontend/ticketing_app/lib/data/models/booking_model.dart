class BookingModel {
  final int? id;
  final int userId;
  final int eventId;
  final List<int> seatIds;
  final double totalAmount;
  final String status;

  const BookingModel({
    this.id,
    required this.userId,
    required this.eventId,
    required this.seatIds,
    required this.totalAmount,
    required this.status,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['booking_id'] as int?,
      userId: json['user_id'] as int? ?? 0,
      eventId: json['event_id'] as int? ?? 0,
      seatIds: (json['seat_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  // Helper factory for the specific confirmed booking response structure
  factory BookingModel.fromConfirmation(Map<String, dynamic> json, int userId, int eventId, List<int> seatIds) {
    return BookingModel(
      id: json['booking_id'] as int?,
      userId: userId,
      eventId: eventId,
      seatIds: seatIds,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: 'pending_payment',
    );
  }
}