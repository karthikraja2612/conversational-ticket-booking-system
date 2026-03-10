import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../animations/fade_slide_transition.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthState>();
      await auth.checkSession();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (auth.isAuthenticated) {
        context.read<BookingState>().setAuthToken(auth.token);
        context.read<BookingState>().setCurrentUserId(auth.userId);
        context.read<ChatState>().setAuthToken(auth.token);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeSlideTransition(
          duration: const Duration(milliseconds: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text('TicketBot', style: AppTextStyles.h1),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}