class Environment {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    if (isProduction) {
      return 'https://api.exchange.eugeniovaleiras.com/api';
    }
    return 'http://localhost:3050/api';
  }

  static String get wsBaseUrl {
    if (isProduction) {
      return 'wss://api.exchange.eugeniovaleiras.com';
    }
    return 'ws://localhost:3050';
  }

  static String get pricesSocketPath => '/prices';
  static String get balancesSocketPath => '/balances';
}
