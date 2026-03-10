import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps FlutterLocalNotificationsPlugin. Call [init] once in main() before runApp.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification channel IDs ──────────────────────────────────────────────
  static const _bookingChannelId = 'booking_confirmed';
  static const _lockChannelId = 'seat_lock';

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: initSettings);

    // Create Android notification channels
    if (Platform.isAndroid) {
      const bookingChannel = AndroidNotificationChannel(
        _bookingChannelId,
        'Booking Confirmed',
        description: 'Notifications when a ticket booking is confirmed.',
        importance: Importance.high,
      );
      const lockChannel = AndroidNotificationChannel(
        _lockChannelId,
        'Seat Lock Expiry',
        description: 'Alerts when your seat lock is about to expire.',
        importance: Importance.max,
      );
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(bookingChannel);
      await androidPlugin?.createNotificationChannel(lockChannel);

      // Request POST_NOTIFICATIONS permission on Android 13+
      await androidPlugin?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  /// Show an immediate notification that booking is confirmed.
  Future<void> showBookingConfirmed({
    required int bookingId,
    required String eventName,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _bookingChannelId,
        'Booking Confirmed',
        channelDescription: 'Your ticket has been confirmed.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id: bookingId,
      title: '🎉 Booking Confirmed!',
      body: 'Your ticket for "$eventName" is ready. Show QR at the entrance.',
      notificationDetails: details,
    );
  }

  /// Schedule a warning 2 minutes before lock expiry. Cancels any previous.
  Future<void> scheduleLockExpiryWarning(DateTime lockExpiresAt) async {
    if (!_initialized) return;
    await _plugin.cancel(id: 0); // cancel previous lock warning if any

    final warnAt = lockExpiresAt.subtract(const Duration(minutes: 2));
    if (warnAt.isBefore(DateTime.now())) return; // already past warning time

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _lockChannelId,
        'Seat Lock Expiry',
        channelDescription: 'Your seat lock is about to expire.',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: 0,
        title: '⏰ Seat Lock Expiring Soon',
        body: 'You have 2 minutes to complete your booking!',
        scheduledDate: tz.TZDateTime.from(warnAt, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Exact alarms may require permission on Android 12+; fail silently.
      if (kDebugMode) rethrow;
    }
  }

  /// Cancel the lock expiry warning (call after payment completes or lock expires).
  Future<void> cancelLockWarning() async {
    await _plugin.cancel(id: 0);
  }
}
