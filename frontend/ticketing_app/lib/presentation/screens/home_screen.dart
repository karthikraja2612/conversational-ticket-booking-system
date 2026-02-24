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
import '../../domain/state/event_state.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/glass_card.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _startBooking(BuildContext context, EventModel event) {
    context.read<BookingState>().reset();
    context.read<ChatState>().reset();
    final auth = context.read<AuthState>();
    context.read<BookingState>().setAuthToken(auth.token);
    context.read<BookingState>().setCurrentUserId(auth.userId);
    context.read<ChatState>().setAuthToken(auth.token);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Consumer<AuthState>(
                            builder: (_, auth, __) => Text(
                              auth.displayName.isNotEmpty
                                  ? 'Hi, ${auth.displayName}!'
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
                ),
                // ── Body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.confirmation_number_rounded,
                            color: AppColors.primary,
                            size: 56,
                          ),
                        ).animate().fadeIn(duration: 400.ms),
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

                        // ── Events from DB ──
                        Consumer<EventState>(
                          builder: (context, eventState, _) {
                            if (eventState.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            if (eventState.loadState == EventLoadState.error ||
                                !eventState.hasEvents) {
                              // Fallback: show retry card
                              return GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.wifi_off_rounded,
                                          color: AppColors.error, size: 36),
                                      const SizedBox(height: 12),
                                      Text(
                                        eventState.errorMessage ??
                                            'Could not load events.',
                                        style: AppTextStyles.body2,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      GradientButton(
                                        text: 'Retry',
                                        icon: Icons.refresh_rounded,
                                        onPressed: eventState.fetchEvents,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Show all events from DB
                            return Column(
                              children: eventState.events
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final event = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom: index <
                                              eventState.events.length - 1
                                          ? 16
                                          : 0),
                                  child: _EventCard(
                                    event: event,
                                    onBook: () =>
                                        _startBooking(context, event),
                                  )
                                      .animate()
                                      .fadeIn(
                                          delay: Duration(
                                              milliseconds: 550 + index * 100),
                                          duration: 600.ms)
                                      .slideY(begin: 0.3, end: 0),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onBook;

  const _EventCard({required this.event, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LIVE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '\u20b9${event.price.toStringAsFixed(0)}/seat',
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(event.name, style: AppTextStyles.h3),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                event.description,
                style: AppTextStyles.body2
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (event.venue.isNotEmpty) ...[
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.venue,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  event.formattedDate,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Book Now',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: onBook,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}