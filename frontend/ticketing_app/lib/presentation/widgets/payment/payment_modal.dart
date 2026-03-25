import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/state/event_state.dart';
import '../common/gradient_button.dart';
import '../common/glass_card.dart';

class PaymentModal extends StatefulWidget {
  final double amount;
  final int seatCount;
  final VoidCallback onPaymentComplete;
  final bool isProcessing;
  final String? errorMessage;

  const PaymentModal({
    super.key,
    required this.amount,
    required this.seatCount,
    required this.onPaymentComplete,
    this.isProcessing = false,
    this.errorMessage,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  double get _pricePerSeat =>
      widget.seatCount > 0 ? widget.amount / widget.seatCount : 0;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onPaymentComplete();
    }
  }

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
        child: Form(
          key: _formKey,
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

              // ── Header ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Secure Checkout', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(
                          context.watch<EventState>().primaryEvent?.name ?? '',
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
                      '${widget.seatCount} seat${widget.seatCount == 1 ? '' : 's'}',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 20),

              // ── Test-mode banner ──────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Test Mode · Use card 4242 4242 4242 4242 · Any future exp · Any CVV',
                        style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFF59E0B), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 20),

              // ── Pricing summary ───────────────────────────────────
              GlassCard(
                child: Column(
                  children: [
                    _buildRow('Price per seat',
                        '₹${_pricePerSeat.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildRow('Seats', 'x ${widget.seatCount}'),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    _buildRow('Total',
                        '₹${widget.amount.toStringAsFixed(2)}',
                        isTotal: true),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 24),

              if (widget.errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.errorMessage!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.isProcessing ? null : _submit,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
                const SizedBox(height: 16),
              ],

              // ── Card form ─────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.credit_card_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Card Details', style: AppTextStyles.h3),
                ],
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 14),

              // Card number
              _CardField(
                controller: _cardCtrl,
                label: 'Card Number',
                hint: '4242 4242 4242 4242',
                icon: Icons.credit_card_rounded,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                  LengthLimitingTextInputFormatter(19),
                ],
                keyboardType: TextInputType.number,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  if (digits.length < 16) return 'Enter a valid 16-digit card';
                  return null;
                },
              ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 12),

              // Cardholder name
              _CardField(
                controller: _nameCtrl,
                label: 'Name on Card',
                hint: 'John Doe',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter cardholder name' : null,
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
              const SizedBox(height: 12),

              // Expiry + CVV row
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      controller: _expiryCtrl,
                      label: 'MM / YY',
                      hint: '12 / 26',
                      icon: Icons.calendar_month_rounded,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final digits = (v ?? '')
                            .replaceAll(' ', '')
                            .replaceAll('/', '');
                        if (digits.length < 4) return 'Invalid expiry';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      controller: _cvvCtrl,
                      label: 'CVV',
                      hint: '•••',
                      icon: Icons.lock_outline_rounded,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (v) =>
                          ((v?.length ?? 0) < 3) ? 'Invalid CVV' : null,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
              const SizedBox(height: 28),

              // ── Pay button ────────────────────────────────────────
              GradientButton(
                text: 'Pay ₹${widget.amount.toStringAsFixed(0)}',
                onPressed: widget.isProcessing ? null : _submit,
                isLoading: widget.isProcessing,
                icon: Icons.lock_outline,
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '256-bit SSL encrypted · Sandbox only',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ).animate().fadeIn(delay: 450.ms, duration: 300.ms),
            ],
          ),
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
              ? AppTextStyles.body1
                  .copyWith(fontWeight: FontWeight.w600)
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

// ── Internal field widget ─────────────────────────────────────────────────────

class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

// ── Input formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '').replaceAll(' ', '');
    String str = digits;
    if (digits.length >= 2) {
      str = '${digits.substring(0, 2)} / ${digits.substring(2)}';
    }
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
