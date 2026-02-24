import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/booking_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'domain/state/auth_state.dart';
import 'domain/state/booking_state.dart';
import 'domain/state/chat_state.dart';
import 'domain/state/event_state.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingRepo = BookingRepository();
    final chatRepo = ChatRepository();
    final eventState = EventState();
    // Fetch events immediately on app start
    eventState.fetchEvents();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(
          create: (_) => BookingState(repository: bookingRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatState(repository: chatRepo),
        ),
        ChangeNotifierProvider.value(value: eventState),
      ],
      child: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<BookingState>().setAuthToken(auth.token);
              context.read<BookingState>().setCurrentUserId(auth.userId);
              context.read<ChatState>().setAuthToken(auth.token);
            });
          }
          return MaterialApp(
            title: 'TicketBot',
            theme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}