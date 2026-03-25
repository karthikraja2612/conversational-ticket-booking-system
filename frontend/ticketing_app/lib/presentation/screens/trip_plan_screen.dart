import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/trip_plan_model.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/state/auth_state.dart';
import '../widgets/common/animated_loader.dart';

class TripPlanScreen extends StatefulWidget {
  final int bookingId;

  const TripPlanScreen({super.key, required this.bookingId});

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

class _TripPlanScreenState extends State<TripPlanScreen> {
  static final Map<String, TripPlan> _cache = {};
  final TripRepository _repository = TripRepository();

  TripPlan? _plan;
  bool _isLoading = false;
  String? _errorMessage;
  String _intent = 'fun';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthState>();
      _repository.setAuthToken(auth.token);
      _loadPlan();
    });
  }

  Future<void> _loadPlan({bool refresh = false}) async {
    final cacheKey = '${widget.bookingId}|$_intent';
    if (!refresh && _cache.containsKey(cacheKey)) {
      setState(() {
        _plan = _cache[cacheKey];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plan = await _repository.planFromBooking(
        widget.bookingId,
        intent: _intent,
        refresh: refresh,
      );
      _cache[cacheKey] = plan;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  IconData _iconForType(String type) {
    final key = type.toLowerCase();
    if (key == 'event') return Icons.event_rounded;
    if (key == 'food') return Icons.restaurant_rounded;
    if (key == 'relax') return Icons.park_rounded;
    if (key == 'fun') return Icons.local_activity_rounded;
    if (key == 'explore') return Icons.museum_rounded;
    return Icons.place_rounded;
  }

  List<TripPlanItem> _dedupePlan(List<TripPlanItem> items) {
    final seen = <String>{};
    final result = <TripPlanItem>[];
    for (final item in items) {
      final key = '${item.place}|${item.type}'.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Plan'),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildIntentSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _plan?.eventName ?? 'Your Event';
    final time = _plan?.eventTime ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  time.isNotEmpty ? 'Event time: $time' : 'Event time pending',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _isLoading ? null : () => _loadPlan(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentSelector() {
    final intents = ['fun', 'relax', 'food', 'explore'];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: intents.map((intent) {
        final isSelected = _intent == intent;
        return ChoiceChip(
          label: Text(intent.toUpperCase()),
          selected: isSelected,
          onSelected: (selected) {
            if (_isLoading) return;
            if (!selected) return;
            setState(() => _intent = intent);
            _loadPlan();
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.25),
          backgroundColor: AppColors.surfaceLight,
          labelStyle: AppTextStyles.caption.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.borderSubtle,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AnimatedLoader());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: AppTextStyles.body1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _loadPlan(refresh: true),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final plan = _dedupePlan(_plan?.plan ?? []);
    if (plan.isEmpty) {
      return Center(
        child: Text(
          'No plan available yet.',
          style: AppTextStyles.body1,
        ),
      );
    }

    final hasOnlyEvent =
        plan.length == 1 && plan.first.type.toLowerCase() == 'event';

    return ListView.builder(
      itemCount: plan.length + (hasOnlyEvent ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasOnlyEvent && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Not enough time for additional stops.',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        final displayIndex = hasOnlyEvent ? index - 1 : index;
        final item = plan[displayIndex];
        final isFirst = displayIndex == 0;
        final isLast = displayIndex == plan.length - 1;
        final distanceText = item.distanceKm != null
            ? '${item.distanceKm!.toStringAsFixed(1)} km'
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Column(
                  children: [
                    if (!isFirst)
                      Container(
                        width: 2,
                        height: 10,
                        color: AppColors.borderSubtle,
                      ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 52,
                        color: AppColors.borderSubtle,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconForType(item.type),
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.place,
                              style: AppTextStyles.body1
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.timeRange,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (distanceText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            distanceText,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ),
            ],
          ),
        );
      },
    );
  }
}
