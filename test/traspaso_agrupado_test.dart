import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:exchange_monitor/core/models/transaction.dart';
import 'package:exchange_monitor/features/movements/widgets/movement_row.dart';

Transaction mov({
  required String id,
  required TransactionType type,
  required String exchange,
  double amount = 0.579245,
  String? grupo,
  int hora = 15,
}) =>
    Transaction(
      id: id,
      exchange: exchange,
      type: type,
      asset: 'BTC',
      amount: amount,
      timestamp: DateTime(2026, 8, 24, hora, 48),
      transferGroupId: grupo,
      price: 80000,
      priceAsset: 'USDT',
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('Un traspaso entre exchanges, en una fila', () {
    // El caso real: 0,579245 BTC salen de Nexo 15:48 y entran a Binance 16:48.
    final salida = mov(
        id: 'r', type: TransactionType.withdrawal, exchange: 'nexo-manual', hora: 15, grupo: 'r');
    final entrada = mov(
        id: 'd', type: TransactionType.deposit, exchange: 'binance', hora: 16, grupo: 'r');

    Future<void> montar(WidgetTester tester, List<Transaction> items) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(body: GroupedMovementRow(transactions: items)),
        ));

    testWidgets('dice "Traspaso" y de dónde a dónde', (tester) async {
      await montar(tester, [salida, entrada]);

      expect(find.text('Traspaso BTC'), findsOneWidget);
      expect(find.text('Nexo → Binance'), findsOneWidget);
      // No es un depósito ni un retiro: ninguno de los dos títulos aparece.
      expect(find.textContaining('Depósito'), findsNothing);
      expect(find.textContaining('Retiro'), findsNothing);
    });

    testWidgets('no suma las dos puntas, que darían cero', (tester) async {
      await montar(tester, [salida, entrada]);

      // Se muestra CUÁNTO se movió, sin signo: ni +0,579 ni −0,579 ni 0.
      expect(find.textContaining('0,579245'), findsWidgets);
      expect(find.textContaining('+0,579245'), findsNothing);
      expect(find.textContaining('−0,579245'), findsNothing);
    });

    testWidgets('no lleva el contador de cantidad: son dos y se sabe',
        (tester) async {
      await montar(tester, [salida, entrada]);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('se puede abrir para ver las dos operaciones', (tester) async {
      await montar(tester, [salida, entrada]);

      expect(find.textContaining('Retiro'), findsNothing);
      await tester.tap(find.text('Traspaso BTC'));
      await tester.pumpAndSettle();

      // adentro sí están las dos puntas, cada una con su exchange
      expect(find.textContaining('Nexo'), findsWidgets);
      expect(find.textContaining('Binance'), findsWidgets);
    });

    testWidgets('un grupo de intereses sigue mostrándose como antes',
        (tester) async {
      final intereses = [
        for (var i = 0; i < 3; i++)
          mov(id: 'i$i', type: TransactionType.interest, exchange: 'nexo-manual', amount: 1),
      ];
      await montar(tester, intereses);

      expect(find.text('3'), findsOneWidget); // el contador vuelve
      expect(find.textContaining('Traspaso'), findsNothing);
    });
  });
}
