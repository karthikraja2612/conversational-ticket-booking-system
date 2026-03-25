import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/event_model.dart';
import '../../data/services/api_service.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/event_state.dart';
import '../widgets/common/gradient_button.dart';
import 'seat_selection_screen.dart';

class MovieShowtimeSelectionScreen extends StatefulWidget {
  final EventModel event;
  const MovieShowtimeSelectionScreen({super.key, required this.event});

  @override
  State<MovieShowtimeSelectionScreen> createState() =>
      _MovieShowtimeSelectionScreenState();
}

class _MovieShowtimeSelectionScreenState
    extends State<MovieShowtimeSelectionScreen> {
  String? _selectedDate;
  String? _selectedTime;
  bool _loading = false;

  EventModel get _event => widget.event;

  List<String> get _availableDates {
    if (_event.availableDates.isNotEmpty) return _event.availableDates;
    return _event.showTimesByDate.keys.toList()..sort();
  }

  List<String> _timesForSelectedDate() {
    if (_selectedDate == null) return const [];
    return _event.getShowTimesForDate(_selectedDate!);
  }

  Future<void> _confirmSelection() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a date and time.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _loading = true);
    final api = ApiService();

    try {
      final showDate = DateTime.tryParse(_selectedDate!);
      if (showDate == null) {
        throw Exception('Invalid show date');
      }

      final response = await api.createMovieEventInstance(
        configId: _event.id,
        showDate: showDate,
        showTime: _selectedTime!,
      );

      final eventId = (response['event_id'] as num?)?.toInt();
      if (eventId == null) {
        throw Exception('Invalid event response');
      }

      final eventDateRaw = response['event_date'] as String?;
      final eventDate = eventDateRaw != null
          ? DateTime.tryParse(eventDateRaw) ?? DateTime.now()
          : DateTime.now();

      final eventInstance = EventModel(
        id: eventId,
        name: response['name'] as String? ?? _event.name,
        description: '',
        venue: response['theatre_name'] as String? ?? _event.venue,
        venueId: (response['venue_id'] as num?)?.toInt() ?? _event.venueId,
        theatreName: response['theatre_name'] as String? ?? _event.theatreName,
        theatreLocation:
            response['theatre_location'] as String? ?? _event.theatreLocation,
        date: eventDate,
        price: (response['base_price'] as num?)?.toDouble() ?? _event.price,
        eventType: (response['event_type'] as String? ?? 'movie').toLowerCase(),
      );

      final auth = context.read<AuthState>();
      final booking = context.read<BookingState>();
      booking.reset();
      booking.setAuthToken(auth.token);
      booking.setCurrentUserId(auth.userId);
      booking.setCurrentEventId(eventId);

      context.read<EventState>().setSelectedEvent(eventInstance);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeatSelectionScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _availableDates;
    final times = _timesForSelectedDate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Select Showtime'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_event.name, style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text(
              _event.theatreName ?? _event.venue,
              style: AppTextStyles.body2,
            ),
            const SizedBox(height: 20),
            Text('Choose a date', style: AppTextStyles.body1),
            const SizedBox(height: 10),
            if (dates.isEmpty)
              Text('No dates available', style: AppTextStyles.caption)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in dates)
                    ChoiceChip(
                      label: Text(d),
                      selected: _selectedDate == d,
                      onSelected: (_) {
                        setState(() {
                          _selectedDate = d;
                          _selectedTime = null;
                        });
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: AppTextStyles.caption.copyWith(
                        color: _selectedDate == d
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.surfaceLight,
                      side: BorderSide(
                        color: _selectedDate == d
                            ? AppColors.primary
                            : AppColors.borderSubtle,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 18),
            Text('Choose a time', style: AppTextStyles.body1),
            const SizedBox(height: 10),
            if (_selectedDate == null)
              Text('Select a date first', style: AppTextStyles.caption)
            else if (times.isEmpty)
              Text('No showtimes available', style: AppTextStyles.caption)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in times)
                    ChoiceChip(
                      label: Text(t),
                      selected: _selectedTime == t,
                      onSelected: (_) => setState(() => _selectedTime = t),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: AppTextStyles.caption.copyWith(
                        color: _selectedTime == t
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.surfaceLight,
                      side: BorderSide(
                        color: _selectedTime == t
                            ? AppColors.primary
                            : AppColors.borderSubtle,
                      ),
                    ),
                ],
              ),
            const Spacer(),
            GradientButton(
              text: _loading ? 'Loading...' : 'Confirm Showtime',
              icon: Icons.event_seat_rounded,
              width: double.infinity,
              onPressed: _loading ? null : _confirmSelection,
            ),
          ],
        ),
      ),
    );
  }
}
