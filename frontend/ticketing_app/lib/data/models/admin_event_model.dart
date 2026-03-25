class AdminEventModel {
  final int id;
  final String name;
  final int venueId;
  final DateTime eventDate;
  final double basePrice;
  final String status; // draft / published
  final String? imageUrl;
  final DateTime? createdAt;
  final String eventType;
  final List<String> showTimes;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isDynamic;

  const AdminEventModel({
    required this.id,
    required this.name,
    required this.venueId,
    required this.eventDate,
    required this.basePrice,
    required this.status,
    this.imageUrl,
    this.createdAt,
    this.eventType = 'others',
    this.showTimes = const [],
    this.startDate,
    this.endDate,
    this.isDynamic = false,
  });

  bool get isPublished => status == 'published';

  String get formattedDate {
    if (eventType == 'movie' && startDate != null && endDate != null) {
      final start = startDate!;
      final end = endDate!;
      final startText = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
      final endText = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
      return '$startText → $endText';
    }
    final d = eventDate;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  factory AdminEventModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['event_date'] as String? ?? json['date'] as String?;
    final rawCreated = json['created_at'] as String?;
    final rawStart = json['start_date'] as String?;
    final rawEnd = json['end_date'] as String?;
    final rawType = json['event_type'] as String?;
    final rawShowTimes = json['show_times'] as List<dynamic>?;
    return AdminEventModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      venueId: json['venue_id'] as int? ?? 0,
      eventDate:
          rawDate != null ? DateTime.tryParse(rawDate) ?? DateTime.now() : DateTime.now(),
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'draft',
      imageUrl: json['image_url'] as String?,
      createdAt: rawCreated != null ? DateTime.tryParse(rawCreated) : null,
      eventType: (rawType ?? 'others').toLowerCase(),
      showTimes: rawShowTimes?.map((t) => t.toString()).toList() ?? const [],
      startDate: rawStart != null ? DateTime.tryParse(rawStart) : null,
      endDate: rawEnd != null ? DateTime.tryParse(rawEnd) : null,
      isDynamic: json['is_dynamic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'venue_id': venueId,
        'event_date': eventDate.toIso8601String(),
        'base_price': basePrice,
        if (imageUrl != null) 'image_url': imageUrl,
      };
}
