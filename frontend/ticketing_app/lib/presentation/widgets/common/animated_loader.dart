import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Full-screen loading overlay with animated dots and optional message.
class AnimatedLoader extends StatelessWidget {
  final String message;
  const AnimatedLoader({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingRing(),
          const SizedBox(height: 24),
          Text(message, style: AppTextStyles.body2)
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(delay: 1200.ms, duration: 600.ms),
        ],
      ),
    );
  }
}

class _PulsingRing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3), width: 2),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.1, 1.1),
                  duration: 1200.ms,
                  curve: Curves.easeInOut)
              .fadeOut(duration: 1200.ms),

          // Inner circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
            ),
          ),

          // Icon
          const Icon(Icons.bolt_rounded,
              size: 26, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Animated success checkmark for payment/booking confirmations.
class SuccessAnimation extends StatelessWidget {
  final double size;
  const SuccessAnimation({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.0, 0.0),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.elasticOut),

          // Border ring
          Container(
            width: size - 8,
            height: size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success, width: 2.5),
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.0, 0.0),
                  end: const Offset(1.0, 1.0),
                  delay: 100.ms,
                  duration: 500.ms,
                  curve: Curves.elasticOut),

          // Checkmark
          Icon(Icons.check_rounded,
              size: size * 0.45, color: AppColors.success)
              .animate()
              .scale(
                  begin: const Offset(0.0, 0.0),
                  end: const Offset(1.0, 1.0),
                  delay: 200.ms,
                  duration: 500.ms,
                  curve: Curves.elasticOut)
              .fadeIn(delay: 200.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

/// Compact inline loading indicator for buttons/states.
class InlineLoader extends StatelessWidget {
  final Color color;
  const InlineLoader({super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: 2.5,
      ),
    );
  }
}
