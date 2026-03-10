import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

extension BuildContextExtensions on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isSmallScreen => screenWidth < 360;
  bool get isTablet => screenWidth >= 600;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.error : AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.success.withValues(alpha: 0.3),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

extension StringExtensions on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DateTimeExtensions on DateTime {
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return formattedTime;
  }
}
