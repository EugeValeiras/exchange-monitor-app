import 'dart:math' as math;

/// La ventana de velas que se está mirando.
///
/// Vive aparte del widget porque es aritmética pura y la aritmética se puede
/// probar: la primera versión aplicaba el desplazamiento de cada frame contra
/// la posición del INICIO del gesto, así que el arrastre se reseteaba solo y
/// no había forma de navegar después de acercar.
class ChartViewport {
  /// Cuántas velas hay en total.
  final int total;

  /// Cuántas entran en pantalla. 0 significa "todas": sin zoom.
  final double visible;

  /// Índice de la primera vela visible.
  final double offset;

  const ChartViewport({
    required this.total,
    this.visible = 0,
    this.offset = 0,
  });

  /// Mínimo de velas en pantalla. Menos que esto no es un gráfico.
  static const double minVisible = 12;

  bool get isZoomed => visible > 0 && visible < total;

  /// Cuántas se ven de verdad, resuelto el 0.
  double get count =>
      total == 0 ? 0 : (visible <= 0 ? total.toDouble() : visible.clamp(minVisible, total.toDouble()));

  /// Hasta dónde puede correrse sin dejar hueco al final.
  double get maxOffset => math.max(0, total - count);

  ChartViewport _con({double? visible, double? offset}) => ChartViewport(
        total: total,
        visible: visible ?? this.visible,
        offset: (offset ?? this.offset).clamp(0.0, math.max(0, total - (visible ?? count))),
      );

  /// Acerca o aleja. `factor` > 1 acerca.
  ///
  /// Se ancla en el centro de la ventana: si no, al acercar se escaparía hacia
  /// un borde y perderías de vista lo que estabas mirando.
  ChartViewport zoom(double factor) {
    if (total == 0 || factor <= 0) return this;
    final antes = count;
    final ahora = (antes / factor).clamp(minVisible, total.toDouble());
    final centro = offset + antes / 2;
    return _con(visible: ahora, offset: centro - ahora / 2);
  }

  /// Corre la ventana en velas. Positivo va hacia el futuro.
  ChartViewport pan(double candles) => _con(offset: offset + candles);

  /// Cuántas velas representa un píxel de pantalla, para traducir un arrastre.
  double candlesPerPixel(double plotWidth) =>
      plotWidth <= 0 ? 0 : count / plotWidth;

  ChartViewport reset() => ChartViewport(total: total);

  /// La misma ventana sobre una lista nueva.
  ///
  /// Al llegar una vela nueva el total crece: si estabas pegado al borde
  /// derecho te quedás pegado —querés ver lo último—, y si estabas mirando
  /// atrás no te mueve el piso.
  ChartViewport withTotal(int nuevo) {
    if (nuevo == total) return this;
    final pegadoAlFinal = offset >= maxOffset - 0.5;
    final v = ChartViewport(total: nuevo, visible: visible, offset: offset);
    return pegadoAlFinal ? v._con(offset: v.maxOffset) : v;
  }

  /// El tramo visible de una lista, listo para dibujar.
  List<T> slice<T>(List<T> all) {
    if (all.isEmpty) return const [];
    final n = count.round().clamp(1, all.length);
    final start = offset.round().clamp(0, all.length - n);
    return all.sublist(start, start + n);
  }
}
