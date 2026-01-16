enum Flavor { dev, prod }

class AppConfig {
  final Flavor flavor;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String appName;

  static AppConfig? _instance;

  factory AppConfig({
    required Flavor flavor,
    required String apiBaseUrl,
    required String wsBaseUrl,
    required String appName,
  }) {
    _instance ??= AppConfig._internal(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      appName: appName,
    );
    return _instance!;
  }

  AppConfig._internal({
    required this.flavor,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.appName,
  });

  static AppConfig get instance {
    if (_instance == null) {
      throw Exception('AppConfig not initialized. Call AppConfig() first.');
    }
    return _instance!;
  }

  static bool get isProduction => _instance?.flavor == Flavor.prod;
  static bool get isDevelopment => _instance?.flavor == Flavor.dev;
}
