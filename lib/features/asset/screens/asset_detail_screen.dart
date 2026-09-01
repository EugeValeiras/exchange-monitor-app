import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/balance.dart';
import '../../../core/models/transaction.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/pnl_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../../movements/widgets/movement_row.dart';
import '../widgets/asset_pnl_breakdown_sheet.dart';

/// Detalle de un activo.
///
/// Pantalla nueva: antes tocar un activo no hacía nada. Es donde entra el P&L
/// que la API ya calculaba y la app nunca pidió —precio promedio de compra,
/// resultado realizado y no realizado— y el reparto por exchange, que la lista
/// insinuaba con logos apilados sin decir cuánto había en cada uno.
class AssetDetailScreen extends StatefulWidget {
  final String asset;

  const AssetDetailScreen({super.key, required this.asset});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Future<List<Transaction>> _movements;

  @override
  void initState() {
    super.initState();
    _movements = _loadMovements();
  }

  Future<List<Transaction>> _loadMovements() async {
    final api = context.read<ApiService>();
    final response = await api.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {'assets': widget.asset, 'limit': '8', 'page': '1'},
    );
    return PaginatedTransactions.fromJson(response).data;
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<BalanceService>();
    final prices = context.watch<PriceService>();
    final pnl = context.watch<PnlService>();

    final asset = balance.assets.firstWhere(
      (a) => a.asset.toUpperCase() == widget.asset.toUpperCase(),
      orElse: () => AssetBalance(asset: widget.asset, free: 0, locked: 0, total: 0),
    );

