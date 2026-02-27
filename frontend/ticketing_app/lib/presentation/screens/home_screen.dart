import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../data/models/event_model.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../../domain/state/event_state.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = ['All', 'Music', 'Sports', 'Theater', 'Comedy'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EventState>().fetchEvents();
      }
    });
  }

  void _goToChat(BuildContext context) {
    context.read<BookingState>().reset();
    context.read<ChatState>().reset();
    final auth = context.read<AuthState>();
    context.read<BookingState>().setAuthToken(auth.token);
    context.read<BookingState>().setCurrentUserId(auth.userId);
    context.read<ChatState>().setAuthToken(auth.token);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ChatScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _goToChatWithEvent(BuildContext context, EventModel event) {
    context.read<BookingState>().reset();
    context.read<ChatState>().reset();
    final auth = context.read<AuthState>();
    context.read<BookingState>().setAuthToken(auth.token);
    context.read<BookingState>().setCurrentUserId(auth.userId);
    context.read<BookingState>().setCurrentEventId(event.id);
    context.read<EventState>().setSelectedEvent(event);
    context.read<ChatState>().setAuthToken(auth.token);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: Stack(
        children: [
          // ── Background ambient glows ──
          Positioned(
            top: -180,
            right: -180,
            child: _AmbientGlow(color: const Color(0xFF4F8CFF), size: 460, opacity: 0.18),
          ),
          Positioned(
            top: 220,
            left: -140,
            child: _AmbientGlow(color: const Color(0xFF9B59F5), size: 320, opacity: 0.12),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _AmbientGlow(color: const Color(0xFF22C55E), size: 260, opacity: 0.07),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ──
                _TopBar(onLogout: () async {
                  context.read<BookingState>().reset();
                  context.read<ChatState>().reset();
                  final auth = context.read<AuthState>();
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }),

                // ── Scrollable body ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroSection(onGetStarted: () => _goToChat(context)),
                        const SizedBox(height: 28),
                        const _StatsRow(),
                        const SizedBox(height: 32),
                        _CategoryChips(
                          categories: _categories,
                          selected: _selectedCategory,
                          onSelect: (i) => setState(() => _selectedCategory = i),
                        ),
                        const SizedBox(height: 20),
                        _UpcomingEventsSection(
                          onBookEvent: (e) => _goToChatWithEvent(context, e),
                        ),
                        const SizedBox(height: 32),
                        const _FeaturesSection(),
                        const SizedBox(height: 32),
                        _AIChatBanner(onTap: () => _goToChat(context)),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating Chat Button ──
          Positioned(
            bottom: 28,
            right: 20,
            child: _FloatingChatBtn(onTap: () => _goToChat(context)),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _TopBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F8CFF).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TicketBot',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Consumer<AuthState>(
                builder: (_, auth, __) => _AvatarButton(
                  name: auth.displayName,
                  onLogout: onLogout,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _AvatarButton extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  const _AvatarButton({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProfileMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name.isNotEmpty ? name.split(' ').first : 'Profile',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12151E).withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            '✓  Verified Member',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onLogout();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

final _gradientPaint = Paint()
  ..shader = const LinearGradient(
    colors: [Color(0xFF4F8CFF), Color(0xFFB06EF5)],
  ).createShader(const Rect.fromLTWH(0, 0, 280, 50));

class _HeroSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Consumer<AuthState>(
        builder: (_, auth, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F8CFF).withValues(alpha: 0.18),
                    const Color(0xFF9B59F5).withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4F8CFF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👋', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    auth.displayName.isNotEmpty
                        ? 'Welcome back, ${auth.displayName.split(' ').first}!'
                        : 'Welcome back!',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4F8CFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: -0.2, end: 0),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
                children: [
                  const TextSpan(text: 'Find & Book\nYour '),
                  TextSpan(
                    text: 'Perfect\nSeat',
                    style: TextStyle(
                      foreground: _gradientPaint,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 14),
            Text(
              'AI-powered chat booking · Real-time seat locking\nInstant QR tickets delivered to you',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.65,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 500.ms),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onGetStarted,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F8CFF).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Book with AI',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 350.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Consumer<EventState>(
        builder: (_, state, __) {
          final count = state.events.length;
          return Row(
            children: [
              _StatPill(
                icon: Icons.event_available_rounded,
                label: '$count Events',
                color: const Color(0xFF4F8CFF),
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.bolt_rounded,
                label: 'AI Powered',
                color: const Color(0xFF9B59F5),
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.verified_rounded,
                label: 'Secure',
                color: const Color(0xFF22C55E),
              ),
            ],
          );
        },
      ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final int selected;
  final void Function(int) onSelect;
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final isSelected = i == selected;
              return Padding(
                padding: EdgeInsets.only(
                    right: i < categories.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4F8CFF)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      categories[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }
}

// ── Upcoming Events Section ───────────────────────────────────────────────────

class _UpcomingEventsSection extends StatelessWidget {
  final void Function(EventModel) onBookEvent;
  const _UpcomingEventsSection({required this.onBookEvent});

  @override
  Widget build(BuildContext context) {
    return Consumer<EventState>(
      builder: (_, eventState, __) {
        if (eventState.isLoading && !eventState.hasEvents) {
          return _EventsLoadingPlaceholder();
        }
        if (eventState.loadState == EventLoadState.error && !eventState.hasEvents) {
          return _EventsErrorState(message: eventState.errorMessage ?? 'Failed to load events');
        }
        if (!eventState.hasEvents) {
          return _EventsEmptyState();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: List.generate(eventState.events.length, (i) {
              final event = eventState.events[i];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i < eventState.events.length - 1 ? 16 : 0),
                child: _EventCard(
                  event: event,
                  colorIndex: i,
                  onTap: () => onBookEvent(event),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 600 + i * 100),
                      duration: 400.ms,
                    )
                    .slideY(begin: 0.1, end: 0),
              );
            }),
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final int colorIndex;
  final VoidCallback onTap;
  const _EventCard({
    required this.event,
    required this.colorIndex,
    required this.onTap,
  });

  static const _palettes = [
    [Color(0xFF4F8CFF), Color(0xFF3A6FD8), Color(0xFF1A2744)],
    [Color(0xFF9B59F5), Color(0xFF7C3AED), Color(0xFF27104A)],
    [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0A2D1A)],
    [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF3D2800)],
    [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF3D0A0A)],
    [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF072A35)],
  ];

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const _typeLabels = ['Music', 'Sports', 'Theater', 'Comedy', 'Festival', 'Dance'];
  static const _typeIcons = [
    Icons.music_note_rounded, Icons.sports_soccer_rounded,
    Icons.theater_comedy_rounded, Icons.sentiment_very_satisfied_rounded,
    Icons.celebration_rounded, Icons.airline_seat_recline_extra_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final p = _palettes[colorIndex % _palettes.length];
    final d = event.date;
    final month = _monthNames[d.month - 1];
    final icon = _typeIcons[colorIndex % _typeIcons.length];
    final label = _typeLabels[colorIndex % _typeLabels.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p[0].withValues(alpha: 0.22)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p[2], const Color(0xFF0D1117)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Deco circles
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p[0].withValues(alpha: 0.12),
                  ),
                ),
              ),
              // Icon box
              Positioned(
                right: 16, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          p[0].withValues(alpha: 0.25),
                          p[1].withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p[0].withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, color: p[0], size: 30),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p[0].withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: p[0].withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: p[0],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 6, color: Color(0xFF22C55E)),
                              SizedBox(width: 4),
                              Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                size: 12, color: p[0]),
                            const SizedBox(width: 4),
                            Text(
                              '${d.day} $month ${d.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '₹${event.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p[0],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [p[0], p[1]],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: p[0].withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(3, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 16 : 0),
            child: Container(
              height: 148,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(22),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(
                  duration: 1400.ms,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
          );
        }),
      ),
    );
  }
}

