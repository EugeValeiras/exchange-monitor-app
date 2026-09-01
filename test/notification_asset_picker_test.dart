import 'package:exchange_monitor/core/config/app_config.dart';
import 'package:exchange_monitor/core/models/balance.dart';
import 'package:exchange_monitor/core/services/api_service.dart';
import 'package:exchange_monitor/core/services/balance_service.dart';
import 'package:exchange_monitor/core/services/notification_service.dart';
import 'package:exchange_monitor/core/theme/em_theme.dart';
import 'package:exchange_monitor/features/settings/screens/notification_settings_screen.dart';
import 'package:exchange_monitor/shared/widgets/em/em_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Qué activos avisan.
///
/// Antes esto era una tabla de cinco escrita a mano en el backend: no se podía
/// sumar algo que tuvieras ni sacar algo que no. Lo que se prueba acá es que la
/// lista ofrecida sea TU cartera y que una elección vieja no desaparezca sola.
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({required List<String> alertAssets})
      : _alertAssetsFake = List<String>.from(alertAssets),
        super(ApiService());

  List<String> _alertAssetsFake;
  final List<({String asset, bool followed})> guardados = [];

  @override
  bool get hasPermission => true;

  @override
  bool get enabled => true;

  @override
  List<String> get alertAssets => List.unmodifiable(_alertAssetsFake);

  @override
  bool followsAsset(String asset) =>
      _alertAssetsFake.contains(asset.toUpperCase());

  @override
  Future<void> loadSettings() async {}

  @override
  Future<void> refreshPermissionStatus() async {}

  @override
  Future<void> setAssetFollowed(String asset, bool followed) async {
    guardados.add((asset: asset, followed: followed));
    final next = List<String>.from(_alertAssetsFake)..remove(asset.toUpperCase());
    if (followed) next.add(asset.toUpperCase());
    _alertAssetsFake = next;
    notifyListeners();
  }
}

class _FakeBalanceService extends BalanceService {
  _FakeBalanceService(this._assets) : super(ApiService());

  final List<AssetBalance> _assets;

  @override
  bool get hasData => true;

  @override
  List<AssetBalance> get assets => _assets;
}

AssetBalance _asset(String ticker, double valueUsd) => AssetBalance(
      asset: ticker,
      free: 1,
      locked: 0,
      total: 1,
      valueUsd: valueUsd,
      exchanges: const ['kraken'],
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeNotificationService notifications,
  _FakeBalanceService balances,
) async {
  // La sección va al final de un ListView: sin alto suficiente no se dibuja, y
  // lo que no se dibuja no se puede encontrar.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationService>.value(value: notifications),
        ChangeNotifierProvider<BalanceService>.value(value: balances),
      ],
      child: MaterialApp(
        theme: EmTheme.dark(),
        home: const NotificationSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    AppConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'http://localhost:3050/api',
      wsBaseUrl: 'ws://localhost:3050',
      appName: 'test',
    );
  });

  testWidgets('ofrece los activos de tu cartera, no un catálogo', (tester) async {
    final notifications = _FakeNotificationService(alertAssets: const ['BTC']);
    final balances = _FakeBalanceService([
      _asset('BTC', 5000),
      _asset('ETH', 1200),
      _asset('XRP', 80),
    ]);

    await _pump(tester, notifications, balances);

    expect(find.text('ACTIVOS'), findsOneWidget);
    expect(
      find.text('XRP'),
      findsWidgets,
      reason: 'XRP no entraba en la tabla vieja de cinco activos',
    );
    expect(find.text('1 de 3'), findsOneWidget);
  });

  testWidgets('una elección vieja no desaparece por quedarte sin saldo',
      (tester) async {
    // Vendiste todo tu SOL: la fila tiene que seguir, o la selección se borraría
    // sola y sin decir nada.
    final notifications = _FakeNotificationService(alertAssets: const ['SOL']);
    final balances = _FakeBalanceService([_asset('BTC', 5000)]);

    await _pump(tester, notifications, balances);

    expect(find.text('SOL'), findsWidgets);
    expect(find.text('sin saldo'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
  });

  testWidgets('tocar la fila cambia la selección', (tester) async {
    final notifications = _FakeNotificationService(alertAssets: const []);
    final balances = _FakeBalanceService([_asset('BTC', 5000)]);

    await _pump(tester, notifications, balances);

    await tester.tap(find.widgetWithText(EmListRow, 'BTC').first);
    await tester.pumpAndSettle();

    expect(notifications.guardados, hasLength(1));
    expect(notifications.guardados.first.asset, 'BTC');
    expect(notifications.guardados.first.followed, isTrue);
    expect(find.text('1 de 1'), findsOneWidget);
  });

  testWidgets('avisa cuando no queda ningún activo elegido', (tester) async {
    final notifications = _FakeNotificationService(alertAssets: const []);
    final balances = _FakeBalanceService([_asset('BTC', 5000)]);

    await _pump(tester, notifications, balances);

    expect(
      find.text('Sin ningún activo elegido no llega ningún aviso.'),
      findsOneWidget,
    );
  });
}
