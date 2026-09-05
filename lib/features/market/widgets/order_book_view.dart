import 'package:flutter/material.dart';
import '../../../core/models/market.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';

/// El libro de órdenes: quién está dispuesto a comprar y a vender, y por cuánto.
///
/// Las dos columnas comparten una misma escala de profundidad —la barra de
/// fondo mide la cantidad acumulada, no la de esa fila— porque lo que dice algo
/// no es un nivel suelto sino dónde se apila la oferta.
class OrderBookView extends StatelessWidget {
  final OrderBook? book;
  final int levels;
  final bool live;

  const OrderBookView({
    super.key,
    required this.book,
    this.levels = 12,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = book;
    if (b == null || (b.bids.isEmpty && b.asks.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: EmSpace.xl),
        child: Center(
          child: Text(
            'Sin libro para este par.',
            style: EmText.label.copyWith(color: EmColors.textTertiary),
          ),
        ),
      );
    }

    final bids = b.bids.take(levels).toList();
    final asks = b.asks.take(levels).toList();

    // El acumulado más grande de los dos lados manda la escala, para que las
    // barras de compra y de venta se puedan comparar entre sí.
    double top = 0;
    for (final side in [bids, asks]) {
      var acc = 0.0;
      for (final l in side) {
        acc += l.amount;
        if (acc > top) top = acc;
      }
    }
    if (top <= 0) top = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _spread(b),
        const SizedBox(height: EmSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _side(bids, top, buy: true)),
            const SizedBox(width: EmSpace.md),
            Expanded(child: _side(asks, top, buy: false)),
          ],
        ),
      ],
    );
  }

  Widget _spread(OrderBook b) {
    final s = b.spread;
    final pct = b.spreadPct;
    return Row(
      children: [
        Text('SPREAD', style: EmText.section.copyWith(color: EmColors.textTertiary)),
        const SizedBox(width: EmSpace.sm),
        Text(
          s == null ? '—' : formatAssetAmount(s),
          style: EmText.data.copyWith(fontSize: 13),
        ),
        if (pct != null) ...[
          const SizedBox(width: EmSpace.xs),
          Text(
            '(${pct.toStringAsFixed(3).replaceAll('.', ',')} %)',
            style: EmText.meta.copyWith(color: EmColors.textTertiary),
          ),
        ],
        const Spacer(),
        if (live)
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: EmColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: EmSpace.xs),
              Text(
                'EN VIVO',
                style: EmText.section.copyWith(color: EmColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }

  Widget _side(List<BookLevel> levels, double top, {required bool buy}) {
    final color = buy ? EmColors.up : EmColors.down;
    var acc = 0.0;
    final rows = <Widget>[];

    for (final l in levels) {
      acc += l.amount;
      rows.add(
        SizedBox(
          height: 20,
          child: Stack(
            alignment: buy ? Alignment.centerRight : Alignment.centerLeft,
            children: [
              // La barra crece hacia el centro: los mejores precios quedan
              // pegados a la línea que separa las dos columnas.
              FractionallySizedBox(
                widthFactor: (acc / top).clamp(0.0, 1.0),
                child: Container(
                  height: 20,
                  color: color.withValues(alpha: 0.10),
                ),
              ),
              Row(
                mainAxisAlignment:
                    buy ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceBetween,
                children: buy
                    ? [
                        Text(formatAssetAmount(l.amount),
                            style: EmText.meta.copyWith(color: EmColors.textSecondary)),
                        Text(formatAssetAmount(l.price),
                            style: EmText.meta.copyWith(color: color)),
                      ]
                    : [
                        Text(formatAssetAmount(l.price),
                            style: EmText.meta.copyWith(color: color)),
                        Text(formatAssetAmount(l.amount),
                            style: EmText.meta.copyWith(color: EmColors.textSecondary)),
                      ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: buy
              ? [
                  Text('CANTIDAD', style: EmText.section.copyWith(color: EmColors.textMuted)),
                  Text('COMPRA', style: EmText.section.copyWith(color: EmColors.textMuted)),
                ]
              : [
                  Text('VENTA', style: EmText.section.copyWith(color: EmColors.textMuted)),
                  Text('CANTIDAD', style: EmText.section.copyWith(color: EmColors.textMuted)),
                ],
        ),
        const SizedBox(height: EmSpace.xs),
        ...rows,
      ],
    );
  }
}
