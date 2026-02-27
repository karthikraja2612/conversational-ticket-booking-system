class VenueModel {
  final int id;
  final String name;
  final String location;
  final int totalRows;
  final int seatsPerRow;

  const VenueModel({
    required this.id,
    required this.name,
    required this.location,
    required this.totalRows,
    required this.seatsPerRow,
  });

  int get totalCapacity => totalRows * seatsPerRow;

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      totalRows: json['total_rows'] as int? ?? 0,
      seatsPerRow: json['seats_per_row'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'total_rows': totalRows,
        'seats_per_row': seatsPerRow,
      };
}
