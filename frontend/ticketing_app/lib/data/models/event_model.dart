class EventModel {
  final int id;
  final String name;
  final String description;
  final String venue;
  final DateTime dateTime;
  final double price;
  final String category;

  const EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.venue,
    required this.dateTime,
    required this.price,
    required this.category,
  });

  /// Static demo event matching backend event ID 1
  static final EventModel demo = EventModel(
    id: 1,
    name: 'The Grand Showcase',
    description:
        'An unforgettable evening of live performances, featuring world-class acts across music and entertainment.',
    venue: 'Grand Arena, Hall A',
    dateTime: DateTime(2026, 3, 15, 19, 30),
    price: 50.0,
    category: 'Live Event',
  );

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String get formattedTime {
    final h = dateTime.hour;
    final m = dateTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}
