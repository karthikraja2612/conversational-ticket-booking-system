class AppConstants {
  /// Reads API_BASE_URL from assets/.env at runtime.
  /// Edit assets/.env to switch between emulator, device, or production URL —
  /// no rebuild required.
  // static String get baseUrl =>
      // dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
      // dotenv.env['API_BASE_URL'] ?? 'http://10.120.97.147:8000';
  static const String baseUrl = "http://10.36.49.147:8000";
  // defaultEventId removed — always use EventState.primaryEvent?.id
  static const int lockDurationSeconds = 300;
  static const int warningThresholdSeconds = 120;
  static const int criticalThresholdSeconds = 60;
  static const double seatPrice = 500.0;
  static const String currencySymbol = r'₹';
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
}