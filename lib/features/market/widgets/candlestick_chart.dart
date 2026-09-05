import 'package:flutter/material.dart';
import '../../../core/models/market.dart';
import '../../../core/theme/em_tokens.dart';

/// Velas japonesas.
///
/// Dibujadas a mano y no con fl_chart: una vela es cuatro números en una barra
/// con mecha, y ninguna librería de líneas lo hace sin pelear. Además así el
/// volumen comparte el eje horizontal exacto del precio, que es la mitad de
/// para qué sirve mirarlos juntos.
class CandlestickChart extends StatefulWidget {
  final List<Candle> candles;

  /// El precio en vivo, para la línea punteada del último valor.
  final double? livePrice;

  /// Tu costo promedio, si tenés posición: la referencia contra la que mirás.
  final double? avgCost;

  /// Tus órdenes puestas, como líneas al precio al que esperan.
  final List<OpenOrder> orders;

  final double height;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.livePrice,
    this.avgCost,
    this.orders = const [],
    this.height = 260,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  /// Cuántas velas entran en pantalla y desde cuál. Pellizcar cambia la
  /// cantidad; arrastrar, el punto de partida.
  double _visible = 0;
  double _offset = 0;
  double _visibleAtGestureStart = 0;
  double _offsetAtGestureStart = 0;

  static const _minVisible = 12.0;

  int get _total => widget.candles.length;

  /// Las velas que se ven ahora. Sin zoom, todas.
  List<Candle> get _slice {
    if (_total == 0) return const [];
    final n = _visible <= 0 ? _total : _visible.clamp(_minVisible, _total.toDouble());
    final start = _offset.clamp(0.0, (_total - n).clamp(0.0, _total.toDouble()));
    return widget.candles.sublist(start.round(), (start + n).round().clamp(0, _total));
  }

  bool get _zoomed => _visible > 0 && _visible < _total;

