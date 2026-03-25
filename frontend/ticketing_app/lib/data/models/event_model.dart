class EventModel {
  final int id;
  final String name;
  final String description;
  final String venue;
  final int? venueId;
  final String? theatreName;
  final String? theatreLocation;
  final DateTime date;
  final double price;
  final String eventType;
  final bool isDynamic;
  final List<String> availableDates;
  final Map<String, List<String>> showTimesByDate;

  const EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.venue,
    this.venueId,
    this.theatreName,
    this.theatreLocation,
    required this.date,
    required this.price,
    required this.eventType,
    this.isDynamic = false,
    this.availableDates = const [],
    this.showTimesByDate = const {},
  });

  String get formattedDate {
    final d = date;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Backend returns 'event_date', fallback to 'date'
    final rawDate = json['event_date'] as String? ?? json['date'] as String?;
    final rawType = json['event_type'] as String? ?? json['eventType'] as String?;
    final rawAvailableDates = json['available_dates'] as List<dynamic>?;
    final rawShowTimesByDate = json['show_times_by_date'] as Map<String, dynamic>?;
    final venueId = (json['venue_id'] as num?)?.toInt();
    final theatreName = json['theatre_name'] as String?;
    final theatreLocation = json['theatre_location'] as String?;
    return EventModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      venue: theatreName ?? json['venue'] as String? ?? json['location'] as String? ?? '',
      venueId: venueId,
      theatreName: theatreName,
      theatreLocation: theatreLocation,
      date: rawDate != null
          ? DateTime.tryParse(rawDate) ?? DateTime.now()
          : DateTime.now(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      eventType: (rawType ?? 'others').toLowerCase(),
      isDynamic: json['is_dynamic'] as bool? ?? false,
      availableDates:
          rawAvailableDates?.map((d) => d.toString()).toList() ?? const [],
      showTimesByDate: rawShowTimesByDate != null
          ? rawShowTimesByDate.map(
              (key, value) => MapEntry(
                key,
                value is List
                    ? value.map((t) => t.toString()).toList()
                    : const <String>[],
              ),
            )
          : const {},
    );
  }

  List<String> getShowTimesForDate(String dateKey) {
    return showTimesByDate[dateKey] ?? const [];
  }

  static EventModel get demo => EventModel(
        id: 1,
        name: 'Music Night',
        description: 'An unforgettable evening of live music and performance.',
        venue: 'City Arena, Hall A',
        date: DateTime.now().add(const Duration(hours: 5)),
        price: 500.0,
      eventType: 'concert',
      );
}