class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://192.168.86.59:4111',
  );

  static bool get isProduction => backendUrl.contains('treasureortrash.app'); // Example check
}
