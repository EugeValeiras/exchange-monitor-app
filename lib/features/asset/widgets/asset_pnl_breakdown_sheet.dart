import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/pnl.dart';
import '../../../core/services/pnl_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../lot_grouping.dart';

/// Qué resultado del activo se está desarmando.
enum AssetPnlKind {
  /// Lo que llevás sobre lo que todavía tenés: sus lotes de compra abiertos.
  unrealized,

  /// Lo que quedó de las ventas ya cerradas.
  realized,
}

/// De qué operaciones está hecho el resultado de UN activo.
///
/// El hermano de `PnlBreakdownSheet`, un nivel más abajo: aquel desarma la
/// cartera por activo, éste desarma un activo por operación. "−$4.017" no dice
/// si fue una venta cara o veinte chicas; acá se ve cuál.
class AssetPnlBreakdownSheet extends StatefulWidget {
  final String asset;
  final AssetPnlKind kind;

  /// El total que muestra el card, tal como lo dio la API.
  ///
  /// Se muestra en el encabezado en lugar de la suma de las filas: recalcularlo
  /// acá con el precio que tiene la app en este segundo daría centavos de
  /// diferencia con la pantalla de atrás, y dos números distintos para la misma
  /// cosa es peor que un número.
  final double? total;

  /// Precio de ahora, para valuar lo que queda de cada lote.
  final double? price;

  const AssetPnlBreakdownSheet({
    super.key,
    required this.asset,
    required this.kind,
    this.total,
    this.price,
  });

  static Future<void> show(
    BuildContext context, {
    required String asset,
    required AssetPnlKind kind,
    double? total,
    double? price,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EmColors.surface,
      builder: (_) => AssetPnlBreakdownSheet(
        asset: asset,
        kind: kind,
        total: total,
        price: price,
      ),
    );
  }

  @override
  State<AssetPnlBreakdownSheet> createState() => _AssetPnlBreakdownSheetState();
}

class _AssetPnlBreakdownSheetState extends State<AssetPnlBreakdownSheet> {
  List<CostBasisLot>? _lots;
  List<RealizedPnlItem>? _sales;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final pnl = context.read<PnlService>();
    try {
      switch (widget.kind) {
        case AssetPnlKind.unrealized:
          final lots = await pnl.lotsFor(widget.asset);
          if (!mounted) return;
          setState(() {
            _lots = lots;
            _loading = false;
          });
        case AssetPnlKind.realized:
          final sales = await pnl.realizedFor(widget.asset);
          if (!mounted) return;
          setState(() {
            _sales = sales;
            _loading = false;
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el detalle.';
        _loading = false;
      });
    }
  }

  String get _title => switch (widget.kind) {
        AssetPnlKind.unrealized => 'No realizado',
        AssetPnlKind.realized => 'Realizado',
      };

  String get _subtitle => switch (widget.kind) {
        AssetPnlKind.unrealized =>
          'Cada compra de ${assetName(widget.asset)} que todavía tenés, contra el '
              'precio de ahora. La contabilidad es FIFO: las ventas se comen '
              'primero los lotes más viejos, y esto es lo que sobrevivió.',
        AssetPnlKind.realized =>
          'Cada venta de ${assetName(widget.asset)} ya cerrada, contra lo que '
              'habían costado los lotes que consumió.',
      };

