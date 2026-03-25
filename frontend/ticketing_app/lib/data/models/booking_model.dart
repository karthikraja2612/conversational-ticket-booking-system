class BookingModel {
  final int? id;
  final int userId;
  final int eventId;
  final String? eventName;
  final List<int> seatIds;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;
  final DateTime? cancellationTime;
  final String? refundStatus;

  const BookingModel({
    this.id,
    required this.userId,
    required this.eventId,
    this.eventName,
    required this.seatIds,
    required this.totalAmount,
    required this.status,
    this.createdAt,
    this.cancellationTime,
    this.refundStatus,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['booking_id'] as int?,
      userId: json['user_id'] as int? ?? 0,
      eventId: json['event_id'] as int? ?? 0,
      eventName: json['event_name'] as String?,
      seatIds: (json['seat_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      cancellationTime: json['cancellation_time'] != null
          ? DateTime.tryParse(json['cancellation_time'] as String)
          : null,
      refundStatus: json['refund_status'] as String?,
    );
  }

  // Helper factory for the specific confirmed booking response structure
  factory BookingModel.fromConfirmation(Map<String, dynamic> json, int userId, int eventId, List<int> seatIds) {
    return BookingModel(
      id: (json['booking_id'] as num?)?.toInt(),
      userId: userId,
      eventId: eventId,
      seatIds: seatIds,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: 'pending_payment',
    );
  }

  BookingModel copyWith({
    int? id,
    int? userId,
    int? eventId,
    String? eventName,
    List<int>? seatIds,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    DateTime? cancellationTime,
    String? refundStatus,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      seatIds: seatIds ?? this.seatIds,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cancellationTime: cancellationTime ?? this.cancellationTime,
      refundStatus: refundStatus ?? this.refundStatus,
    );
  }
}