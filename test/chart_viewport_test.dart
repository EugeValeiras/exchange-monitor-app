import 'package:flutter_test/flutter_test.dart';
import 'package:exchange_monitor/features/market/widgets/chart_viewport.dart';

void main() {
  final velas = List.generate(100, (i) => i);

  group('ChartViewport · la ventana de velas', () {
    test('sin zoom se ven todas', () {
      const v = ChartViewport(total: 100);
      expect(v.isZoomed, isFalse);
      expect(v.count, 100);
      expect(v.slice(velas), velas);
    });

    test('acercar deja menos velas, ancladas en el centro', () {
      final v = const ChartViewport(total: 100).zoom(2);
      expect(v.count, 50);
      expect(v.isZoomed, isTrue);
      // el centro era 50: la ventana queda de 25 a 75
      expect(v.offset, 25);
      expect(v.slice(velas).first, 25);
      expect(v.slice(velas).last, 74);
    });

    test('arrastrar corre la ventana y ACUMULA entre gestos', () {
      // El bug: cada frame se aplicaba contra el inicio del gesto y el
      // desplazamiento se perdía. Tres tirones seguidos tienen que sumar.
      var v = const ChartViewport(total: 100).zoom(2);
      final desde = v.offset;
      v = v.pan(5).pan(5).pan(5);
      expect(v.offset, desde + 15);
    });

    test('no se puede correr más allá de los bordes', () {
      final v = const ChartViewport(total: 100).zoom(2);
      expect(v.pan(-999).offset, 0);
      expect(v.pan(999).offset, 50); // 100 - 50 visibles
      expect(v.pan(999).slice(velas).last, 99);
    });

    test('alejar más allá del total vuelve a mostrarlo entero', () {
      final v = const ChartViewport(total: 100).zoom(4).zoom(0.01);
      expect(v.count, 100);
      expect(v.offset, 0);
    });

    test('no se puede acercar por debajo del mínimo', () {
      final v = const ChartViewport(total: 100).zoom(1000);
      expect(v.count, ChartViewport.minVisible);
    });

    test('un píxel vale más velas cuanto más alejado estés', () {
      const ancho = 300.0;
      expect(const ChartViewport(total: 300).candlesPerPixel(ancho), 1);
      expect(const ChartViewport(total: 300).zoom(3).candlesPerPixel(ancho), closeTo(0.333, 0.01));
      expect(const ChartViewport(total: 300).candlesPerPixel(0), 0);
    });

    group('cuando llega una vela nueva', () {
      test('si estabas pegado al borde te quedás pegado', () {
        final v = const ChartViewport(total: 100).zoom(2).pan(999);
        expect(v.offset, 50);
        final crecido = v.withTotal(101);
        expect(crecido.offset, 51); // sigue mostrando lo último
      });

      test('si mirabas atrás no te mueve el piso', () {
        final v = const ChartViewport(total: 100).zoom(2).pan(-999);
        expect(v.offset, 0);
        expect(v.withTotal(101).offset, 0);
      });
    });

    test('reset vuelve a todas', () {
      final v = const ChartViewport(total: 100).zoom(4).pan(20).reset();
      expect(v.isZoomed, isFalse);
      expect(v.slice(velas).length, 100);
    });

    test('sin velas no rompe nada', () {
      const v = ChartViewport(total: 0);
      expect(v.count, 0);
      expect(v.slice(<int>[]), isEmpty);
      expect(v.zoom(2).count, 0);
    });
  });
}
