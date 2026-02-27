import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../../domain/state/event_state.dart';
import '../widgets/common/animated_loader.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/lock_timer_banner.dart';
import '../widgets/payment/payment_modal.dart';
import '../widgets/seat/seat_grid.dart';
import '../widgets/seat/seat_legend.dart';
import 'ticket_confirmation_screen.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final booking = context.read<BookingState>();
        final chat = context.read<ChatState>();
        booking.fetchSeats().then((_) {
          // After seats are loaded, pre-select recommended seats from chat
          if (mounted && chat.recommendedSeats.isNotEmpty) {
            booking.applyRecommendedSeats(chat.recommendedSeats);
          }
        });
      }
    });
  }

  Future<void> _handleLock() async {
    final booking = context.read<BookingState>();
    final chat = context.read<ChatState>();
    final count = booking.selectedSeats.length;
    if (count == 0) return;

    final ok = await booking.lockSelection();
    if (!mounted) return;

    if (ok) {
      chat.onSeatsLocked(count);
      context.showSnackBar(
          '$count seat${count > 1 ? 's' : ''} locked for 5 minutes!');
    } else {
      context.showSnackBar(
        booking.errorMessage ?? 'Failed to lock seats',
        isError: true,
      );
      booking.clearError();
    }
  }

  Future<void> _handleConfirm() async {
    final booking = context.read<BookingState>();
    final chat = context.read<ChatState>();

    final ok = await booking.confirmBooking();
    if (!mounted) return;

    if (!ok) {
      context.showSnackBar(
        booking.errorMessage ?? 'Booking failed',
        isError: true,
      );
      booking.clearError();
      return;
    }

    chat.onBookingConfirmed();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (modalCtx) => ChangeNotifierProvider.value(
        value: booking,
        child: Consumer<BookingState>(
          builder: (ctx, state, __) {
            final double amount =
                (state.currentBooking?.totalAmount ??
                        (state.lockedCount * AppConstants.seatPrice))
                    .toDouble();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: PaymentModal(
                amount: amount,
                seatCount: state.lockedCount,
                isProcessing: state.isLoading,
                onPaymentComplete: () async {
                  final paid = await state.processPayment();
                  if (!mounted) return;
                  if (paid) {
                    chat.onPaymentDone();
                    // Close payment modal first
                    if (modalCtx.mounted) Navigator.pop(modalCtx);
                    // Navigate directly to ticket/QR screen, replacing this screen
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TicketConfirmationScreen(),
                        ),
                      );
                    }
                  } else {
                    if (!context.mounted) return;
                    context.showSnackBar(
                      state.errorMessage ?? 'Payment failed',
                      isError: true,
                    );
                    state.clearError();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _onLockExpired() {
    if (!mounted) return;
    context.read<ChatState>().onLockExpired();
    context.showSnackBar(
        'Seat lock expired. Please select again.',
        isError: true);
    context.read<BookingState>().fetchSeats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Consumer<EventState>(
          builder: (_, eventState, __) {
            final event = eventState.primaryEvent;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Seats'),
                if (event != null)
                  Text(
                    event.name,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Consumer<EventState>(
              builder: (_, eventState, __) {
                final price = eventState.primaryEvent?.price ?? AppConstants.seatPrice;
                return Center(
                  child: Text(
                    '\u20b9${price.toStringAsFixed(0)}/seat',
                    style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer2<BookingState, EventState>(
        builder: (context, booking, eventState, _) {
          // ── Initial loading ──
          if (booking.isLoading && !booking.hasSeats) {
            return AnimatedLoader(message: 'Loading seats...')
                .animate()
                .fadeIn(duration: 300.ms);
          }

          // ── Error with no seats ──
          if (booking.phase == BookingPhase.error && !booking.hasSeats) {
            return _ErrorView(
              message: booking.errorMessage ?? 'Failed to load seats',
              onRetry: () {
                booking.clearError();
                booking.fetchSeats();
              },
            );
          }

          // ── Empty state ──
          if (!booking.hasSeats) {
            return _EmptyView(onRetry: booking.fetchSeats);
          }

          final bool isLocked = booking.isLocked;
          final int selectedCount =
              isLocked ? booking.lockedCount : booking.selectedSeats.length;
          final double eventPrice =
              eventState.primaryEvent?.price ?? AppConstants.seatPrice;
          final double total = isLocked
              ? (booking.currentBooking?.totalAmount ??
                      (booking.lockedCount * eventPrice))
                  .toDouble()
              : (booking.selectedSeats.length * eventPrice).toDouble();

          return Column(
            children: [
              // ── Timer banner ──
              if (isLocked && booking.lockExpiration != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: LockTimerBanner(
                    expiresAt: booking.lockExpiration!,
                    onExpired: _onLockExpired,
                  ),
                ),

              // ── AI recommended seats banner ──
              Consumer<ChatState>(
                builder: (_, chat, __) {
                  if (chat.recommendedSeats.isEmpty || isLocked) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI recommended: Seats ${chat.recommendedSeats.join(', ')}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Legend ──
              const SeatLegend(),

              // ── Seat grid ──
              Expanded(
                child: SeatGrid(
                  seats: booking.seats,
                  onSeatTap: booking.toggleSeat,
                  isEnabled: !isLocked && !booking.isLoading,
                ),
              ),

              // ── Bottom action bar ──
              _BottomBar(
                selectedCount: selectedCount,
                total: total,
                isLocked: isLocked,
                isLoading: booking.isLoading,
                onAction: isLocked ? _handleConfirm : _handleLock,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int selectedCount;
  final double total;
  final bool isLocked;
  final bool isLoading;
  final VoidCallback? onAction;

  const _BottomBar({
    required this.selectedCount,
    required this.total,
    required this.isLocked,
    required this.isLoading,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
            top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLocked) ...[
                          const Icon(Icons.lock_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '$selectedCount seat${selectedCount > 1 ? 's' : ''} '
                          '${isLocked ? "locked" : "selected"}',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            GradientButton(
              text: selectedCount == 0
                  ? 'Select seats to continue'
                  : isLocked
                      ? 'Confirm & Pay  →'
                      : 'Lock $selectedCount Seat${selectedCount > 1 ? 's' : ''}',
              icon: isLocked
                  ? Icons.payment_rounded
                  : Icons.lock_outline_rounded,
              gradient: isLocked ? AppColors.successGradient : null,
              isLoading: isLoading,
              onPressed: selectedCount == 0 ? null : onAction,
              width: double.infinity,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text('Connection Error',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style: AppTextStyles.body2,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_seat_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('No Seats Found',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'No seats available for this event.\nEnsure the backend is running.',
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}