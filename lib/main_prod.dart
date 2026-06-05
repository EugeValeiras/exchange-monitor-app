import 'core/config/app_config.dart';
import 'main_common.dart';

void main() async {
  AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: 'https://api.exchange.eugeniovaleiras.com/api',
    wsBaseUrl: 'wss://api.exchange.eugeniovaleiras.com',
    appName: 'Exchange Monitor',
  );

  await mainCommon();
}
