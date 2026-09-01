import 'package:exchange_monitor/core/models/pnl.dart';
import 'package:exchange_monitor/features/asset/lot_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

CostBasisLot _lot(
  DateTime at, {
  double remaining = 0.00009,
  double costPerUnit = 86495.24,
  double? original,
  String exchange = 'binance',
  String? pair = 'BTC/USDT',
  String source = 'trade',
}) {
  return CostBasisLot(
    id: at.toIso8601String() + remaining.toString(),
    asset: 'BTC',
    exchange: exchange,
    source: source,
    acquiredAt: at,
    originalAmount: original ?? remaining,
    remainingAmount: remaining,
    costPerUnit: costPerUnit,
    totalCost: costPerUnit * (original ?? remaining),
    pair: pair,
  );
}

RealizedPnlItem _sale(
  DateTime at, {
  double amount = 1,
  double pnl = 10,
  double costBasis = 100,
  double proceeds = 110,
  String exchange = 'binance',
}) {
  return RealizedPnlItem(
    id: at.toIso8601String() + amount.toString(),
    asset: 'BTC',
    amount: amount,
    proceeds: proceeds,
    costBasis: costBasis,
    realizedPnl: pnl,
    realizedAt: at,
    exchange: exchange,
    buyPrice: costBasis / amount,
    sellPrice: proceeds / amount,
  );
}

void main() {
  final base = DateTime(2025, 1, 25, 14, 30);

  group('groupLots', () {
    test('junta los fills de una orden en una fila', () {
      // El caso real: una compra ejecutada en 47 pedacitos idénticos.
      final lots = [
        for (var i = 0; i < 47; i++) _lot(base.add(Duration(seconds: i))),
      ];

      final groups = groupLots(lots);

      expect(groups, hasLength(1));
      expect(groups.single.count, 47);
      expect(groups.single.isGrouped, isTrue);
      expect(groups.single.remainingAmount, closeTo(0.00009 * 47, 1e-12));
    });

    test('no junta compras de días distintos', () {
      final groups = groupLots([
        _lot(base),
        _lot(base.add(const Duration(days: 3))),
      ]);

      expect(groups, hasLength(2));
    });

    test('mide la ventana contra el último fill, no contra el primero', () {
      // Una ráfaga de 40 minutos en pasos de 10: es una orden ejecutándose,
      // y medir contra el primero la partiría en compras que nunca existieron.
      final lots = [
        for (var i = 0; i < 5; i++) _lot(base.add(Duration(minutes: i * 10))),
      ];

      expect(groupLots(lots), hasLength(1));
    });

    test('corta cuando el hueco supera la ventana', () {
      final groups = groupLots([
        _lot(base),
        _lot(base.add(const Duration(minutes: 16))),
      ]);

      expect(groups, hasLength(2));
    });

    test('no mezcla exchanges', () {
      final groups = groupLots([
        _lot(base, exchange: 'binance'),
        _lot(base.add(const Duration(seconds: 1)), exchange: 'nexo'),
      ]);

      expect(groups, hasLength(2));
    });

    test('un fill vía otro par no es parte de una compra en el par principal', () {
      final groups = groupLots([
        _lot(base, pair: 'BTC/USDT'),
        _lot(base.add(const Duration(seconds: 1)), pair: 'NEXO/BTC'),
      ]);

      expect(groups, hasLength(2));
    });

    test('el precio del grupo es el ponderado por lo que queda', () {
      final groups = groupLots([
        _lot(base, remaining: 1, costPerUnit: 60000),
        _lot(base.add(const Duration(seconds: 1)), remaining: 3, costPerUnit: 80000),
      ]);

      // (60.000×1 + 80.000×3) / 4 = 75.000. Promediar a secas daría 70.000,
      // un precio que nadie pagó.
      expect(groups.single.costPerUnit, closeTo(75000, 0.01));
    });

    test('el no realizado del grupo es el de sus fills sumados', () {
      final groups = groupLots([
        _lot(base, remaining: 1, costPerUnit: 60000),
        _lot(base.add(const Duration(seconds: 1)), remaining: 1, costPerUnit: 90000),
      ]);

      // (80.000−60.000) + (80.000−90.000) = +10.000
      expect(groups.single.unrealizedAt(80000), closeTo(10000, 0.01));
    });

    test('marca el grupo como parcial si algún fill fue consumido', () {
      final groups = groupLots([
        _lot(base, remaining: 1, original: 1),
        _lot(base.add(const Duration(seconds: 1)), remaining: 1, original: 3),
      ]);

      expect(groups.single.isPartial, isTrue);
      expect(groups.single.remainingPercent, 50); // 2 de 4
    });

    test('deja en paz a un lote solo', () {
      final groups = groupLots([_lot(base, remaining: 2, costPerUnit: 70000)]);

      expect(groups.single.isGrouped, isFalse);
      expect(groups.single.count, 1);
      expect(groups.single.costPerUnit, 70000);
      expect(groups.single.isPartial, isFalse);
    });

    test('no rompe con una lista vacía', () {
      expect(groupLots(const []), isEmpty);
    });
  });

  group('groupSales', () {
    test('junta los fills de una venta y suma su resultado', () {
      final groups = groupSales([
        _sale(base, amount: 1, pnl: -10, costBasis: 100, proceeds: 90),
        _sale(base.add(const Duration(seconds: 5)),
            amount: 1, pnl: -20, costBasis: 100, proceeds: 80),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.count, 2);
      expect(groups.single.realizedPnl, closeTo(-30, 0.001));
      expect(groups.single.amount, closeTo(2, 0.001));
    });

    test('los precios del grupo son ponderados por cantidad', () {
      final groups = groupSales([
        _sale(base, amount: 1, costBasis: 100, proceeds: 200),
        _sale(base.add(const Duration(seconds: 1)),
            amount: 3, costBasis: 600, proceeds: 900),
      ]);

      // compra: 700/4 = 175 · venta: 1100/4 = 275
      expect(groups.single.buyPrice, closeTo(175, 0.01));
      expect(groups.single.sellPrice, closeTo(275, 0.01));
    });

    test('no junta ventas separadas por más que la ventana', () {
      final groups = groupSales([
        _sale(base),
        _sale(base.add(const Duration(hours: 2))),
      ]);

      expect(groups, hasLength(2));
    });
  });
}
