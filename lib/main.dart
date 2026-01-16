// Default entry point - uses dev flavor
// For specific flavors, use:
//   flutter run -t lib/main_dev.dart --flavor dev
//   flutter run -t lib/main_prod.dart --flavor prod

import 'core/config/app_config.dart';
import 'main_common.dart';

void main() {
  // Default to dev for convenience during development
  AppConfig(
    flavor: Flavor.dev,
    apiBaseUrl: 'http://localhost:3050/api',
    wsBaseUrl: 'ws://localhost:3050',
    appName: 'Exchange Monitor DEV',
  );

  mainCommon();
}
