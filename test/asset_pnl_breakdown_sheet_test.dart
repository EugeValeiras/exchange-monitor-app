import 'package:exchange_monitor/core/config/app_config.dart';
import 'package:exchange_monitor/core/models/pnl.dart';
import 'package:exchange_monitor/core/services/api_service.dart';
import 'package:exchange_monitor/core/services/pnl_service.dart';
import 'package:exchange_monitor/core/theme/em_theme.dart';
import 'package:exchange_monitor/features/asset/widgets/asset_pnl_breakdown_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class _FakePnlService extends PnlService {
  _FakePnlService({this.lots = const [], this.sales = const []})
      : super(ApiService());

  final List<CostBasisLot> lots;
  final List<RealizedPnlItem> sales;

  @override
  Future<List<CostBasisLot>> lotsFor(String asset) async => lots;

  @override
  Future<List<RealizedPnlItem>> realizedFor(String asset) async => sales;
}

CostBasisLot _lot(
  String id, {
  required double remaining,
  required double costPerUnit,
  double? original,
  String exchange = 'binance',
  String? pair,
  DateTime? at,
}) {
  return CostBasisLot(
    id: id,
    asset: 'BTC',
    exchange: exchange,
    source: 'trade',
    // Días distintos salvo que el caso pida lo contrario: dos lotes a la misma
    // hora son fills de una compra y la pantalla los junta.
    acquiredAt: at ?? DateTime(2025, 3, 14).add(Duration(days: id.hashCode % 90)),
    originalAmount: original ?? remaining,
    remainingAmount: remaining,
    costPerUnit: costPerUnit,
    totalCost: costPerUnit * (original ?? remaining),
    pair: pair,
  );
}

