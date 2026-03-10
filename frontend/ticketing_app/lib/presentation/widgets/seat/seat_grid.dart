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

    String _getAlphabetRow(int rowNum) {
      String result = '';
      int temp = rowNum;
      while (temp > 0) {
        temp--;
        result = String.fromCharCode(65 + (temp % 26)) + result;
        temp ~/= 26;
      }
      return result;
    }

    // Deduplicate by (rowNumber, seatNumber) — keep the "worst" status so
    // booked/locked seats are never hidden by a duplicate available record.
    int _statusPriority(SeatStatus s) {
      switch (s) {
        case SeatStatus.booked: return 3;
        case SeatStatus.locked: return 2;
        case SeatStatus.available: return 1;
      }
    }
    final Map<String, SeatModel> uniqueMap = {};
    for (final seat in seats) {
      final key = '${seat.rowNumber}_${seat.seatNumber}';
      final existing = uniqueMap[key];
      if (existing == null ||
          _statusPriority(seat.status) > _statusPriority(existing.status)) {
        uniqueMap[key] = seat;
      }
    }
    final deduped = uniqueMap.values.toList();

    // Build row map
    final Map<int, List<SeatModel>> rowMap = {};
    for (final seat in deduped) {
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

    // seatsPerRow = highest seat_number value across all rows (matches DB definition)
    int seatsPerRow = 1;
    for (final key in sortedRowKeys) {
      for (final s in rowMap[key]!) {
        if (s.seatNumber > seatsPerRow) seatsPerRow = s.seatNumber;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalPadding = 32.0;
        const double rowLabelWidth = 28.0;
        const double seatSpacing = 6.0;
        const double minSeatSize = 20.0;
        const double maxSeatSize = 40.0;

        // Available width for the seats row (inside Expanded, after scroll padding + row label)
        final double availableWidthForSeats = constraints.maxWidth -
            horizontalPadding -
            rowLabelWidth;

        // Each seat has Padding(horizontal: seatSpacing/2) on BOTH sides,
        // so total spacing = seatSpacing * maxSeatsInRow (not n-1).
        final double idealSeatSize =
            (availableWidthForSeats - (seatSpacing * maxSeatsInRow)) /
                maxSeatsInRow;

        final double seatSize = idealSeatSize.clamp(minSeatSize, maxSeatSize);

        // Build the full seats content width so we know whether to scroll
        final double contentWidth = rowLabelWidth +
            (seatSize * maxSeatsInRow) +
            (seatSpacing * maxSeatsInRow);

        final Widget rowsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _StageIndicator(width: constraints.maxWidth * 0.6)),
            const SizedBox(height: 24),
            ...sortedRowKeys.map((rowNum) {
              final rowSeats = rowMap[rowNum]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row label — alphabetical (A, B, C ...) matching DB row_number
                    SizedBox(
                      width: rowLabelWidth,
                      child: Text(
                        _getAlphabetRow(rowNum),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // All seats in a non-scrollable Row — the outer scroll handles it
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: rowSeats.map((seat) => Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: seatSpacing / 2),
                        child: _SeatTile(
                          seat: seat,
                          size: seatSize,
                          label: '${seat.seatNumber}',
                          onTap: () => onSeatTap(seat.id),
                          isEnabled: isEnabled,
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        );

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(40.0),
          minScale: 0.5,
          maxScale: 3.5,
          panEnabled: true,
          scaleEnabled: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 32,
                ),
                child: rowsColumn,
              ),
            ),
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
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;

  const _SeatTile({
    required this.seat,
    required this.size,
    required this.label,
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
    Widget? child;
    final double fontSize = (size * 0.30).clamp(8.0, 11.0);

    switch (seat.status) {
      case SeatStatus.locked:
        if (seat.isSelected) {
          bg = AppColors.warning.withValues(alpha: 0.45);
          borderColor = AppColors.warning.withValues(alpha: 0.8);
          shadowColor = AppColors.warning;
          child = Icon(Icons.lock_rounded,
              size: size * 0.38, color: AppColors.warning);
        } else {
          bg = AppColors.warning.withValues(alpha: 0.2);
          borderColor = AppColors.warning.withValues(alpha: 0.4);
          child = Icon(Icons.lock_outline,
              size: size * 0.38,
              color: AppColors.warning.withValues(alpha: 0.6));
        }
        break;
      case SeatStatus.booked:
        bg = AppColors.booked;
        borderColor = Colors.white.withValues(alpha: 0.05);
        child = Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        );
        break;
      case SeatStatus.available:
        if (seat.isSelected) {
          bg = AppColors.primary;
          borderColor = AppColors.primary.withValues(alpha: 0.5);
          shadowColor = AppColors.primary;
          child = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded,
                  size: size * 0.32, color: Colors.white),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          );
        } else {
          bg = AppColors.surfaceLight;
          borderColor = Colors.white.withValues(alpha: 0.08);
          child = Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          );
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
        child: child != null ? Center(child: child) : null,
      ),
    );
  }
}