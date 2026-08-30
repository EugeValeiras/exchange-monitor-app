import 'core/config/app_config.dart';
import 'main_common.dart';

void main() async {
  AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: 'http://100.79.196.98:3050/api',
    wsBaseUrl: 'ws://100.79.196.98:3050',
    appName: 'Exchange Monitor',
  );

  await mainCommon();
}
