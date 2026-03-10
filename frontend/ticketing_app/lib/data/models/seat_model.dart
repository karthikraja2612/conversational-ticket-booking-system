enum SeatStatus { available, locked, booked }

class SeatModel {
  final int id;
  final int rowNumber;
  final int seatNumber;
  final SeatStatus status;
  final bool isSelected;

  const SeatModel({
    required this.id,
    required this.rowNumber,
    required this.seatNumber,
    required this.status,
    this.isSelected = false,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    return SeatModel(
      id: (json['id'] as num).toInt(),
      rowNumber: (json['row_number'] as num).toInt(),
      seatNumber: (json['seat_number'] as num).toInt(),
      status: _parseStatus(json['status'] as String?),
    );
  }

  static SeatStatus _parseStatus(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'locked':
        return SeatStatus.locked;
      case 'booked':
        return SeatStatus.booked;
      default:
        return SeatStatus.available;
    }
  }

  /// Returns the absolute seat number (1-based) given the total seats per row.
  int absoluteNumber(int seatsPerRow) => (rowNumber - 1) * seatsPerRow + seatNumber;

  SeatModel copyWith({
    int? id,
    int? rowNumber,
    int? seatNumber,
    SeatStatus? status,
    bool? isSelected,
  }) {
    return SeatModel(
      id: id ?? this.id,
      rowNumber: rowNumber ?? this.rowNumber,
      seatNumber: seatNumber ?? this.seatNumber,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  bool get isInteractable => status == SeatStatus.available;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SeatModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}