class _EventsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F8CFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_rounded,
                  size: 36, color: Color(0xFF4F8CFF)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No events yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Events will appear here once published.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsErrorState extends StatelessWidget {
  final String message;
  const _EventsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 36, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load events',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.read<EventState>().fetchEvents(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F8CFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4F8CFF).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F8CFF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Features Section ──────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    const features = [
      _FeatureData(
        icon: Icons.smart_toy_rounded,
        title: 'AI Chat Booking',
        desc: 'Natural language seat selection',
        color: Color(0xFF4F8CFF),
      ),
      _FeatureData(
        icon: Icons.lock_clock_rounded,
        title: '5-min Seat Hold',
        desc: 'Seats reserved while you pay',
        color: Color(0xFF9B59F5),
      ),
      _FeatureData(
        icon: Icons.qr_code_2_rounded,
        title: 'Instant QR Ticket',
        desc: 'Download e-ticket right away',
        color: Color(0xFF22C55E),
      ),
      _FeatureData(
        icon: Icons.shield_rounded,
        title: 'Secure Payments',
        desc: 'End-to-end encrypted transactions',
        color: Color(0xFFF59E0B),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why TicketBot?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: features.length,
            itemBuilder: (_, i) => _FeatureCard(data: features[i]),
          )
              .animate()
              .fadeIn(delay: 800.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  const _FeatureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, size: 22, color: data.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.desc,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ambient Glow Widget ───────────────────────────────────────────────────────

class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _AmbientGlow({
    required this.color,
    required this.size,
    this.opacity = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI Chat Banner ────────────────────────────────────────────────────────────

class _AIChatBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AIChatBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF1A1340)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF4F8CFF).withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8CFF).withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F8CFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🤖  AI Assistant',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4F8CFF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chat to Book\nSeats Instantly',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Just say what you want and our AI\nwill handle the rest.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F8CFF).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start Chatting',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F8CFF).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: 1000.ms, duration: 500.ms)
          .slideY(begin: 0.2, end: 0),
    );
  }
}

// ── Floating Chat Button ──────────────────────────────────────────────────────

class _FloatingChatBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingChatBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F8CFF), Color(0xFF9B59F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F8CFF).withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
            Icons.smart_toy_rounded, color: Colors.white, size: 26),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0, end: 1.06,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}