/// Una venta con los números cerrando entre sí: el grupo deriva los precios
/// de costBasis/proceeds, así que un helper con precios sueltos mentiría.
RealizedPnlItem _sale(String id,
    {required double pnl, double amount = 1, DateTime? at}) {
  const buyPrice = 60000.0;
  final costBasis = buyPrice * amount;
  final proceeds = costBasis + pnl;

  return RealizedPnlItem(
    id: id,
    asset: 'BTC',
    amount: amount,
    proceeds: proceeds,
    costBasis: costBasis,
    realizedPnl: pnl,
    realizedAt: at ?? DateTime(2025, 6, 2).add(Duration(days: id.hashCode % 90)),
    exchange: 'binance',
    buyPrice: buyPrice,
    sellPrice: proceeds / amount,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakePnlService service,
  required AssetPnlKind kind,
  double? total,
  double? price,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PnlService>.value(
      value: service,
      child: MaterialApp(
        theme: EmTheme.dark(),
        home: Scaffold(
          body: AssetPnlBreakdownSheet(
            asset: 'BTC',
            kind: kind,
            total: total,
            price: price,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // Las filas llevan fecha, y `DateFormat(..., 'es')` no arranca sin esto.
    initializeDateFormatting('es');
    AppConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'http://localhost:3050/api',
      wsBaseUrl: 'ws://localhost:3050',
      appName: 'test',
    );
  });

  group('AssetPnlBreakdownSheet · no realizado', () {
    testWidgets('muestra un lote por cada compra que sobrevivió', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('a', remaining: 0.5, costPerUnit: 60000),
          _lot('b', remaining: 0.25, costPerUnit: 90000),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
        total: -500,
      );

      expect(find.text('LOTES ABIERTOS · 2'), findsOneWidget);
      // (80.000 − 60.000) × 0,5 = +10.000
      expect(find.text('+\$10.000,00'), findsOneWidget);
      // (80.000 − 90.000) × 0,25 = −2.500
      expect(find.text('−\$2.500,00'), findsOneWidget);
    });

    testWidgets('ordena por lo que pesa, sin importar el signo', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('chico', remaining: 0.01, costPerUnit: 70000),
          _lot('grande', remaining: 2, costPerUnit: 100000),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      // El lote grande pierde 40.000; el chico gana 100. Pesa más el grande.
      final iGrande = textos.indexWhere((t) => t.contains('−\$40.000'));
      final iChico = textos.indexWhere((t) => t.contains('+\$100'));
      expect(iGrande, greaterThanOrEqualTo(0));
      expect(iGrande, lessThan(iChico));
    });

    testWidgets('avisa cuánto queda de un lote comido a medias', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('a', remaining: 0.25, original: 1, costPerUnit: 60000),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      expect(find.textContaining('quedan 25%'), findsOneWidget);
    });

    testWidgets('el encabezado repite el número del card, no la suma de las filas',
        (tester) async {
      // La API dijo −103; las filas al precio de este segundo dan otra cosa.
      // Manda el card: dos números distintos para lo mismo es peor que uno.
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('a', remaining: 1, costPerUnit: 60000),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
        total: -103,
      );

      expect(find.text('−\$103,00'), findsOneWidget);
    });

    testWidgets('junta los fills de una compra en una sola fila', (tester) async {
      // El caso de la captura: una orden ejecutada en 47 pedacitos idénticos.
      final t = DateTime(2025, 1, 25, 14, 30);
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          for (var i = 0; i < 47; i++)
            _lot('f$i',
                remaining: 0.00009,
                costPerUnit: 86495.24,
                at: t.add(Duration(seconds: i))),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      // Una fila, no 47, y el conteo no le miente a la contabilidad.
      expect(find.text('LOTES ABIERTOS · 1 DE 47'), findsOneWidget);
      expect(find.textContaining('47 operaciones'), findsOneWidget);
      expect(find.text('0,00423000 BTC · Binance'), findsOneWidget);
    });

    testWidgets('no dice "de" cuando no agrupó nada', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('a', remaining: 1, costPerUnit: 60000, at: DateTime(2025, 1, 2)),
          _lot('b', remaining: 1, costPerUnit: 70000, at: DateTime(2025, 5, 9)),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      expect(find.text('LOTES ABIERTOS · 2'), findsOneWidget);
      expect(find.textContaining('operaciones'), findsNothing);
    });

    testWidgets('la fila lleva el exchange arriba, y abajo el precio y el mercado',
        (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: [
          _lot('a',
              remaining: 0.213063,
              costPerUnit: 64163.22,
              pair: 'BTC/USDT',
              at: DateTime(2025, 6, 3, 15, 6)),
        ]),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      // Arriba: cuánto y dónde. Abajo: cuándo, a cuánto y por qué mercado —
      // los dos últimos son justo los que se cortaban.
      expect(find.text('0,213063 BTC · Binance'), findsOneWidget);
      expect(find.textContaining('a 64.163,22'), findsOneWidget);
      expect(find.textContaining('vía BTC/USDT'), findsOneWidget);
      expect(find.textContaining('3 jun 15:06'), findsOneWidget);
    });

    testWidgets('lo dice cuando no hay lotes', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(lots: const []),
        kind: AssetPnlKind.unrealized,
        price: 80000,
      );

      expect(find.textContaining('No hay lotes'), findsOneWidget);
    });
  });

  group('AssetPnlBreakdownSheet · realizado', () {
    testWidgets('muestra una fila por venta cerrada', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(sales: [
          _sale('a', pnl: -3000),
          _sale('b', pnl: 500),
        ]),
        kind: AssetPnlKind.realized,
        total: -2500,
      );

      expect(find.text('VENTAS · 2'), findsOneWidget);
      expect(find.text('−\$3.000,00'), findsOneWidget);
      expect(find.text('+\$500,00'), findsOneWidget);
    });

    testWidgets('cada venta lleva el precio de compra y el de venta', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(sales: [_sale('a', pnl: 200)]),
        kind: AssetPnlKind.realized,
      );

      // Sin el precio de compra, el resultado es un número sin origen.
      expect(find.textContaining('60.000,00 → 60.200,00'), findsOneWidget);
    });

    testWidgets('lo dice cuando no cerraste ninguna venta', (tester) async {
      await _pump(
        tester,
        service: _FakePnlService(sales: const []),
        kind: AssetPnlKind.realized,
      );

      expect(find.textContaining('Todavía no cerraste'), findsOneWidget);
    });
  });
}
