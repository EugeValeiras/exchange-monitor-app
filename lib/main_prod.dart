import 'core/config/app_config.dart';
import 'main_common.dart';

void main() async {
  AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: 'http://192.168.0.172:3050/api',
    wsBaseUrl: 'ws://192.168.0.172:3050',
    appName: 'Exchange Monitor DEV',
  );

  await mainCommon();
}
