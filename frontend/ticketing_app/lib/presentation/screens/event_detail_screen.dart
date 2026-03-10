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
import 'seat_selection_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar ──
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  title: const Text('Event Details',
                      style: AppTextStyles.h4),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero card ──
                        _HeroCard(event: event)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),
                        const SizedBox(height: 24),

                        // ── Info grid ──
                        _InfoGrid(event: event)
                            .animate()
                            .fadeIn(delay: 150.ms, duration: 400.ms),
                        const SizedBox(height: 24),

                        // ── Description ──
                        if (event.description.isNotEmpty) ...[
                          _DescriptionCard(event: event)
                              .animate()
                              .fadeIn(delay: 250.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],

                        // ── Seat count picker ──
                        _SeatCountCard()
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 400.ms),
                        const SizedBox(height: 32),

                        // ── CTA ──
                        _BookButton(event: event)
                            .animate()
                            .fadeIn(delay: 450.ms, duration: 400.ms),
                        const SizedBox(height: 16),
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

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final EventModel event;
  const _HeroCard({required this.event});

  static const _palettes = [
    [Color(0xFF4F8CFF), Color(0xFF3A6FD8)],
    [Color(0xFF9B59F5), Color(0xFF7C3AED)],
    [Color(0xFF22C55E), Color(0xFF16A34A)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
  ];

  List<Color> get _gradient => _palettes[event.id % _palettes.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _gradient[0].withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('UPCOMING EVENT',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 16),
          Text(event.name,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.venue.isNotEmpty ? event.venue : 'Venue TBA',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(event.formattedDate,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info Grid ─────────────────────────────────────────────────────────────────

class _InfoGrid extends StatelessWidget {
  final EventModel event;
  const _InfoGrid({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.confirmation_number_rounded,
            label: 'Price',
            value: '₹${event.price.toStringAsFixed(0)}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoTile(
            icon: Icons.access_time_rounded,
            label: 'Duration',
            value: '~2 hrs',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoTile(
            icon: Icons.event_seat_rounded,
            label: 'Seats',
            value: 'Available',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.h4.copyWith(color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Description Card ──────────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final EventModel event;
  const _DescriptionCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('About This Event', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 12),
          Text(event.description,
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.textSecondary, height: 1.7)),
        ],
      ),
    );
  }
}

// ── Seat Count Card (stepper) ─────────────────────────────────────────────────

class _SeatCountCard extends StatefulWidget {
  const _SeatCountCard();

  @override
  State<_SeatCountCard> createState() => _SeatCountCardState();
}

class _SeatCountCardState extends State<_SeatCountCard> {
  int _count = 1;
  static const int _max = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Sync with chat recommendation if available
      final qty = context.read<ChatState>().pendingQuantity;
      if (qty != null && qty >= 1 && qty <= _max) {
        setState(() => _count = qty);
        context.read<BookingState>().setDesiredSeatCount(_count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventPrice =
        context.read<EventState>().primaryEvent?.price ?? 500.0;
    final total = eventPrice * _count;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Number of Tickets', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                enabled: _count > 1,
                onTap: () {
                  setState(() => _count--);
                  context.read<BookingState>().setDesiredSeatCount(_count);
                },
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text('$_count',
                      style: AppTextStyles.h1
                          .copyWith(color: AppColors.primary)),
                  Text(
                    _count == 1 ? 'ticket' : 'tickets',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              _StepBtn(
                icon: Icons.add_rounded,
                enabled: _count < _max,
                onTap: () {
                  setState(() => _count++);
                  context.read<BookingState>().setDesiredSeatCount(_count);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Estimated total: ₹${total.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'On the next screen, select your preferred seats. '
            'We\'ll pre-highlight your AI-recommended spots.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

// ── Book Button ───────────────────────────────────────────────────────────────

class _BookButton extends StatelessWidget {
  final EventModel event;
  const _BookButton({required this.event});

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      text: 'Choose My Seats',
      icon: Icons.event_seat_rounded,
      width: double.infinity,
      onPressed: () {
        final auth = context.read<AuthState>();
        final booking = context.read<BookingState>();
        final eventState = context.read<EventState>();

        booking.reset();
        booking.setAuthToken(auth.token);
        booking.setCurrentUserId(auth.userId);
        booking.setCurrentEventId(event.id);
        eventState.setSelectedEvent(event);

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SeatSelectionScreen(),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(
                      begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
    );
  }
}
