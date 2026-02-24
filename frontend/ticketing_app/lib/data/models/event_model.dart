class EventModel {
  final int id;
  final String name;
  final String description;
  final String venue;
  final DateTime date;
  final double price;

  const EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.venue,
    required this.date,
    required this.price,
  });

  String get formattedDate {
    final d = date;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Backend returns 'event_date', fallback to 'date'
    final rawDate = json['event_date'] as String? ?? json['date'] as String?;
    return EventModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      venue: json['venue'] as String? ?? json['location'] as String? ?? '',
      date: rawDate != null
          ? DateTime.tryParse(rawDate) ?? DateTime.now()
          : DateTime.now(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static EventModel get demo => EventModel(
        id: 1,
        name: 'Music Night',
        description: 'An unforgettable evening of live music and performance.',
        venue: 'City Arena, Hall A',
        date: DateTime.now().add(const Duration(hours: 5)),
        price: 500.0,
      );
}