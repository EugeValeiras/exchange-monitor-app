import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/chart_data.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';

/// Dominio vertical de una serie, calculado de forma ROBUSTA.
///
/// Un solo snapshot corrupto no puede inutilizar la pantalla principal: eso es
/// exactamente lo que pasaba antes, cuando el gráfico de 24 h se dibujaba con
/// `min`/`max` crudos y una lectura atípica se llevaba todo el rango vertical
/// dejando el resto de la serie como una línea plana.
///
/// El rango se calcula sobre el cuerpo de la distribución (rango intercuartil).
/// Las lecturas que quedan fuera NO se dibujan: la línea las saltea y une los
/// vecinos, porque clampearlas al borde inferior pintaba un pico vertical hasta
/// la base que no corresponde a nada. Se cuentan aparte, para poder decir que
/// las hay en vez de esconderlas.
class YDomain {
  final double min;
  final double max;
  final int clippedCount;

  const YDomain({required this.min, required this.max, this.clippedCount = 0});

  double get span => max - min;

  /// 0 en [min], 1 en [max]; recortado a [0,1].
  double normalize(double value) {
    if (span <= 0) return 0.5;
    return ((value - min) / span).clamp(0.0, 1.0);
  }

  bool isOutside(double value) => value < min || value > max;

  factory YDomain.robust(List<double> values, {double padding = 0.10}) {
    if (values.isEmpty) return const YDomain(min: 0, max: 1);

    final sorted = List<double>.from(values)..sort();
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;

    late double lo;
    late double hi;

    if (iqr > 0) {
      // Vallas amplias (3×IQR): sólo queremos descartar lo absurdo, no recortar
      // un movimiento real y fuerte del mercado.
      final fenceLo = q1 - 3 * iqr;
      final fenceHi = q3 + 3 * iqr;
      final inliers = sorted.where((v) => v >= fenceLo && v <= fenceHi).toList();
      if (inliers.isEmpty) {
        lo = sorted.first;
        hi = sorted.last;
      } else {
        lo = inliers.first;
        hi = inliers.last;
      }
    } else {
      lo = sorted.first;
      hi = sorted.last;
    }

    if (hi <= lo) {
      // Serie plana: un margen absoluto para que la línea no quede pegada al
      // borde ni el span sea cero.
      final pad = hi.abs() * 0.02 + 1;
      lo -= pad;
      hi += pad;
    } else {
      final pad = (hi - lo) * padding;
      lo -= pad;
      hi += pad;
    }

    final clipped = values.where((v) => v < lo || v > hi).length;
    return YDomain(min: lo, max: hi, clippedCount: clipped);
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final pos = (sorted.length - 1) * p;
    final lower = pos.floor();
    final upper = pos.ceil();
    if (lower == upper) return sorted[lower];
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (pos - lower);
  }
}

/// Gráfico de evolución de la cartera.
///
/// A diferencia del anterior: tiene escala visible (máximo y mínimo
/// etiquetados), extremos temporales, marca los movimientos de capital sobre el
/// eje y aguanta un dato corrupto sin volverse ilegible.
class EmBalanceChart extends StatefulWidget {
  final List<ChartPoint> points;
  final List<CapitalEvent> capitalEvents;
  final double height;

  /// Qué decir al pie sobre el origen del cambio (mercado o capital aportado).
  /// Va acá y no en una tarjeta aparte: es una nota sobre el gráfico.
  final String? footnote;

  /// Se llama al arrastrar sobre el gráfico con el punto tocado, y con null al
  /// soltar. La pantalla lo usa para reemplazar el número grande mientras dura
  /// el gesto.
  final void Function(ChartPoint? point)? onScrub;

  const EmBalanceChart({
    super.key,
    required this.points,
    this.capitalEvents = const [],
    this.height = 132,
    this.footnote,
    this.onScrub,
  });

  @override
  State<EmBalanceChart> createState() => _EmBalanceChartState();
}

class _EmBalanceChartState extends State<EmBalanceChart> {
  int? _activeIndex;

  /// El trazo llega a los dos bordes de la pantalla; este margen es sólo para
  /// que las etiquetas de escala y de tiempo no queden pegadas al canto.
  static const double _inset = EmSpace.screen;

  void _updateFromPosition(double dx, double width) {
    if (widget.points.length < 2) return;
    if (width <= 0) return;

    final ratio = (dx / width).clamp(0.0, 1.0);
    final index = (ratio * (widget.points.length - 1)).round();
    if (index == _activeIndex) return;

    final isFirst = _activeIndex == null;
    setState(() => _activeIndex = index);
    if (isFirst) HapticFeedback.selectionClick();
    widget.onScrub?.call(widget.points[index]);
  }

