class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const int defaultEventId = 1;
  static const int defaultUserId = 1;
  static const int lockDurationSeconds = 300;
  static const int warningThresholdSeconds = 60;
  static const int criticalThresholdSeconds = 15;
  static const double seatPrice = 50.0;
  static const String currencySymbol = r'$';
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;
}
