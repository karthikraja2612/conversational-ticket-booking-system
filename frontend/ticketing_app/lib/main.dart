import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/booking_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/services/notification_service.dart';
import 'domain/state/admin_state.dart';
import 'domain/state/auth_state.dart';
import 'domain/state/booking_state.dart';
import 'domain/state/chat_state.dart';
import 'domain/state/event_state.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  await NotificationService.instance.init();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final BookingRepository _bookingRepo;
  late final ChatRepository _chatRepo;
  late final EventState _eventState;

  @override
  void initState() {
    super.initState();
    _bookingRepo = BookingRepository();
    _chatRepo = ChatRepository();
    _eventState = EventState();
    // Fetch events once on app start — not on every build()
    _eventState.fetchEvents();
  }

  @override
  void dispose() {
    _eventState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminState()),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(
          create: (_) => BookingState(repository: _bookingRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatState(repository: _chatRepo),
        ),
        ChangeNotifierProvider.value(value: _eventState),
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