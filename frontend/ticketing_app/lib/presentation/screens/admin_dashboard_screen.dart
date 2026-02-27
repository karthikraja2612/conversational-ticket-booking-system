import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/admin_state.dart';
import 'admin_venues_screen.dart';
import 'admin_events_screen.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load venues and events immediately on dashboard open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminState>();
      admin.loadVenues();
      admin.loadEvents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to sign out of the admin panel?',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              context.read<AdminState>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                (route) => false,
              );
            },
            child: Text('Logout',
                style: AppTextStyles.body2.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -80,
            right: -80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.15),
                      AppColors.warning.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar area ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: AppColors.warning, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admin Panel',
                              style: AppTextStyles.h3),
                          Text('TicketBot Management',
                              style: AppTextStyles.caption),
                        ],
                      ),
                      const Spacer(),
                      // Stats summary
                      Consumer<AdminState>(
                        builder: (_, admin, __) => Row(
                          children: [
                            _headerStat(
                                admin.venues.length.toString(), 'Venues'),
                            const SizedBox(width: 16),
                            _headerStat(
                                admin.events.length.toString(), 'Events'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.textSecondary, size: 20),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),

                // ── Stats row ────────────────────────────────────────────
                Consumer<AdminState>(
                  builder: (_, admin, __) {
                    final published =
                        admin.events.where((e) => e.isPublished).length;
                    final draft = admin.events.length - published;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                              child: _summaryCard(
                                  'Published', published.toString(),
                                  AppColors.success,
                                  Icons.public_rounded)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _summaryCard(
                                  'Drafts', draft.toString(),
                                  AppColors.textTertiary,
                                  Icons.drafts_outlined)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _summaryCard(
                                  'Venues',
                                  admin.venues.length.toString(),
                                  AppColors.primary,
                                  Icons.stadium_rounded)),
                        ],
                      ),
                    );
                  },
                ),

                // ── Tab bar ──────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: AppTextStyles.h4,
                    unselectedLabelStyle: AppTextStyles.body2,
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textTertiary,
                    indicator: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.stadium_rounded, size: 18),
                          text: 'Venues'),
                      Tab(
                          icon: Icon(
                              Icons.confirmation_number_rounded,
                              size: 18),
                          text: 'Events'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tab views ────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      AdminVenuesScreen(),
                      AdminEventsScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTextStyles.h4.copyWith(color: color, fontSize: 18)),
              Text(label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
