import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exchange_monitor/core/models/market.dart';
import 'package:exchange_monitor/features/market/widgets/candlestick_chart.dart';
import 'package:exchange_monitor/features/market/widgets/order_book_view.dart';

Candle vela(double o, double h, double l, double c, {double vol = 10}) => Candle(
      time: DateTime(2026, 6, 3),
      open: o,
      high: h,
      low: l,
      close: c,
      volume: vol,
    );

Future<void> montar(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
    );

void main() {
  group('OrderBook · el modelo', () {
    test('lee niveles y descarta los de cantidad cero', () {
      final b = OrderBook.fromJson({
        'symbol': 'BTC/USDT',
        'timestamp': '2026-06-03T10:00:00.000Z',
        'bids': [
          ['80662.27', '1.60385'],
          ['80662.26', '0'],
        ],
        'asks': [
          ['80662.28', '2.38971'],
        ],
      });

      expect(b.bids, hasLength(1));
      expect(b.bids.first.price, 80662.27);
      expect(b.asks, hasLength(1));
      expect(b.spread, closeTo(0.01, 1e-9));
      expect(b.spreadPct, closeTo(0.0000124, 1e-6));
    });

    test('sin un lado no inventa spread', () {
      final b = OrderBook.fromJson({
        'symbol': 'BTC/USDT',
        'bids': [
          ['100', '1'],
        ],
        'asks': <dynamic>[],
      });
      expect(b.spread, isNull);
      expect(b.spreadPct, isNull);
    });
  });

  group('Ohlc · máximos, mínimos y volumen del tramo', () {
    test('salen de las velas, sin pedir nada más', () {
      final o = Ohlc(
        exchange: 'binance',
        symbol: 'BTC/USDT',
        timeframe: '1d',
        candles: [vela(100, 120, 90, 110, vol: 3), vela(110, 130, 105, 108, vol: 7)],
      );
      expect(o.high, 130);
      expect(o.low, 90);
      expect(o.volume, 10);
    });

    test('sin velas no hay rango', () {
      const o = Ohlc(exchange: 'b', symbol: 's', timeframe: '1d', candles: []);
      expect(o.high, isNull);
      expect(o.low, isNull);
      expect(o.volume, 0);
    });
  });

  group('CandlestickChart', () {
    testWidgets('dibuja sin romperse con velas normales', (tester) async {
      await montar(
        tester,
        CandlestickChart(
          candles: [vela(100, 120, 90, 110), vela(110, 130, 105, 108)],
          livePrice: 115,
          avgCost: 95,
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una vela plana no rompe la escala', (tester) async {
      // open == high == low == close: el rango es cero y dividir por él
      // mandaría todo a infinito.
      await montar(tester, CandlestickChart(candles: [vela(100, 100, 100, 100, vol: 0)]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin velas avisa en vez de quedar en blanco', (tester) async {
      await montar(tester, const CandlestickChart(candles: []));
      expect(find.textContaining('Sin velas'), findsOneWidget);
    });
  });

  group('OrderBookView', () {
    testWidgets('muestra los dos lados y el spread', (tester) async {
      final b = OrderBook(
        symbol: 'BTC/USDT',
        at: DateTime(2026, 6, 3),
        bids: const [BookLevel(80662.27, 1.6), BookLevel(80662.26, 0.5)],
        asks: const [BookLevel(80662.28, 2.4)],
      );
      await montar(tester, OrderBookView(book: b, live: true));

      expect(find.text('SPREAD'), findsOneWidget);
      expect(find.text('EN VIVO'), findsOneWidget);
      expect(find.text('COMPRA'), findsOneWidget);
      expect(find.text('VENTA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin libro lo dice, no deja el hueco', (tester) async {
      await montar(tester, const OrderBookView(book: null));
      expect(find.textContaining('Sin libro'), findsOneWidget);
    });

    testWidgets('un libro vacío se trata como sin libro', (tester) async {
      final b = OrderBook(
        symbol: 'X/Y',
        at: DateTime(2026, 6, 3),
        bids: const [],
        asks: const [],
      );
      await montar(tester, OrderBookView(book: b));
      expect(find.textContaining('Sin libro'), findsOneWidget);
    });
  });
}
