import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/chat_message_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == MessageSender.bot;

    // ── Structured message types (always bot, no bubble wrapper) ──────────
    if (isBot && message.messageType == MessageType.eventList) {
      return _EventListMessage(message: message);
    }
    if (isBot && message.messageType == MessageType.bookingHistory) {
      return _BookingHistoryMessage(message: message);
    }

    // ── Regular text bubble ───────────────────────────────────────────────
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isBot ? null : AppColors.primaryGradient,
          color: isBot ? AppColors.surfaceLight : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isBot ? 4 : 20),
            bottomRight: Radius.circular(isBot ? 20 : 4),
          ),
          border: isBot
              ? Border.all(color: AppColors.borderSubtle)
              : null,
          boxShadow: isBot
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: AppTextStyles.body1.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              message.timestamp.formattedTime,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event List Cards ──────────────────────────────────────────────────────────

class _EventListMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _EventListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final events =
        (message.extraData?['events'] as List<dynamic>?) ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bubble
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text('Here are the available events:',
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Event cards
            ...events.map((e) => _EventCard(event: e as Map<String, dynamic>)),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final name = event['name'] as String? ?? 'Event';
    final price = (event['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.body1
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap "Select Seats" to book',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              '₹${price.toStringAsFixed(0)}',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking History Cards ─────────────────────────────────────────────────────

class _BookingHistoryMessage extends StatelessWidget {
  final ChatMessageModel message;
  const _BookingHistoryMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final bookings =
        (message.extraData?['bookings'] as List<dynamic>?) ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text('Your recent bookings:',
                      style: AppTextStyles.body1
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...bookings
                .map((b) => _BookingCard(booking: b as Map<String, dynamic>)),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                message.timestamp.formattedTime,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final id = booking['booking_id'];
    final status = (booking['status'] as String? ?? 'unknown').toUpperCase();
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
    final isConfirmed = status == 'CONFIRMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isConfirmed ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isConfirmed
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
              size: 18,
              color:
                  isConfirmed ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking #$id',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(status,
                    style: AppTextStyles.caption.copyWith(
                      color: isConfirmed
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style:
                AppTextStyles.body1.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}