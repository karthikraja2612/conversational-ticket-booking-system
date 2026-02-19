import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/event_model.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/glass_card.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final event = EventModel.demo;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Consumer<AuthState>(
                              builder: (_, auth, __) => Text(
                                auth.userName != null
                                    ? 'Hi, ${auth.userName}!'
                                    : 'TicketBot',
                                style: AppTextStyles.h4.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        Consumer<AuthState>(
                          builder: (_, auth, __) => IconButton(
                            icon: const Icon(Icons.logout_rounded,
                                color: AppColors.textTertiary, size: 22),
                            tooltip: 'Sign Out',
                            onPressed: () async {
                              context.read<BookingState>().reset();
                              context.read<ChatState>().reset();
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.18)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.14),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.confirmation_number_outlined,
                              size: 72,
                              color: AppColors.primary,
                            ),
                          )
                              .animate()
                              .scale(
                                  begin: const Offset(0.5, 0.5),
                                  curve: Curves.elasticOut,
                                  duration: 800.ms)
                              .fadeIn(duration: 400.ms),
                          const SizedBox(height: 28),
                          const Text('TicketBot', style: AppTextStyles.h1)
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 10),
                          Text(
                            'Experience the future of ticketing.\nBook seats instantly with AI assistance.',
                            style: AppTextStyles.body2.copyWith(height: 1.7),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 350.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: const [
                              _FeatureChip(
                                  icon: Icons.lock_clock_rounded,
                                  label: 'Real-time locking'),
                              _FeatureChip(
                                  icon: Icons.bolt_rounded,
                                  label: 'Instant booking'),
                              _FeatureChip(
                                  icon: Icons.qr_code_2_rounded,
                                  label: 'QR Ticket'),
                            ],
                          ).animate().fadeIn(delay: 450.ms, duration: 600.ms),
                          const SizedBox(height: 32),
                          _EventCard(event: event)
                              .animate()
                              .fadeIn(delay: 550.ms, duration: 600.ms)
                              .slideY(begin: 0.3, end: 0),
                          const SizedBox(height: 28),
                          GradientButton(
                            text: 'Start Booking',
                            onPressed: () {
                              context.read<BookingState>().reset();
                              context.read<ChatState>().reset();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ChatScreen()),
                              );
                            },
                            icon: Icons.chat_bubble_outline_rounded,
                            width: double.infinity,
                          )
                              .animate()
                              .fadeIn(delay: 650.ms, duration: 600.ms)
                              .slideY(begin: 0.3, end: 0),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(event.category,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.primary)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Available',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.success)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(event.name, style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  event.description,
                  style: AppTextStyles.body2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label: event.formattedDate,
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label: event.formattedTime,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.location_on_rounded,
                        label: event.venue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '\$${event.price.toStringAsFixed(0)} / seat',
                      style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: AppTextStyles.caption)),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
