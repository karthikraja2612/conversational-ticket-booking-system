class TripPlanItem {
  final String timeRange;
  final String place;
  final String type;
  final double? distanceKm;

  const TripPlanItem({
    required this.timeRange,
    required this.place,
    required this.type,
    this.distanceKm,
  });

  factory TripPlanItem.fromJson(Map<String, dynamic> json) {
    return TripPlanItem(
      timeRange: json['time'] as String? ?? '',
      place: json['place'] as String? ?? 'Place',
      type: json['type'] as String? ?? 'explore',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

class TripPlan {
  final String eventName;
  final String eventTime;
  final List<TripPlanItem> plan;

  const TripPlan({
    required this.eventName,
    required this.eventTime,
    required this.plan,
  });

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>?;
    final rawPlan = json['plan'] as List<dynamic>? ?? [];
    return TripPlan(
      eventName: event?['name'] as String? ?? 'Event',
      eventTime: event?['time'] as String? ?? '',
      plan: rawPlan
          .map((e) => TripPlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
