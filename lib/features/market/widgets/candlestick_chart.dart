import 'package:flutter/material.dart';
import '../../../core/models/market.dart';
import '../../../core/theme/em_tokens.dart';

/// Velas japonesas.
///
/// Dibujadas a mano y no con fl_chart: una vela es cuatro números en una barra
/// con mecha, y ninguna librería de líneas lo hace sin pelear. Además así el
/// volumen comparte el eje horizontal exacto del precio, que es la mitad de
/// para qué sirve mirarlos juntos.
class CandlestickChart extends StatelessWidget {
  final List<Candle> candles;

  /// El precio en vivo, para la línea punteada del último valor.
  final double? livePrice;

  /// Tu costo promedio, si tenés posición: la referencia contra la que mirás.
  final double? avgCost;

  final double height;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.livePrice,
    this.avgCost,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Sin velas para este intervalo.',
            style: EmText.label.copyWith(color: EmColors.textTertiary),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CandlePainter(
          candles: candles,
          livePrice: livePrice,
          avgCost: avgCost,
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final double? livePrice;
  final double? avgCost;

  /// Franja inferior para el volumen, como fracción del alto.
  static const _volumeShare = 0.18;
  static const _gap = 8.0;

  /// Ancho reservado a la escala de precios, a la derecha.
  static const _axisWidth = 54.0;

  _CandlePainter({required this.candles, this.livePrice, this.avgCost});

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
      old.candles != candles || old.livePrice != livePrice || old.avgCost != avgCost;
}