  void _end() {
    if (_activeIndex == null) return;
    setState(() => _activeIndex = null);
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;

    if (points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Sin datos para este período',
            style: EmText.label.copyWith(color: EmColors.textMuted),
          ),
        ),
      );
    }

    final values = points.map((p) => p.value).toList();
    final domain = YDomain.robust(values);
    final isUp = values.last >= values.first;
    final color = isUp ? EmColors.up : EmColors.down;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            // Dos formas de recorrerlo: arrastrando el dedo, o manteniendo
            // presionado. Se declaran como reconocedores propios porque el
            // gráfico vive dentro de una lista que scrollea — con un
            // GestureDetector común el scroll vertical se queda con el gesto
            // antes de que llegue acá. El de arrastre horizontal compite por
            // dirección y gana en cuanto el dedo se mueve de costado.
            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                HorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        HorizontalDragGestureRecognizer>(
                  HorizontalDragGestureRecognizer.new,
                  (instance) {
                    instance
                      ..onStart = (d) {
                        _updateFromPosition(d.localPosition.dx, width);
                      }
                      ..onUpdate = (d) {
                        _updateFromPosition(d.localPosition.dx, width);
                      }
                      ..onEnd = (_) {
                        _end();
                      }
                      ..onCancel = _end;
                  },
                ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                  LongPressGestureRecognizer.new,
                  (instance) {
                    instance
                      ..onLongPressStart = (d) {
                        _updateFromPosition(d.localPosition.dx, width);
                      }
                      ..onLongPressMoveUpdate = (d) {
                        _updateFromPosition(d.localPosition.dx, width);
                      }
                      ..onLongPressEnd = (_) {
                        _end();
                      }
                      ..onLongPressCancel = _end;
                  },
                ),
              },
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ChartPainter(
                    points: points,
                    domain: domain,
                    color: color,
                    activeIndex: _activeIndex,
                    capitalEvents: widget.capitalEvents,
                    inset: _inset,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: EmSpace.sm - 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _inset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_edgeLabel(points.first.timestamp), style: EmText.meta.copyWith(color: EmColors.textMuted)),
              Text('ahora', style: EmText.meta.copyWith(color: EmColors.textMuted)),
            ],
          ),
        ),
        if (widget.footnote != null || domain.clippedCount > 0)
          Padding(
            padding: const EdgeInsets.only(
              top: EmSpace.sm + 2,
              left: _inset,
              right: _inset,
            ),
            child: Row(
              children: [
                if (widget.capitalEvents.isNotEmpty) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: EmColors.flow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: EmSpace.sm - 2),
                ],
                Expanded(
                  child: Text(
                    _footnoteText(domain.clippedCount),
                    style: EmText.meta.copyWith(color: EmColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Una sola línea: es una nota al pie, no un párrafo. Los textos se eligen
  /// cortos para que entren en el ancho de la pantalla sin recortarse.
  String _footnoteText(int clipped) {
    final parts = <String>[
      if (widget.footnote != null) widget.footnote!,
      if (clipped == 1) '1 dato atípico fuera',
      if (clipped > 1) '$clipped datos atípicos fuera',
    ];
    return parts.join(' · ');
  }

  String _edgeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 36) return formatTime(dt);
    return formatDayShort(dt);
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final YDomain domain;
  final Color color;
  final int? activeIndex;
  final List<CapitalEvent> capitalEvents;

  /// Margen para el TEXTO. El trazo no lo usa: va de borde a borde.
  final double inset;
  final TextDirection textDirection;

  const _ChartPainter({
    required this.points,
    required this.domain,
    required this.color,
    required this.activeIndex,
    required this.capitalEvents,
    required this.inset,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const plotLeft = 0.0;
    final plotWidth = size.width;
    if (plotWidth <= 0) return;

    // Espacio reservado abajo para las marcas de capital sobre el eje.
    final markGutter = capitalEvents.isEmpty ? 0.0 : 10.0;
    final plotHeight = size.height - markGutter;

    double xAt(int i) => plotLeft + (i / (points.length - 1)) * plotWidth;
    double yAt(double v) => (1 - domain.normalize(v)) * plotHeight;

    _paintScaleLines(canvas, size, plotHeight);

    // Sólo las lecturas dentro del dominio entran en el dibujo: una atípica se
    // saltea y la línea une los vecinos.
    final drawn = <int>[
      for (var i = 0; i < points.length; i++)
        if (!domain.isOutside(points[i].value)) i,
    ];
    if (drawn.length < 2) return;

    // Área bajo la curva.
    final area = Path()..moveTo(xAt(drawn.first), yAt(points[drawn.first].value));
    for (final i in drawn.skip(1)) {
      area.lineTo(xAt(i), yAt(points[i].value));
    }
    area
      ..lineTo(xAt(drawn.last), plotHeight)
      ..lineTo(xAt(drawn.first), plotHeight)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, plotHeight),
          [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
        ),
    );

    // Línea.
    final line = Path()..moveTo(xAt(drawn.first), yAt(points[drawn.first].value));
    for (final i in drawn.skip(1)) {
      line.lineTo(xAt(i), yAt(points[i].value));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    _paintCapitalMarks(canvas, plotLeft, plotWidth, plotHeight, markGutter);

    // Punto final.
    canvas.drawCircle(
      Offset(xAt(drawn.last), yAt(points[drawn.last].value)),
      3,
      Paint()..color = color,
    );

    if (activeIndex != null && activeIndex! >= 0 && activeIndex! < points.length) {
      _paintCrosshair(canvas, xAt(activeIndex!), yAt(points[activeIndex!].value), plotHeight);
    }

    _paintScaleLabels(canvas, plotHeight);
  }

  void _paintScaleLines(Canvas canvas, Size size, double plotHeight) {
    final hairline = Paint()
      ..color = EmColors.strokeSoft
      ..strokeWidth = 1;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), hairline);
    canvas.drawLine(
      Offset(0, plotHeight - 1),
      Offset(size.width, plotHeight - 1),
      hairline,
    );
  }

  /// Las etiquetas muestran el rango DIBUJADO, no el mínimo y máximo crudos: el
  /// gráfico no puede prometer una escala que no está usando. Van dentro del
  /// área —con el trazo a todo lo ancho no hay una columna al costado— y se
  /// pintan AL FINAL, encima de la serie: si no, la línea las cruzaba y el
  /// número quedaba cortado por la mitad.
  void _paintScaleLabels(Canvas canvas, double plotHeight) {
    _paintText(canvas, formatCompactMoney(domain.max), Offset(inset, 3));
    _paintText(
      canvas,
      formatCompactMoney(domain.min),
      Offset(inset, plotHeight - 17),
    );
  }

  /// Cuántas marcas caben sin que el eje se vuelva una franja. Con un año de
  /// historia hay decenas de movimientos y dibujarlos todos no informa nada:
  /// se muestran los de mayor monto, que son los que explican los saltos de la
  /// curva, y el aviso de abajo dice cuántos hay en total.
  static const int _maxMarks = 10;

  List<CapitalEvent> get _marksToPaint {
    if (capitalEvents.length <= _maxMarks) return capitalEvents;
    final sorted = List<CapitalEvent>.from(capitalEvents)
      ..sort((a, b) {
        final av = a.usdValue ?? 0;
        final bv = b.usdValue ?? 0;
        if (av == bv) return b.timestamp.compareTo(a.timestamp);
        return bv.compareTo(av);
      });
    return sorted.take(_maxMarks).toList();
  }

  void _paintCapitalMarks(
    Canvas canvas,
    double plotLeft,
    double plotWidth,
    double plotHeight,
    double markGutter,
  ) {
    if (capitalEvents.isEmpty || points.length < 2) return;

    final start = points.first.timestamp.millisecondsSinceEpoch;
    final end = points.last.timestamp.millisecondsSinceEpoch;
    final span = (end - start).toDouble();
    if (span <= 0) return;

    final paint = Paint()..color = EmColors.flow;

    for (final event in _marksToPaint) {
      final t = event.timestamp.millisecondsSinceEpoch;
      final ratio = ((t - start) / span).clamp(0.0, 1.0);
      final x = plotLeft + ratio * plotWidth;
      final y = plotHeight + markGutter * 0.5;

      // Triangulito hacia arriba si entró plata, hacia abajo si salió.
      final path = Path();
      if (event.isDeposit) {
        path.moveTo(x, y - 3.5);
        path.lineTo(x + 3, y + 2.5);
        path.lineTo(x - 3, y + 2.5);
      } else {
        path.moveTo(x, y + 3.5);
        path.lineTo(x + 3, y - 2.5);
        path.lineTo(x - 3, y - 2.5);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintCrosshair(Canvas canvas, double x, double y, double plotHeight) {
    final paint = Paint()
      ..color = EmColors.strokeStrong
      ..strokeWidth = 1;

    // Punteado a mano: dashPath no está en el framework.
    const dash = 4.0;
    const gap = 4.0;
    var current = 0.0;
    while (current < plotHeight) {
      canvas.drawLine(
        Offset(x, current),
        Offset(x, math.min(current + dash, plotHeight)),
        paint,
      );
      current += dash + gap;
    }

    canvas.drawCircle(Offset(x, y), 5, Paint()..color = EmColors.bg);
    canvas.drawCircle(
      Offset(x, y),
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: EmText.meta.copyWith(
          color: EmColors.textMuted,
          fontSize: 11,
          // Halo del color del lienzo: con el trazo a todo lo ancho las
          // etiquetas de escala viven DENTRO del área, y cuando la serie pasa
          // por su altura el número quedaba cortado por la línea.
          shadows: const [
            Shadow(color: EmColors.bg, blurRadius: 4),
            Shadow(color: EmColors.bg, blurRadius: 4),
            Shadow(color: EmColors.bg, blurRadius: 2),
          ],
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.activeIndex != activeIndex ||
      old.color != color ||
      old.domain.min != domain.min ||
      old.domain.max != domain.max ||
      old.capitalEvents != capitalEvents;
}
