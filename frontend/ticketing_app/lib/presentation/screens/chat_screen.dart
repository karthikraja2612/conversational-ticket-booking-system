import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/chat_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/event_state.dart';
import '../../data/models/event_model.dart';
import '../widgets/chat/chat_message_bubble.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/chat_input.dart';
import '../widgets/common/gradient_button.dart';
import 'seat_selection_screen.dart';
import 'ticket_confirmation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatState>().initialize();
        // Listen for auto-navigation to seat selection (from booking flow)
        context.read<ChatState>().addListener(_onChatStateChanged);
      }
    });
  }

  void _onChatStateChanged() {
    if (!mounted) return;
    final chat = context.read<ChatState>();
    if (chat.shouldNavigateToSeats) {
      chat.consumeNavigateToSeats();
      final eventId = chat.pendingEventId;
      if (eventId != null) {
        // Set the event in BookingState and EventState
        final booking = context.read<BookingState>();
        booking.setCurrentEventId(eventId);
        booking.clearSelection();
        // Find the event in EventState's list
        final eventState = context.read<EventState>();
        final found = eventState.events.where((e) => e.id == eventId).toList();
        if (found.isNotEmpty) {
          eventState.setSelectedEvent(found.first);
        } else {
          // Set a placeholder event with the ID
          eventState.setSelectedEvent(EventModel(
            id: eventId,
            name: 'Event #$eventId',
            description: '',
            venue: '',
            date: DateTime.now(),
            price: 0,
          ));
        }
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeatSelectionScreen()),
      );
    }
  }

  @override
  void dispose() {
    // Remove listener before disposing
    try {
      context.read<ChatState>().removeListener(_onChatStateChanged);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Row(
              children: [
                const Text('TicketBot'),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Consumer<BookingState>(
              builder: (_, booking, __) {
                if (!booking.isLocked) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(booking.remainingLockTime),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.warning),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer2<ChatState, BookingState>(
        builder: (context, chatState, bookingState, _) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());

          final showViewTicket = chatState.step == ChatFlowStep.paymentDone;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: chatState.messages.length +
                      (chatState.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatState.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TypingIndicator(),
                        ),
                      );
                    }
                    return ChatMessageBubble(
                      message: chatState.messages[index],
                    ).animate().fadeIn(duration: 300.ms).slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOut,
                        );
                  },
                ),
              ),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showViewTicket)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GradientButton(
                            text: 'View My Ticket',
                            icon: Icons.confirmation_number_rounded,
                            gradient: AppColors.successGradient,
                            width: double.infinity,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TicketConfirmationScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      const ChatInput(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
