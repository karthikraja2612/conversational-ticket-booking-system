import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LockTimerBanner extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;

  const LockTimerBanner({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });

  @override
  State<LockTimerBanner> createState() => _LockTimerBannerState();
}

class _LockTimerBannerState extends State<LockTimerBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);
    if (diff.isNegative || diff == Duration.zero) {
      _timer?.cancel();
      setState(() => _remaining = Duration.zero);
      widget.onExpired();
    } else {
      setState(() => _remaining = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color get _timerColor {
    if (_remaining.inSeconds <= 60) return AppColors.error;
    if (_remaining.inSeconds <= 120) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _timerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _timerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 16, color: _timerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seats locked — complete payment before timer expires',
              style: AppTextStyles.caption.copyWith(color: _timerColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_remaining),
            style: AppTextStyles.h4.copyWith(
              color: _timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}