  void _reset() => setState(() {
        _visible = 0;
        _offset = 0;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Sin velas para este intervalo.',
            style: EmText.label.copyWith(color: EmColors.textTertiary),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          // Pellizcar y arrastrar sobre el mismo gesto: en un gráfico, alejar
          // y correrse son la misma intención de "mostrame otra ventana".
          onScaleStart: (_) {
            _visibleAtGestureStart = _visible <= 0 ? _total.toDouble() : _visible;
            _offsetAtGestureStart = _offset;
          },
          onScaleUpdate: (d) {
            setState(() {
              if (d.scale != 1.0) {
                _visible = (_visibleAtGestureStart / d.scale)
                    .clamp(_minVisible, _total.toDouble());
              }
              final ancho = context.size?.width ?? 1;
              final porPixel = (_visible <= 0 ? _total : _visible) / ancho;
              _offset = (_offsetAtGestureStart - d.focalPointDelta.dx * porPixel)
                  .clamp(0.0, (_total - _visible).clamp(0.0, _total.toDouble()));
            });
          },
          onDoubleTap: _reset,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _CandlePainter(
                candles: _slice,
                livePrice: widget.livePrice,
                avgCost: widget.avgCost,
                orders: widget.orders,
              ),
            ),
          ),
        ),
        if (_zoomed)
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: _reset,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: EmColors.surfaceTop,
                  borderRadius: BorderRadius.circular(EmRadii.sm),
                ),
                child: Text(
                  '${_slice.length} velas · tocá para ver todo',
                  style: EmText.meta.copyWith(color: EmColors.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final double? livePrice;
  final double? avgCost;
  final List<OpenOrder> orders;

  /// Franja inferior para el volumen, como fracción del alto.
  static const _volumeShare = 0.18;
  static const _gap = 8.0;

  /// Ancho reservado a la escala de precios, a la derecha.
  static const _axisWidth = 54.0;

  _CandlePainter({
    required this.candles,
    this.livePrice,
    this.avgCost,
    this.orders = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _axisWidth;
    if (plotWidth <= 0) return;

    final volumeTop = size.height * (1 - _volumeShare);
    final priceHeight = volumeTop - _gap;

    // ── rango de precios ────────────────────────────────────────────────────
    var lo = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    var hi = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    // El PPC entra en el rango sólo si está cerca: si compraste al triple, la
    // línea no vale aplastar todas las velas contra un borde.
    final avg = avgCost;
    if (avg != null && avg > lo * 0.75 && avg < hi * 1.25) {
      lo = lo < avg ? lo : avg;
      hi = hi > avg ? hi : avg;
    }
    final span = (hi - lo).abs() < 1e-9 ? (hi.abs() * 0.01 + 1) : hi - lo;
    final pad = span * 0.06;
    lo -= pad;
    hi += pad;

    double yOf(double price) => priceHeight * (1 - (price - lo) / (hi - lo));

    // ── grilla y escala ─────────────────────────────────────────────────────
    final grid = Paint()
      ..color = EmColors.strokeSoft
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = priceHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), grid);
      _label(canvas, _money(hi - (hi - lo) * i / 4), plotWidth + 6, y);
    }

    // ── velas ───────────────────────────────────────────────────────────────
    final slot = plotWidth / candles.length;
    final body = (slot * 0.62).clamp(1.0, 14.0);

    var maxVol = candles.map((c) => c.volume).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVol <= 0) maxVol = 1;

    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final cx = slot * (i + 0.5);
      final color = c.isUp ? EmColors.up : EmColors.down;
      final paint = Paint()..color = color;

      // mecha
      canvas.drawRect(
        Rect.fromLTRB(cx - 0.5, yOf(c.high), cx + 0.5, yOf(c.low)),
        paint,
      );

      // cuerpo: nunca menos de un pelo, o una vela sin recorrido desaparece
      final top = yOf(c.open > c.close ? c.open : c.close);
      final bottom = yOf(c.open > c.close ? c.close : c.open);
      canvas.drawRect(
        Rect.fromLTRB(cx - body / 2, top, cx + body / 2,
            (bottom - top) < 1 ? top + 1 : bottom),
        paint,
      );

      // volumen, en la franja de abajo
      final vh = (size.height - volumeTop) * (c.volume / maxVol);
      canvas.drawRect(
        Rect.fromLTRB(cx - body / 2, size.height - vh, cx + body / 2, size.height),
        Paint()..color = color.withValues(alpha: 0.35),
      );
    }

    // ── referencias horizontales ────────────────────────────────────────────
    if (avg != null && avg >= lo && avg <= hi) {
      _dashed(canvas, yOf(avg), plotWidth, EmColors.flow);
      _label(canvas, _money(avg), plotWidth + 6, yOf(avg), color: EmColors.flow);
    }
    final live = livePrice;
    if (live != null && live >= lo && live <= hi) {
      final color = candles.last.isUp ? EmColors.up : EmColors.down;
      _dashed(canvas, yOf(live), plotWidth, color);
      _label(canvas, _money(live), plotWidth + 6, yOf(live), color: color);
    }

    // ── tus órdenes esperando ───────────────────────────────────────────────
    // Enteras y no punteadas: una orden puesta no es una referencia calculada,
    // es algo que va a pasar si el precio llega ahí.
    for (final o in orders) {
      final p = o.chartPrice;
      if (p == null || p < lo || p > hi) continue;
      final y = yOf(p);
      final color = o.isBuy ? EmColors.up : EmColors.down;
      canvas.drawLine(
        Offset(0, y),
        Offset(plotWidth, y),
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..strokeWidth = 1.2,
      );
      // Un triángulo en el borde: de qué lado empuja la orden.
      final path = Path();
      if (o.isBuy) {
        path.moveTo(0, y - 4);
        path.lineTo(6, y);
        path.lineTo(0, y + 4);
      } else {
        path.moveTo(0, y - 4);
        path.lineTo(6, y);
        path.lineTo(0, y + 4);
      }
      canvas.drawPath(path..close(), Paint()..color = color);
    }
  }

  void _dashed(Canvas canvas, double y, double width, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = 0.0; x < width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, width), y), paint);
    }
  }

  void _label(Canvas canvas, String text, double x, double y, {Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? EmColors.textMuted,
          fontSize: 9,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height / 2));
  }

  /// Cifras cortas: en una escala de 9 px, "80.979" gana a "80.979,50".
  String _money(double v) {
    final a = v.abs();
    if (a >= 1000) {
      return v
          .toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    }
    if (a >= 1) return v.toStringAsFixed(2).replaceAll('.', ',');
    return v.toStringAsFixed(a >= 0.01 ? 4 : 6).replaceAll('.', ',');
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) =>
      old.candles != candles ||
      old.livePrice != livePrice ||
      old.avgCost != avgCost ||
      old.orders != orders;
}
