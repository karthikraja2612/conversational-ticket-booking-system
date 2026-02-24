import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../../domain/state/event_state.dart';
import '../widgets/common/animated_loader.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import 'home_screen.dart';

class TicketConfirmationScreen extends StatelessWidget {
  const TicketConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<BookingState>(
        builder: (context, bookingState, _) {
          final booking = bookingState.currentBooking;

          if (booking == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('No booking data found', style: AppTextStyles.h3),
                ],
              ),
            );
          }

          final qrData =
              'TICKETBOT|BOOKING:${booking.id}|EVENT:${booking.eventId}|USER:${booking.userId}|SEATS:${booking.seatIds.join(",")}|AMOUNT:${booking.totalAmount}|EVENT:${context.read<EventState>().primaryEvent?.name ?? ''}';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SuccessAnimation(size: 100)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 24),
                Text(
                  'Booking Confirmed!',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Your tickets are ready. Show QR at the entrance.',
                  style: AppTextStyles.body2,
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 500.ms),
                const SizedBox(height: 32),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Booking Details', style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRow('Event', context.read<EventState>().primaryEvent?.name ?? ''),
                      const SizedBox(height: 10),
                      _buildRow('Date', context.read<EventState>().primaryEvent?.formattedDate ?? ''),
                      const SizedBox(height: 10),
                      _buildRow('Booking ID', '#${booking.id}'),
                      const SizedBox(height: 10),
                      _buildRow(
                          'Seats',
                          booking.seatIds
                              .map((id) => 'Seat $id')
                              .join(', ')),
                      const SizedBox(height: 10),
                      _buildRow(
                          'Total Seats', '${booking.seatIds.length}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white12),
                      ),
                      _buildRow(
                        'Total Paid',
                        '₹${booking.totalAmount.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                      const SizedBox(height: 10),
                      _buildRow('Status', 'CONFIRMED ✓',
                          isTotal: true, valueColor: AppColors.success),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Your Ticket QR', style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Show this QR at the entrance',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
                GradientButton(
                  text: 'Done — Go Home',
                  icon: Icons.home_rounded,
                  width: double.infinity,
                  onPressed: () {
                    bookingState.reset();
                    context.read<ChatState>().reset();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                )
                    .animate()
                    .fadeIn(delay: 750.ms, duration: 500.ms),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.body1
                  .copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body2,
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: isTotal
                ? AppTextStyles.h3.copyWith(
                    color: valueColor ?? AppColors.primary,
                  )
                : AppTextStyles.body1,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}