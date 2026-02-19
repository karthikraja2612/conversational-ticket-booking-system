import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/seat_model.dart';
import '../../animations/scale_tap_animation.dart';

class SeatGrid extends StatelessWidget {
  final List<SeatModel> seats;
  final Function(int seatId) onSeatTap;
  final bool isEnabled;

  const SeatGrid({
    super.key,
    required this.seats,
    required this.onSeatTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) return const SizedBox.shrink();

    // Build row map
    final Map<int, List<SeatModel>> rowMap = {};
    for (final seat in seats) {
      rowMap.putIfAbsent(seat.rowNumber, () => []).add(seat);
    }
    final sortedRowKeys = rowMap.keys.toList()..sort();
    for (final key in sortedRowKeys) {
      rowMap[key]!.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    }

    final int maxSeatsInRow = sortedRowKeys.isEmpty
        ? 1
        : sortedRowKeys
            .map((k) => rowMap[k]!.length)
            .reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate seat size dynamically to fit within available width
        const double horizontalPadding = 32.0;
        const double rowLabelWidth = 28.0;
        const double seatSpacing = 6.0;
        const double minSeatSize = 28.0;
        const double maxSeatSize = 40.0;

        // Calculate available width for seats
        final double availableWidthForSeats = constraints.maxWidth - 
            horizontalPadding - 
            rowLabelWidth;

        // Calculate ideal seat size that fits in viewport
        final double idealSeatSize = (availableWidthForSeats - 
            (seatSpacing * (maxSeatsInRow - 1))) / maxSeatsInRow;

        // Clamp seat size between min and max
        final double seatSize = idealSeatSize.clamp(minSeatSize, maxSeatSize);

        // Calculate total width needed for seats in a row
        final double seatsRowWidth = (seatSize * maxSeatsInRow) + 
            (seatSpacing * (maxSeatsInRow - 1));

        // Determine if horizontal scrolling is needed
        final bool needsHorizontalScroll = seatsRowWidth > availableWidthForSeats;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              _StageIndicator(
                width: constraints.maxWidth * 0.6),
              const SizedBox(height: 32),
              ...sortedRowKeys.map((rowNum) {
                final rowSeats = rowMap[rowNum]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Row label - fixed position
                      SizedBox(
                        width: rowLabelWidth,
                        child: Text(
                          String.fromCharCode(64 + rowNum),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Seats - scrollable horizontally if needed
                      Expanded(
                        child: needsHorizontalScroll
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rowSeats.map((seat) => Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: seatSpacing / 2),
                                    child: _SeatTile(
                                      seat: seat,
                                      size: seatSize,
                                      onTap: () => onSeatTap(seat.id),
                                      isEnabled: isEnabled,
                                    ),
                                  )).toList(),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: rowSeats.map((seat) => Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: seatSpacing / 2),
                                  child: _SeatTile(
                                    seat: seat,
                                    size: seatSize,
                                    onTap: () => onSeatTap(seat.id),
                                    isEnabled: isEnabled,
                                  ),
                                )).toList(),
                              ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Stage Indicator ───────────────────────────────────────────────────────────

class _StageIndicator extends StatelessWidget {
  final double width;
  const _StageIndicator({required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          height: 5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.primary.withValues(alpha: 0.7),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'S C R E E N',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ── Seat Tile ─────────────────────────────────────────────────────────────────

class _SeatTile extends StatelessWidget {
  final SeatModel seat;
  final double size;
  final VoidCallback onTap;
  final bool isEnabled;

  const _SeatTile({
    required this.seat,
    required this.size,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final bool canTap =
        isEnabled && seat.status == SeatStatus.available;

    Color bg;
    Color borderColor = Colors.transparent;
    Color? shadowColor;
    Widget? icon;

    switch (seat.status) {
      case SeatStatus.locked:
        if (seat.isSelected) {
          bg = AppColors.warning.withValues(alpha: 0.45);
          borderColor = AppColors.warning.withValues(alpha: 0.8);
          shadowColor = AppColors.warning;
          icon = Icon(Icons.lock_rounded,
              size: size * 0.38, color: AppColors.warning);
        } else {
          bg = AppColors.warning.withValues(alpha: 0.2);
          borderColor = AppColors.warning.withValues(alpha: 0.4);
          icon = Icon(Icons.lock_outline,
              size: size * 0.38,
              color: AppColors.warning.withValues(alpha: 0.6));
        }
        break;
      case SeatStatus.booked:
        bg = AppColors.booked;
        borderColor = Colors.white.withValues(alpha: 0.05);
        break;
      case SeatStatus.available:
        if (seat.isSelected) {
          bg = AppColors.primary;
          borderColor = AppColors.primary.withValues(alpha: 0.5);
          shadowColor = AppColors.primary;
          icon = Icon(Icons.check_rounded,
              size: size * 0.42, color: Colors.white);
        } else {
          bg = AppColors.surfaceLight;
          borderColor = Colors.white.withValues(alpha: 0.08);
        }
        break;
    }

    return ScaleTapAnimation(
      onTap: canTap ? onTap : null,
      scaleDown: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: shadowColor != null
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: icon != null ? Center(child: icon) : null,
      ),
    );
  }
}