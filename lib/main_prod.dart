import 'core/config/app_config.dart';
import 'main_common.dart';

void main() async {
  AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: 'https://api.monitor.eugeniovaleiras.com/api',
    wsBaseUrl: 'wss://api.monitor.eugeniovaleiras.com',
    appName: 'Exchange Monitor',
  );

  await mainCommon();
}
