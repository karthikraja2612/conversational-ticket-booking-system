import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/event_model.dart';
import '../../../domain/state/chat_state.dart';
import '../../../domain/state/booking_state.dart';
import '../../../domain/state/event_state.dart';
import '../../screens/movie_showtime_selection_screen.dart';
import '../../screens/seat_selection_screen.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == MessageSender.bot;

    // ── Structured message types (always bot, no bubble wrapper) ──────────
    if (isBot && message.messageType == MessageType.eventList) {
      return _EventListMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.bookingHistory) {
      return _BookingHistoryMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.itinerary) {
      return _ItineraryMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.movieList) {
      return _MovieListMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.theatreList) {
      return _TheatreListMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.showtimeList) {
      return _ShowtimeListMessage(message: message);
    }

    // ── Regular text bubble ───────────────────────────────────────────────
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isBot ? null : AppColors.primaryGradient,
          color: isBot ? AppColors.surfaceLight : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isBot ? 4 : 20),
            bottomRight: Radius.circular(isBot ? 20 : 4),
          ),
          border: isBot
              ? Border.all(color: AppColors.borderSubtle)
              : null,
          boxShadow: isBot
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: AppTextStyles.body1
                  .copyWith(color: isBot ? AppColors.textPrimary : Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              message.timestamp.formattedTime,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event List Cards ──────────────────────────────────────────────────────────

class _EventListMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _EventListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final events =
        (message.extraData?['events'] as List<dynamic>?) ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bubble
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text('Here are the available events:',
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Event cards
            ...events.map((e) {
              final eventMap = e as Map<String, dynamic>;
              final eventId = (eventMap['id'] as num?)?.toInt() ?? 0;
              final eventName = eventMap['name'] as String? ?? 'Event';
              final eventPrice = (eventMap['price'] as num?)?.toDouble() ?? 0.0;
              final eventType =
                  (eventMap['event_type'] as String? ?? 'others').toLowerCase();

              return _EventCard(
                event: eventMap,
                onTap: () {
                  final selectedEvent = EventModel.fromJson({
                    ...eventMap,
                    'id': eventId,
                    'name': eventName,
                    'price': eventPrice,
                    'event_type': eventType,
                  });
                  context.read<EventState>().setSelectedEvent(selectedEvent);
                  context.read<BookingState>().setCurrentEventId(eventId);
                  context.read<BookingState>().clearSelection();
                  if (selectedEvent.isDynamic) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MovieShowtimeSelectionScreen(event: selectedEvent),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SeatSelectionScreen(),
                    ),
                  );
                },
              );
            }),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  const _EventCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = event['name'] as String? ?? 'Event';
    final price = (event['price'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.body1
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap to select seats',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              '₹${price.toStringAsFixed(0)}',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

// ── Booking History Cards ─────────────────────────────────────────────────────

class _BookingHistoryMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _BookingHistoryMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final bookings =
        (message.extraData?['bookings'] as List<dynamic>?) ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text('Your recent bookings:',
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...bookings
                .map((b) => _BookingCard(booking: b as Map<String, dynamic>)),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final id = booking['booking_id'];
    final status = (booking['status'] as String? ?? 'unknown').toUpperCase();
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
    final isConfirmed = status == 'CONFIRMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isConfirmed ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isConfirmed
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
              size: 18,
              color:
                  isConfirmed ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking #$id',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(status,
                    style: AppTextStyles.caption.copyWith(
                      color: isConfirmed
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style:
                AppTextStyles.body1.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Itinerary Timeline ─────────────────────────────────────────────────────

class _ItineraryMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _ItineraryMessage({required this.message});

  IconData _iconForType(String type, String? category) {
    final typeKey = type.toLowerCase();
    final categoryKey = (category ?? '').toLowerCase();
    if (typeKey.contains('museum')) {
      return Icons.museum;
    }
    if (categoryKey.contains('food') || categoryKey.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (categoryKey.contains('park')) {
      return Icons.park;
    }
    if (categoryKey.contains('entertainment') || categoryKey.contains('mall')) {
      return Icons.local_activity;
    }
    return Icons.place_rounded;
  }

  String _formatMinutes(num? minutes) {
    final value = (minutes ?? 0).toInt();
    if (value >= 60) {
      return '${(value / 60).toStringAsFixed(1)} hrs';
    }
    return '$value mins';
  }

  @override
  Widget build(BuildContext context) {
    final itinerary =
        (message.extraData?['itinerary'] as List<dynamic>?) ?? [];
    final totalMinutes = message.extraData?['total_estimated_time_min'];
    final planSummary = message.extraData?['plan_summary'] as String?;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      message.content,
                      style:
                          AppTextStyles.body1.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (planSummary != null && planSummary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  planSummary,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ...List.generate(itinerary.length, (index) {
              final data = itinerary[index] as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'place';
              final category = data['category'] as String?;
              final name = data['name'] as String? ?? 'Place';
              final minutes = data['estimated_time_min'] as num?;
              final icon = _iconForType(type, category);
              final duration = _formatMinutes(minutes);
              final isFirst = index == 0;
              final isLast = index == itinerary.length - 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 18,
                      child: Column(
                        children: [
                          if (!isFirst)
                            Container(
                              width: 2,
                              height: 10,
                              color: AppColors.borderSubtle,
                            ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 52,
                              color: AppColors.borderSubtle,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  Icon(icon, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: AppTextStyles.body1
                                              .copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (isFirst || isLast)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isFirst ? 'Start' : 'End',
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (category != null && category.isNotEmpty)
                                    Text(
                                      category,
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.textTertiary),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              duration,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (totalMinutes != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: Text(
                  'Total: ${_formatMinutes(totalMinutes as num)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Movie List Cards ─────────────────────────────────────────────────────────

class _MovieListMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _MovieListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final movies = (message.extraData?['movies'] as List<dynamic>?) ?? [];
    final theatreName = message.extraData?['theatre_name'] as String?;

    final headerText = theatreName != null && theatreName.isNotEmpty
        ? 'Movies at $theatreName'
        : 'Here are movies playing:';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_creation_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text(headerText,
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...movies.map((m) {
              final movie = m as Map<String, dynamic>;
              return _MovieCard(movie: movie, theatreName: theatreName);
            }),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Map<String, dynamic> movie;
  final String? theatreName;
  const _MovieCard({required this.movie, this.theatreName});

  @override
  Widget build(BuildContext context) {
    final title = movie['title'] as String? ?? 'Movie';
    final genre = movie['genre'] as String? ?? 'Genre';
    final duration = (movie['duration_min'] as num?)?.toInt();
    final language = movie['language'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        final chat = context.read<ChatState>();
        final theatreSuffix = (theatreName != null && theatreName!.isNotEmpty)
            ? ' at $theatreName'
            : '';
        chat.sendMessage('$title$theatreSuffix');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceLight,
              AppColors.surface.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_movies_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '$genre${duration != null ? ' • $duration min' : ''}${language.isNotEmpty ? ' • $language' : ''}',
                    style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Theatre List Cards ───────────────────────────────────────────────────────

class _TheatreListMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _TheatreListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theatres = (message.extraData?['theatres'] as List<dynamic>?) ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text('Nearby theatres',
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...theatres.map((t) {
              final theatre = t as Map<String, dynamic>;
              return _TheatreCard(theatre: theatre);
            }),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TheatreCard extends StatelessWidget {
  final Map<String, dynamic> theatre;
  const _TheatreCard({required this.theatre});

  @override
  Widget build(BuildContext context) {
    final name = theatre['name'] as String? ?? 'Theatre';
    final area = theatre['area'] as String? ?? '';
    final distance = theatre['distance_km'] as num?;

    return GestureDetector(
      onTap: () {
        context.read<ChatState>().sendMessage('movies in $name');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceLight,
              AppColors.surface.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.theaters_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '${area.isNotEmpty ? area : 'Nearby'}${distance != null ? ' • ${distance.toStringAsFixed(2)} km' : ''}',
                    style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Showtime Cards ───────────────────────────────────────────────────────────

class _ShowtimeListMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _ShowtimeListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final showTimes = (message.extraData?['show_times'] as List<dynamic>?) ?? [];
    final movieTitle = message.extraData?['movie_title'] as String?;
    final theatreName = message.extraData?['theatre_name'] as String?;

    final headerText = movieTitle != null && theatreName != null
        ? '$movieTitle at $theatreName'
        : 'Showtimes';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text(headerText,
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: showTimes.map((t) {
                final time = t.toString();
                return GestureDetector(
                  onTap: () {
                    final title = movieTitle ?? '';
                    final theatre = theatreName ?? '';
                    final parts = [title, time, theatre.isNotEmpty ? 'at $theatre' : '']
                        .where((part) => part.trim().isNotEmpty)
                        .join(' ');
                    context.read<ChatState>().sendMessage(parts.trim());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      time,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                );
              }).toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}