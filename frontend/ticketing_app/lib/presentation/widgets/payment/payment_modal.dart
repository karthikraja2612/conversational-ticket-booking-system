import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/event_model.dart';
import '../common/gradient_button.dart';
import '../common/glass_card.dart';

class PaymentModal extends StatelessWidget {
  final double amount;
  final int seatCount;
  final VoidCallback onPaymentComplete;
  final bool isProcessing;

  const PaymentModal({
    super.key,
    required this.amount,
    required this.seatCount,
    required this.onPaymentComplete,
    this.isProcessing = false,
  });

  double get _pricePerSeat => seatCount > 0 ? amount / seatCount : 0;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Secure Checkout', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(
                        EventModel.demo.name,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$seatCount seat${seatCount == 1 ? '' : 's'}',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 24),

            // Pricing breakdown
            GlassCard(
              child: Column(
                children: [
                  _buildRow(
                    'Price per seat',
                    '\$${_pricePerSeat.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildRow(
                    'Seats',
                    'x $seatCount',
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  _buildRow(
                    'Total',
                    '\$${amount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 24),

            // QR Code section
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Scan to Pay (Sandbox)', style: AppTextStyles.h3),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data:
                      'PAYMENT_MOCK_${amount}_${DateTime.now().millisecondsSinceEpoch}',
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms).scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.0, 1.0),
                delay: 300.ms,
                duration: 400.ms,
                curve: Curves.easeOut),
            const SizedBox(height: 32),

            GradientButton(
              text: 'Confirm Payment',
              onPressed: isProcessing ? null : onPaymentComplete,
              isLoading: isProcessing,
              icon: Icons.lock_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
              : AppTextStyles.body2,
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.h3.copyWith(color: AppColors.primary)
              : AppTextStyles.body1,
        ),
      ],
    );
  }
}