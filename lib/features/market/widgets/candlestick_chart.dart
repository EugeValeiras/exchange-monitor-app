import 'package:flutter/material.dart';
import '../../../core/models/market.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import 'chart_viewport.dart';

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
  ChartViewport _view = const ChartViewport(total: 0);
  double _scaleAlEmpezar = 1;

  /// La vela que estás tocando y a qué altura: el crosshair.
  int? _cruzIndex;
  double? _cruzY;

  /// Ancho que ocupa la escala de precios: no es zona de velas, y contarla
  /// hacía que el arrastre corriera de más.
  static const _axisWidth = 54.0;

  @override
  void initState() {
    super.initState();
    _view = ChartViewport(total: widget.candles.length);
  }

  @override
  void didUpdateWidget(CandlestickChart old) {
    super.didUpdateWidget(old);
    // Llega una vela nueva: la ventana se adapta sin perder dónde estabas.
    if (old.candles.length != widget.candles.length) {
      _view = _view.withTotal(widget.candles.length);
    }
  }

  List<Candle> get _slice => _view.slice(widget.candles);

  void _reset() => setState(() => _view = _view.reset());

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

    final tocada = _cruzIndex != null && _cruzIndex! < _slice.length
        ? _slice[_cruzIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Una sola franja arriba del gráfico, fuera de las velas: cuando tocás
        // muestra la vela, cuando hay zoom ofrece salir, y si no, nada. Antes
        // el cartel flotaba encima de los datos y tapaba justo lo que mirabas.
        SizedBox(
          height: 18,
          child: tocada != null
              ? _lectura(tocada)
              : _view.isZoomed
                  ? _salidaDelZoom()
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          // Pellizcar y arrastrar sobre el mismo gesto: en un gráfico, alejar
          // y correrse son la misma intención de "mostrame otra ventana".
          onScaleStart: (_) => _scaleAlEmpezar = 1,
          onScaleUpdate: (d) {
            setState(() {
              // El zoom llega acumulado desde el inicio del gesto; el arrastre,
              // como delta de este frame. Cada uno se aplica como corresponde:
              // mezclarlos era lo que dejaba el arrastre sin efecto.
              if (d.scale != _scaleAlEmpezar && d.scale > 0) {
                _view = _view.zoom(d.scale / _scaleAlEmpezar);
                _scaleAlEmpezar = d.scale;
              }
              final ancho = (context.size?.width ?? _axisWidth * 2) - _axisWidth;
              _view = _view.pan(-d.focalPointDelta.dx * _view.candlesPerPixel(ancho));
            });
          },
          onDoubleTap: _reset,
          // Mantener apretado saca el crosshair; mover el dedo sin frenar
          // arrastra el gráfico. Es la misma división que hace Binance: quien
          // se queda quieto quiere leer, quien se mueve quiere navegar.
          onLongPressStart: (d) => _cruz(d.localPosition),
          onLongPressMoveUpdate: (d) => _cruz(d.localPosition),
          onLongPressEnd: (_) => setState(() {
            _cruzIndex = null;
            _cruzY = null;
          }),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _CandlePainter(
                candles: _slice,
                livePrice: widget.livePrice,
                avgCost: widget.avgCost,
                orders: widget.orders,
                crosshairIndex: _cruzIndex,
                crosshairY: _cruzY,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _cruz(Offset p) {
    final ancho = (context.size?.width ?? _axisWidth * 2) - _axisWidth;
    setState(() {
      _cruzIndex = _view.candleAt(p.dx, ancho);
      _cruzY = p.dy;
    });
  }

  /// Lo que dice una vela: apertura, máximo, mínimo y cierre.
  Widget _lectura(Candle c) {
    final sube = c.isUp;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            formatDayShort(c.time),
            style: EmText.section.copyWith(color: EmColors.textTertiary),
          ),
          const SizedBox(width: EmSpace.sm),
          for (final par in [
            ('A', c.open),
            ('M', c.high),
            ('m', c.low),
            ('C', c.close),
          ]) ...[
            Text('${par.$1} ',
                style: EmText.section.copyWith(color: EmColors.textMuted)),
            Text(
              _corto(par.$2),
              style: EmText.meta.copyWith(
                color: sube ? EmColors.up : EmColors.down,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: EmSpace.sm),
          ],
        ],
      ),
    );
  }

  Widget _salidaDelZoom() => GestureDetector(
        onTap: _reset,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_slice.length} velas',
              style: EmText.section.copyWith(color: EmColors.textTertiary),
            ),
            const SizedBox(width: EmSpace.xs),
            Text(
              '· ver todo',
              style: EmText.section.copyWith(color: EmColors.textSecondary),
            ),
          ],
        ),
      );

  String _corto(double v) {
    final a = v.abs();
    if (a >= 1000) {
      return v
          .toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    }
    return v.toStringAsFixed(a >= 1 ? 2 : 6).replaceAll('.', ',');
  }
}

class _CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final double? livePrice;
  final double? avgCost;
  final List<OpenOrder> orders;
  final int? crosshairIndex;
  final double? crosshairY;

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
    this.crosshairIndex,
    this.crosshairY,
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

    // ── crosshair ───────────────────────────────────────────────────────────
    // Vertical sobre la vela que tocás; horizontal a la altura del dedo, con
    // el precio de ESA altura en la escala: leer un nivel cualquiera del
    // gráfico es la mitad de para qué sirve tocar.
    final ci = crosshairIndex;
    if (ci != null && ci >= 0 && ci < candles.length) {
      final cx = slot * (ci + 0.5);
      final cruz = Paint()
        ..color = EmColors.textSecondary
        ..strokeWidth = 1;

      for (var y = 0.0; y < priceHeight; y += 6) {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + 3), cruz);
      }

      final cy = crosshairY;
      if (cy != null && cy >= 0 && cy <= priceHeight) {
        for (var x = 0.0; x < plotWidth; x += 6) {
          canvas.drawLine(Offset(x, cy), Offset(x + 3, cy), cruz);
        }
        // El precio a esa altura, sobre fondo opaco para que no se pierda
        // entre las etiquetas de la escala.
        final precio = hi - (cy / priceHeight) * (hi - lo);
        final tp = TextPainter(
          text: TextSpan(
            text: _money(precio),
            style: const TextStyle(
              color: EmColors.bg,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final r = Rect.fromLTWH(plotWidth + 3, cy - 7, tp.width + 6, 14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()..color = EmColors.textSecondary,
        );
        tp.paint(canvas, Offset(plotWidth + 6, cy - tp.height / 2));
      }
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
      old.orders != orders ||
      old.crosshairIndex != crosshairIndex ||
      old.crosshairY != crosshairY;
}
