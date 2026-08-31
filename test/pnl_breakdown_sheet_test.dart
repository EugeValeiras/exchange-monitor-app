import 'package:exchange_monitor/core/config/app_config.dart';
import 'package:exchange_monitor/core/models/balance.dart';
import 'package:exchange_monitor/core/models/pnl.dart';
import 'package:exchange_monitor/core/services/api_service.dart';
import 'package:exchange_monitor/core/services/balance_service.dart';
import 'package:exchange_monitor/core/services/pnl_service.dart';
import 'package:exchange_monitor/core/theme/em_theme.dart';
import 'package:exchange_monitor/features/position/widgets/pnl_breakdown_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePnlService extends PnlService {
  _FakePnlService(this._positions, this._summary) : super(ApiService());

  final List<PnlPosition> _positions;
  final PnlSummary? _summary;

  @override
  List<PnlPosition> get positions => _positions;

  @override
  PnlSummary? get summary => _summary;
}

class _FakeBalanceService extends BalanceService {
  _FakeBalanceService(this._assets) : super(ApiService());

  final List<AssetBalance> _assets;

  @override
  List<AssetBalance> get assets => _assets;
}

PnlPosition _position(String asset, double pnl, {double amount = 1, double cost = 100}) {
  return PnlPosition(
    asset: asset,
    amount: amount,
    costBasis: cost,
    currentValue: cost + pnl,
    unrealizedPnl: pnl,
    unrealizedPnlPercent: cost == 0 ? 0 : pnl / cost * 100,
  );
}

AssetBalance _balance(String asset, double total) =>
    AssetBalance(asset: asset, free: total, locked: 0, total: total);

Future<void> _pump(
  WidgetTester tester, {
  required List<PnlPosition> positions,
  PnlSummary? summary,
  List<AssetBalance> balances = const [],
  PnlBreakdownKind kind = PnlBreakdownKind.unrealized,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PnlService>.value(
          value: _FakePnlService(positions, summary),
        ),
        ChangeNotifierProvider<BalanceService>.value(
          value: _FakeBalanceService(balances),
        ),
      ],
      child: MaterialApp(
        theme: EmTheme.dark(),
        home: Scaffold(body: PnlBreakdownSheet(kind: kind)),
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

  group('PnlBreakdownSheet', () {
    testWidgets('ordena por cuánto pesa, sin importar el signo', (tester) async {
      await _pump(tester, positions: [
        _position('USDT', -6),
        _position('BTC', -290),
        _position('NEXO', 221),
      ]);

      final nombres = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      final iBtc = nombres.indexOf('Bitcoin');
      final iNexo = nombres.indexOf('Nexo');
      final iUsdt = nombres.indexOf('Tether');

      expect(iBtc, greaterThanOrEqualTo(0));
      expect(iBtc, lessThan(iNexo), reason: 'BTC pesa 290, va primero');
      expect(iNexo, lessThan(iUsdt), reason: 'NEXO pesa 221, va antes que USDT');
    });

    testWidgets('el encabezado suma las filas mostradas', (tester) async {
      await _pump(tester, positions: [
        _position('BTC', -290),
        _position('NEXO', -221),
      ]);

      expect(find.text('−\$511,00'), findsOneWidget);
    });

    testWidgets('avisa una sola vez cuando los lotes no cuadran', (tester) async {
      await _pump(
        tester,
        positions: [
          _position('USDC', -37, amount: 36373.92),
          _position('NEXO', -221, amount: 11250.85),
        ],
        balances: [_balance('USDC', 4.21), _balance('NEXO', 25441.76)],
      );

      // Un aviso arriba, no uno por fila: repetido convierte el panel en un
      // muro de advertencias.
      expect(find.textContaining('pueden estar desfasados'), findsOneWidget);
    });

    testWidgets('nombra los activos cuando sólo algunos están desfasados',
        (tester) async {
      await _pump(
        tester,
        positions: [
          _position('USDC', -37, amount: 36373.92),
          _position('BTC', -290, amount: 1.0792),
        ],
        balances: [_balance('USDC', 4.21), _balance('BTC', 1.0792)],
      );

      expect(find.textContaining('En USD Coin'), findsOneWidget);
    });

    testWidgets('no avisa nada cuando los lotes cuadran', (tester) async {
      await _pump(
        tester,
        positions: [_position('BTC', -290, amount: 1.0792)],
        balances: [_balance('BTC', 1.0792)],
      );

      expect(find.textContaining('desfasado'), findsNothing);
    });

    testWidgets('sin lotes registrados lo dice en vez de mostrar una lista vacía',
        (tester) async {
      await _pump(tester, positions: const []);

      expect(find.textContaining('no se puede desarmar'), findsOneWidget);
    });

    testWidgets('el desglose total muestra realizado y no realizado', (tester) async {
      await _pump(
        tester,
        kind: PnlBreakdownKind.total,
        positions: const [],
        summary: const PnlSummary(
          totalRealizedPnl: -5860,
          totalUnrealizedPnl: -618,
          totalPnl: -6478,
          byAsset: [
            AssetPnl(
              asset: 'NEXO',
              realizedPnl: -5987,
              unrealizedPnl: -221,
              totalCostBasis: 9492,
              currentValue: 9270,
              totalAmount: 11250,
            ),
          ],
        ),
      );

      expect(find.textContaining('realizado −5.987'), findsOneWidget);
      expect(find.textContaining('no realizado −221'), findsOneWidget);
    });
  });
}
