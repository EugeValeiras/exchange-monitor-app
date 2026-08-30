class Environment {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    if (isProduction) {
      return 'http://100.79.196.98:3050/api';
    }
    return 'http://localhost:3050/api';
  }

  static String get wsBaseUrl {
    if (isProduction) {
      return 'ws://100.79.196.98:3050';
    }
    return 'ws://localhost:3050';
  }

  static String get pricesSocketPath => '/prices';
  static String get balancesSocketPath => '/balances';
}
