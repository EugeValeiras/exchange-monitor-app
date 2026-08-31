import 'package:flutter/material.dart';

import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';

/// Encabezado de sección: "ACTIVOS · 4 · 3 exchanges".
class EmSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const EmSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title.toUpperCase(), style: EmText.section),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                trailing!,
                style: EmText.meta.copyWith(
                  color: onTrailingTap != null
                      ? EmColors.textSecondary
                      : EmColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Triangulito de dirección. Un glyph de fuente cambia de tamaño y de peso
/// óptico entre plataformas; dibujarlo lo deja igual en todos lados.
class EmDirectionMark extends StatelessWidget {
  final bool isUp;
  final Color color;
  final double size;

  const EmDirectionMark({
    super.key,
    required this.isUp,
    required this.color,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.72),
      painter: _TrianglePainter(isUp: isUp, color: color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final Color color;

  const _TrianglePainter({required this.isUp, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.isUp != isUp || old.color != color;
}

/// Variación de valor. Único lugar del sistema autorizado a usar verde y rojo.
///
/// Un cambio de cero no es "positivo": se pinta neutro, porque teñirlo de verde
/// haría leer como ganancia una moneda estable que no se movió.
class EmDelta extends StatelessWidget {
  final double? percent;
  final double? usd;
  final String? suffix;
  final double fontSize;
  final bool showMark;

  const EmDelta({
    super.key,
    this.percent,
    this.usd,
    this.suffix,
    this.fontSize = 15,
    this.showMark = true,
  });

  /// Un valor que redondea a cero con los decimales que se muestran NO es una
  /// caída: pintarlo de rojo con un "−0,00%" es ruido. Se lee neutro.
  static Color colorFor(double? value, {int decimals = 2}) {
    if (value == null) return EmColors.textTertiary;
    final rounded = double.parse(value.toStringAsFixed(decimals));
    if (rounded == 0) return EmColors.textTertiary;
    return rounded > 0 ? EmColors.up : EmColors.down;
  }

  static bool _roundsToZero(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals)) == 0;

  @override
  Widget build(BuildContext context) {
    final reference = usd ?? percent;
    if (reference == null) {
      return Text('—', style: EmText.meta.copyWith(fontSize: fontSize));
    }

    final color = colorFor(reference);
    final isNeutral = _roundsToZero(reference, 2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (showMark && !isNeutral) ...[
          Padding(
            padding: const EdgeInsets.only(right: EmSpace.sm),
            child: EmDirectionMark(
              isUp: reference > 0,
              color: color,
              size: fontSize * 0.7,
            ),
          ),
        ],
        if (usd != null)
          Text(
            formatMoney(usd!.abs()),
            style: EmText.data.copyWith(fontSize: fontSize, color: color),
          ),
        if (usd != null && percent != null) const SizedBox(width: EmSpace.sm),
        if (percent != null)
          Text(
            isNeutral ? formatPercent(percent!) : formatSignedPercent(percent!),
            style: EmText.data.copyWith(
              fontSize: fontSize,
              fontWeight: usd != null ? FontWeight.w500 : FontWeight.w600,
              color: color,
            ),
          ),
        if (suffix != null) ...[
          const SizedBox(width: EmSpace.sm),
          Text(suffix!, style: EmText.meta.copyWith(color: EmColors.textMuted)),
        ],
      ],
    );
  }
}

/// Disco neutro con el ticker, para cuando no hay logo del activo.
///
/// Las listas usan [AssetLogo]; esto es el respaldo tipográfico para una moneda
/// sin SVG, y para contextos donde el logo no aporta (una fila de exchange, por
/// ejemplo).
class EmAssetAvatar extends StatelessWidget {
  final String asset;
  final double size;

  const EmAssetAvatar({super.key, required this.asset, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final ticker = asset.toUpperCase();
    // El cuerpo tipográfico baja con tickers largos para que STETH entre en el
    // mismo disco que BTC sin recortarse.
    final fontSize = switch (ticker.length) {
      <= 3 => size * 0.33,
      4 => size * 0.30,
      _ => size * 0.25,
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: EmColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: EmColors.stroke)),
      ),
      child: Text(
        ticker.length > 5 ? ticker.substring(0, 5) : ticker,
        style: EmText.data.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: EmColors.textSecondary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Cuadradito de ícono de una fila de movimiento.
class EmIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool tinted;

  const EmIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
    this.tinted = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tinted ? EmColors.wash(color) : EmColors.surfaceHigh,
        borderRadius: BorderRadius.circular(EmRadii.sm),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Tarjeta de dato: un número y su etiqueta.
class EmStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  /// Cuando el dato se puede abrir para ver de qué está hecho. El card lo
  /// anuncia con un chevron al lado de la etiqueta: sin eso, tres cards
  /// idénticos donde sólo algunos responden al toque son una lotería.
  final VoidCallback? onTap;

  const EmStat({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: EmSpace.md + 1,
          vertical: EmSpace.md - 1,
        ),
        decoration: BoxDecoration(
          color: EmColors.surface,
          borderRadius: BorderRadius.circular(EmRadii.control),
          border: Border.all(color: EmColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: EmText.headline.copyWith(color: valueColor ?? EmColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: EmText.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 13,
                    color: EmColors.textMuted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector segmentado. Seleccionar es ACLARAR: la opción activa sube un
/// escalón de superficie y firma el borde, nunca se tiñe.
class EmSegmented<T> extends StatelessWidget {
  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const EmSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                // 44 pt de alto: es un blanco de toque, no una etiqueta.
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: option.value == selected
                      ? EmColors.surfaceTop
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(EmRadii.sm),
                  border: Border.all(
                    color: option.value == selected
                        ? EmColors.strokeStrong
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  option.label,
                  style: EmText.label.copyWith(
                    fontWeight:
                        option.value == selected ? FontWeight.w600 : FontWeight.w500,
                    color: option.value == selected
                        ? EmColors.textPrimary
                        : EmColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          if (option != options.last) const SizedBox(width: EmSpace.xs + 2),
        ],
      ],
    );
  }
}

/// Chip de filtro. Mismo criterio de selección que [EmSegmented].
class EmChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  const EmChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: EmSpace.md + 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? EmColors.surfaceTop : Colors.transparent,
          borderRadius: BorderRadius.circular(EmRadii.pill),
          border: Border.all(
            color: selected ? EmColors.strokeStrong : EmColors.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: EmSpace.sm),
            ],
            Text(
              label,
              style: EmText.label.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? EmColors.textPrimary : EmColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de lista densa: 64 pt en vez de los ~150 de las tarjetas viejas.
/// Con cuatro activos, la cartera entera entra en una pantalla.
class EmListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final Widget? valueBelow;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool showChevron;

  const EmListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.valueBelow,
    this.onTap,
    this.showDivider = true,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 44 pt mínimos de alto útil aun sin subtítulo.
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: EmSpace.md),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: EmColors.strokeSoft)),
              )
            : null,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: EmSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: EmText.rowLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: EmText.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (value != null || valueBelow != null) ...[
              const SizedBox(width: EmSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null) Text(value!, style: EmText.data),
                  if (valueBelow != null) ...[
                    const SizedBox(height: 2),
                    valueBelow!,
                  ],
                ],
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: EmSpace.sm),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: EmSpace.sm),
              const Icon(Icons.chevron_right, size: 18, color: EmColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vacío, sin el disco gigante de antes.
class EmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EmSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: EmColors.textMuted),
            const SizedBox(height: EmSpace.lg),
            Text(title, style: EmText.headline, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: EmSpace.sm),
              Text(
                subtitle!,
                style: EmText.body.copyWith(color: EmColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: EmSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Aviso discreto: una línea con un hairline alrededor. Para cuando la app
/// tiene algo que aclarar sin gritarlo.
class EmNotice extends StatelessWidget {
  final String text;
  final Color? accent;
  final Widget? trailing;

  const EmNotice({super.key, required this.text, this.accent, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EmSpace.md + 1,
        vertical: EmSpace.md - 1,
      ),
      decoration: BoxDecoration(
        color: EmColors.surface,
        borderRadius: BorderRadius.circular(EmRadii.control),
        border: Border.all(color: EmColors.stroke),
      ),
      child: Row(
        children: [
          if (accent != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: EmSpace.sm + 2),
          ],
          Expanded(
            child: Text(text, style: EmText.label.copyWith(height: 1.35)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: EmSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