    final price = prices.getPriceByAsset(widget.asset) ?? asset.priceUsd;
    final change = prices.getChange24hByAsset(widget.asset) ?? asset.change24h;
    final value = asset.valueUsd ?? (price != null ? asset.total * price : null);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [_favoriteButton(context)],
        title: Row(
          children: [
            // La marca del activo vive acá y sólo acá: en las listas competiría
            // con el verde y el rojo, que son los que informan.
            AssetLogo(asset: widget.asset, size: 26),
            const SizedBox(width: EmSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(assetName(widget.asset), style: EmText.headline),
                Text(widget.asset.toUpperCase(), style: EmText.meta),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EmSpace.screen,
          EmSpace.sm,
          EmSpace.screen,
          EmSpace.xxl,
        ),
        children: [
          _position(asset, value, change),
          const SizedBox(height: EmSpace.xl - 2),
          _costBasis(pnl, asset, price),
          const SizedBox(height: EmSpace.xl - 2),
          _whereItIs(asset, price),
          const SizedBox(height: EmSpace.xl - 2),
          _movementsSection(),
        ],
      ),
    );
  }

  /// El widget de iOS se alimenta de los favoritos, así que marcar uno sigue
  /// existiendo — pero acá, en el detalle, y no como una estrella flotando
  /// sobre cada fila de la lista.
  Widget _favoriteButton(BuildContext context) {
    final favorites = context.watch<FavoritesService>();
    final isFavorite = favorites.isFavorite(widget.asset);

    return IconButton(
      onPressed: () => favorites.toggleFavorite(widget.asset),
      tooltip: isFavorite ? 'Quitar del widget' : 'Mostrar en el widget',
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        size: 20,
        color: isFavorite ? EmColors.textPrimary : EmColors.textTertiary,
      ),
    );
  }

  Widget _position(AssetBalance asset, double? value, double? change) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TU POSICIÓN', style: EmText.section),
        const SizedBox(height: EmSpace.sm),
        Text(
          value != null ? formatMoney(value) : '—',
          style: EmText.displaySmall,
        ),
        const SizedBox(height: EmSpace.sm + 1),
        Row(
          children: [
            Text(
              formatAssetQuantity(asset.total, asset.asset),
              style: EmText.body.copyWith(color: EmColors.textSecondary),
            ),
            const SizedBox(width: EmSpace.sm),
            Text('·', style: EmText.meta.copyWith(color: EmColors.textMuted)),
            const SizedBox(width: EmSpace.sm),
            EmDelta(percent: change, fontSize: 15, suffix: '24 h'),
          ],
        ),
      ],
    );
  }

  Widget _costBasis(PnlService pnl, AssetBalance asset, double? price) {
    final position = pnl.positionFor(widget.asset);
    final assetPnl = pnl.pnlFor(widget.asset);
    final avgBuy = position?.avgBuyPrice ?? assetPnl?.avgBuyPrice ?? asset.avgBuyPriceUsdt;

    if (avgBuy == null || avgBuy <= 0) {
      if (pnl.isLoading) {
        return const SizedBox(
          height: 60,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return const EmNotice(
        text: 'Todavía no hay lotes de compra registrados para este activo, '
            'así que no se puede calcular el precio promedio.',
      );
    }

    final diffPercent = price != null ? (price - avgBuy) / avgBuy * 100 : null;
    final diffUsd = price != null ? price - avgBuy : null;

    // La contabilidad de lotes puede haber quedado desfasada del saldo real.
    // Cuando pasa, el dato se muestra igual pero dicho: una app de plata no
    // puede presentar como verdad un número que no cuadra.
    final mismatch = position != null && !position.matchesBalance(asset.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: EmColors.surface,
            borderRadius: BorderRadius.circular(EmRadii.card),
            border: Border.all(color: EmColors.stroke),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EmSpace.lg,
                  EmSpace.lg - 2,
                  EmSpace.lg,
                  EmSpace.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Precio promedio de compra', style: EmText.meta),
                          const SizedBox(height: 3),
                          Text(formatMoney(avgBuy), style: EmText.title),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Precio ahora', style: EmText.meta),
                        const SizedBox(height: 3),
                        Text(
                          price != null ? formatMoney(price) : '—',
                          style: EmText.title.copyWith(
                            color: diffUsd == null
                                ? EmColors.textPrimary
                                : EmDelta.colorFor(diffUsd),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (diffPercent != null && diffUsd != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EmSpace.lg,
                    0,
                    EmSpace.lg,
                    EmSpace.lg - 2,
                  ),
                  child: _PpcBar(diffPercent: diffPercent, diffUsd: diffUsd),
                ),
              const Divider(height: 1, color: EmColors.strokeSoft),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _pnlCell(
                        'No realizado',
                        position?.unrealizedPnl ?? assetPnl?.unrealizedPnl,
                        kind: AssetPnlKind.unrealized,
                        price: price,
                      ),
                    ),
                    const VerticalDivider(width: 1, color: EmColors.strokeSoft),
                    Expanded(
                      child: _pnlCell(
                        'Realizado',
                        assetPnl?.realizedPnl,
                        kind: AssetPnlKind.realized,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (mismatch) ...[
          const SizedBox(height: EmSpace.sm),
          EmNotice(
            accent: EmColors.flow,
            text: 'La contabilidad de lotes registra '
                '${formatAssetQuantity(position.amount, widget.asset)} y el saldo real es '
                '${formatAssetQuantity(asset.total, widget.asset)}. '
                'El promedio puede estar desfasado.',
          ),
        ],
      ],
    );
  }

  /// Un resultado del activo, y de qué está hecho.
  ///
  /// Sin valor no se abre: un card que dice "—" no tiene nada que desarmar, y
  /// el chevron estaría prometiendo un panel vacío.
  Widget _pnlCell(
    String label,
    double? value, {
    required AssetPnlKind kind,
    double? price,
  }) {
    final canOpen = value != null;

    return GestureDetector(
      onTap: canOpen
          ? () => AssetPnlBreakdownSheet.show(
                context,
                asset: widget.asset,
                kind: kind,
                total: value,
                price: price,
              )
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EmSpace.lg,
          vertical: EmSpace.md + 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == null ? '—' : formatSignedUsd(value),
              style: EmText.headline.copyWith(color: EmDelta.colorFor(value)),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: EmText.meta),
                // Los cards que se abren lo anuncian: tres iguales donde sólo
                // algunos responden al toque son una lotería.
                if (canOpen) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: EmColors.textTertiary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _whereItIs(AssetBalance asset, double? price) {
    final breakdown = asset.exchangeBreakdown;
    if (breakdown == null || breakdown.isEmpty) {
      if (asset.exchanges.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmSectionHeader(title: 'Dónde está'),
          for (final exchange in asset.exchanges)
            EmListRow(
              title: formatExchangeName(exchange),
              showDivider: exchange != asset.exchanges.last,
            ),
        ],
      );
    }

    final sorted = List<ExchangeBreakdown>.from(breakdown)
      ..sort((a, b) => b.total.compareTo(a.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmSectionHeader(title: 'Dónde está'),
        for (final item in sorted)
          EmListRow(
            title: formatExchangeName(item.exchange),
            trailing: Text(
              formatAssetAmount(item.total),
              style: EmText.label.copyWith(color: EmColors.textTertiary),
            ),
            value: price != null ? formatMoney(item.total * price) : null,
            showDivider: item != sorted.last,
          ),
      ],
    );
  }

  Widget _movementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmSectionHeader(title: 'Movimientos'),
        FutureBuilder<List<Transaction>>(
          future: _movements,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: EmSpace.xl),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: EmSpace.lg),
                child: Text(
                  'No se pudieron cargar los movimientos.',
                  style: EmText.label.copyWith(color: EmColors.textTertiary),
                ),
              );
            }

            final movements = snapshot.data ?? const [];
            if (movements.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: EmSpace.lg),
                child: Text(
                  'Sin movimientos registrados.',
                  style: EmText.label.copyWith(color: EmColors.textTertiary),
                ),
              );
            }

            return Column(
              children: [
                for (final movement in movements)
                  MovementRow(
                    transaction: movement,
                    showDivider: movement != movements.last,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Dónde está el precio respecto de lo que pagaste. El recorrido se acota a
/// ±10 %: más allá de eso el dato ya lo dice el porcentaje, y una barra sin
/// tope se vuelve ilegible.
class _PpcBar extends StatelessWidget {
  final double diffPercent;
  final double diffUsd;

  const _PpcBar({required this.diffPercent, required this.diffUsd});

  @override
  Widget build(BuildContext context) {
    final color = EmDelta.colorFor(diffUsd);
    final ratio = (diffPercent / 10).clamp(-1.0, 1.0);
    final isAbove = diffUsd >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final half = constraints.maxWidth / 2;
            final width = (half * ratio.abs()).clamp(2.0, half);

            return SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: EmColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(EmRadii.pill),
                    ),
                  ),
                  Positioned(
                    left: isAbove ? half : half - width,
                    width: width,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(EmRadii.pill),
                      ),
                    ),
                  ),
                  Positioned(
                    left: half - 0.5,
                    width: 1,
                    top: -2,
                    bottom: -2,
                    child: Container(color: EmColors.strokeStrong),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: EmSpace.sm - 1),
        Row(
          children: [
            Expanded(
              child: Text(
                isAbove
                    ? 'estás ${formatMoney(diffUsd.abs())} por encima del PPC'
                    : 'estás ${formatMoney(diffUsd.abs())} por debajo del PPC',
                style: EmText.meta.copyWith(color: EmColors.textMuted),
              ),
            ),
            Text(
              formatSignedPercent(diffPercent),
              style: EmText.meta.copyWith(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
