import 'core/config/app_config.dart';
import 'main_common.dart';

void main() {
  AppConfig(
    flavor: Flavor.dev,
    apiBaseUrl: 'http://localhost:3050/api',
    wsBaseUrl: 'ws://localhost:3050',
    appName: 'Exchange Monitor DEV',
  );

  mainCommon();
}