  String get _sectionTitle => switch (widget.kind) {
        AssetPnlKind.unrealized => 'Lotes abiertos',
        AssetPnlKind.realized => 'Ventas',
      };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: EmSpace.md, bottom: EmSpace.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: EmColors.strokeStrong,
                borderRadius: BorderRadius.circular(EmRadii.pill),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  EmSpace.screen,
                  EmSpace.sm,
                  EmSpace.screen,
                  EmSpace.xxl,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_title, style: EmText.title),
                            const SizedBox(height: 2),
                            Text(
                              assetName(widget.asset),
                              style: EmText.meta,
                            ),
                          ],
                        ),
                      ),
                      if (widget.total != null)
                        Text(
                          formatSignedUsd(widget.total!),
                          style: EmText.title
                              .copyWith(color: EmDelta.colorFor(widget.total)),
                        ),
                    ],
                  ),
                  const SizedBox(height: EmSpace.sm),
                  Text(
                    _subtitle,
                    style: EmText.body.copyWith(color: EmColors.textTertiary),
                  ),
                  const SizedBox(height: EmSpace.xl),
                  ..._body(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: EmSpace.xxl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: EmSpace.xl),
          child: Column(
            children: [
              Text(
                _error!,
                style: EmText.label.copyWith(color: EmColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: EmSpace.md),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      ];
    }

    return switch (widget.kind) {
      AssetPnlKind.unrealized => _lotRows(),
      AssetPnlKind.realized => _saleRows(),
    };
  }

  List<Widget> _lotRows() {
    final lots = _lots ?? const <CostBasisLot>[];
    if (lots.isEmpty) {
      return [_empty('No hay lotes de compra abiertos para este activo.')];
    }

    final price = widget.price;
    // Los fills de una compra son una compra. Sin esto, una orden ejecutada en
    // 47 pedazos son 47 filas idénticas y el panel deja de decir nada.
    final groups = groupLots(lots);

    // Ordenados por lo que pesan, no por fecha: lo que explica el número va
    // primero, sin importar el signo.
    final sorted = [...groups];
    if (price != null) {
      sorted.sort((a, b) =>
          b.unrealizedAt(price).abs().compareTo(a.unrealizedAt(price).abs()));
    }

    return [
      EmSectionHeader(title: _sectionLabel(groups.length, lots.length)),
      for (final group in sorted)
        EmListRow(
          title: _rowTitle(
            formatAssetQuantity(group.remainingAmount, widget.asset),
            group.exchange,
          ),
          subtitle: _lotSubtitle(group),
          subtitleMaxLines: 2,
          value:
              price == null ? null : formatSignedUsd(group.unrealizedAt(price)),
          valueBelow: price == null || group.remainingCost <= 0
              ? null
              : EmDelta(
                  percent:
                      (group.unrealizedAt(price) / group.remainingCost) * 100,
                  fontSize: 12,
                  showMark: false,
                ),
          showDivider: group != sorted.last,
        ),
    ];
  }

  /// La cantidad y dónde está, juntas: el exchange es parte de qué es esta
  /// fila, no un dato más de la letra chica — y bajarlo dejaba al precio y al
  /// mercado peleando por el final de una línea que no alcanzaba.
  String _rowTitle(String amount, String exchange) =>
      exchange.isEmpty ? amount : '$amount · ${formatExchangeName(exchange)}';

  String _lotSubtitle(LotGroup group) {
    final parts = <String>[
      // Con la hora, porque dos órdenes del mismo día son dos filas que dicen
      // "25 ene" y sólo la hora las distingue.
      formatDateTimeShort(group.acquiredAt),
      if (group.isGrouped) '${group.count} operaciones',
      'a ${formatMoney(group.costPerUnit)}',
      // Un lote comido a medias explica por qué su cantidad no coincide con
      // ninguna compra de la lista de movimientos.
      if (group.isPartial) 'quedan ${group.remainingPercent}%',
      if (group.pair != null && group.pair!.isNotEmpty) 'vía ${group.pair}',
    ];
    return parts.join(' · ');
  }

  /// "Lotes abiertos · 3" cuando cada fila es un lote; "· 3 de 47" cuando las
  /// filas agrupan fills, para que el conteo no contradiga a la contabilidad.
  String _sectionLabel(int rows, int total) =>
      rows == total ? '$_sectionTitle · $rows' : '$_sectionTitle · $rows de $total';

  List<Widget> _saleRows() {
    final sales = _sales ?? const <RealizedPnlItem>[];
    if (sales.isEmpty) {
      return [_empty('Todavía no cerraste ninguna venta de este activo.')];
    }

    final groups = groupSales(sales);
    final sorted = [...groups]
      ..sort((a, b) => b.realizedPnl.abs().compareTo(a.realizedPnl.abs()));

    return [
      EmSectionHeader(title: _sectionLabel(groups.length, sales.length)),
      for (final group in sorted)
        EmListRow(
          title: _rowTitle(
            formatAssetQuantity(group.amount, widget.asset),
            group.exchange,
          ),
          subtitle: _saleSubtitle(group),
          subtitleMaxLines: 2,
          value: formatSignedUsd(group.realizedPnl),
          valueBelow: group.percent == null
              ? null
              : EmDelta(percent: group.percent, fontSize: 12, showMark: false),
          showDivider: group != sorted.last,
        ),
    ];
  }

  String _saleSubtitle(SaleGroup group) {
    final parts = <String>[
      formatDateTimeShort(group.realizedAt),
      if (group.isGrouped) '${group.count} operaciones',
      // El precio de compra y el de venta juntos son la operación entera: sin
      // el primero, el resultado es un número sin origen.
      '${formatMoney(group.buyPrice)} → ${formatMoney(group.sellPrice)}',
    ];
    return parts.join(' · ');
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: EmSpace.xl),
        child: Text(
          text,
          style: EmText.label.copyWith(color: EmColors.textTertiary),
        ),
      );
}
