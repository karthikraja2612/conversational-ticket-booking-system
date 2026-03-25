import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../data/services/api_service.dart';
import '../../domain/state/auth_state.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _apiService = ApiService();
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookings());
  }

  Future<void> _loadBookings() async {
    final token = context.read<AuthState>().token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _apiService.setAuthToken(token);

    try {
      final data = await _apiService.fetchMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'payment_failed':
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('My Bookings'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadBookings)
              : _bookings.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) {
                          final b = _bookings[i];
                          return _BookingCard(
                            booking: b,
                            dateLabel: _formatDate(b.createdAt),
                            statusColor: _statusColor(b.status),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final String dateLabel;
  final Color statusColor;

  const _BookingCard({
    required this.booking,
    required this.dateLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final seatCount = booking.seatIds.length;
    final eventName = booking.eventName ?? 'Event #${booking.eventId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.confirmation_number_rounded,
                    size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eventName,
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(dateLabel,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.status.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Seats: $seatCount',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary)),
              ),
              Text(
                '₹${booking.totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.body1
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                color: AppColors.textTertiary, size: 36),
          ),
          const SizedBox(height: 12),
          const Text('No bookings yet', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text('Your bookings will show up here.',
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 34),
          ),
          const SizedBox(height: 12),
          const Text('Could not load bookings', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
