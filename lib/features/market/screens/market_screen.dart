import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/price.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/pnl_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../../asset/screens/asset_detail_screen.dart';

/// Mercado.
///
/// Primero los pares donde tenés plata, con tu precio promedio al lado del
/// precio de ahora: mirar una cotización sin saber a cuánto entraste no
/// responde ninguna pregunta.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String? _exchangeFilter;

  @override
  Widget build(BuildContext context) {
    final prices = context.watch<PriceService>();
    final balance = context.watch<BalanceService>();

    final held = balance.assets.map((a) => a.asset.toUpperCase()).toSet();

    var all = prices.priceList;
    if (_exchangeFilter != null) {
      all = all.where((p) => p.source == _exchangeFilter).toList();
    }

    final owned = all.where((p) => held.contains(p.asset.toUpperCase())).toList()
      ..sort((a, b) => a.asset.compareTo(b.asset));
    final others = all.where((p) => !held.contains(p.asset.toUpperCase())).toList()
      ..sort((a, b) => a.asset.compareTo(b.asset));

    final sources = prices.priceList
        .map((p) => p.source)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    // Exchanges con saldo de los que ESPERAMOS precios en vivo y no llegan.
    // "Esperamos" es la parte importante: Nexo no emite precios nunca y
    // Kraken sin pares configurados no tiene nada que mandar. Listarlos
    // acusaba de silencio a quien nadie le había pedido hablar.
    final silent = balance.exchanges
        .map((e) => e.exchange)
        .where(prices.expectsPrices)
        .where((e) => !sources.any((s) => s.toLowerCase() == e.toLowerCase()))
        .map(formatExchangeName)
        .toSet()
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EmSpace.screen,
            EmSpace.xs,
            EmSpace.screen,
            EmSpace.xxl,
          ),
          children: [
            Row(
              children: [
                Text('MERCADO', style: EmText.section),
                const Spacer(),
                _connectionDot(prices),
              ],
            ),
            const SizedBox(height: EmSpace.lg),
            if (sources.length > 1) ...[
              _sourceChips(sources),
              const SizedBox(height: EmSpace.lg),
            ],
            if (prices.priceList.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: EmSpace.xxxl),
                child: EmEmptyState(
                  icon: Icons.show_chart,
                  title: prices.isConnecting ? 'Conectando…' : 'Sin cotizaciones',
                  subtitle: prices.isConnecting
                      ? null
                      : 'No llegaron precios en vivo. Deslizá para reintentar.',
                ),
              )
            else ...[
              if (owned.isNotEmpty) ...[
                const EmSectionHeader(title: 'Donde tenés posición'),
                for (final price in owned)
                  _priceRow(price, owned: true, isLast: price == owned.last),
                const SizedBox(height: EmSpace.xl - 2),
              ],
              if (others.isNotEmpty) ...[
                const EmSectionHeader(title: 'Otros pares'),
                for (final price in others)
                  _priceRow(price, owned: false, isLast: price == others.last),
              ],
            ],
            if (silent.isNotEmpty) ...[
              const SizedBox(height: EmSpace.lg),
              EmNotice(
                text: silent.length == 1
                    ? '${silent.first} no está enviando precios en vivo. '
                        'Tu saldo ahí se valúa con la última cotización conocida.'
                    : '${silent.join(' y ')} no están enviando precios en vivo. '
                        'Tus saldos ahí se valúan con la última cotización conocida.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _connectionDot(PriceService prices) {
    final live = prices.isConnected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: live ? EmColors.up : EmColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: EmSpace.sm - 2),
        Text(
          live ? 'en vivo' : (prices.isConnecting ? 'conectando' : 'sin conexión'),
          style: EmText.meta,
        ),
      ],
    );
  }

  Widget _sourceChips(List<String> sources) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          EmChip(
            label: 'Todos',
            selected: _exchangeFilter == null,
            onTap: () => setState(() => _exchangeFilter = null),
          ),
          for (final source in sources) ...[
            const SizedBox(width: EmSpace.sm - 1),
            EmChip(
              label: formatExchangeName(source),
              selected: _exchangeFilter == source,
              onTap: () => setState(
                () => _exchangeFilter = _exchangeFilter == source ? null : source,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(PriceUpdate price, {required bool owned, required bool isLast}) {
    final balance = context.read<BalanceService>();
    final pnl = context.watch<PnlService>();

    // Cada cotización se muestra en SU moneda. Antes todo llevaba "$", así que
    // un par NEXO/BTC aparecía como "$0,000011": un número sin significado.
    final quoted = splitQuotePrice(price.price, price.quote);

    String? subtitle;
    if (owned) {
      final asset = balance.assets.firstWhere(
        (a) => a.asset.toUpperCase() == price.asset.toUpperCase(),
        orElse: () => balance.assets.first,
      );
      final avg = pnl.avgBuyPrice(price.asset);
      subtitle = [
        'tenés ${formatAssetAmount(asset.total)}',
        if (avg != null && isDollarQuote(price.quote)) 'PPC ${formatAssetAmount(avg)}',
      ].join(' · ');
    }

    return EmListRow(
      leading: PairLogos(asset: price.asset, quote: price.quote, size: 34),
      title: '${price.asset.toUpperCase()} / ${price.quote.toUpperCase()}',
      subtitle: subtitle ?? (price.source != null ? formatExchangeName(price.source!) : null),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(quoted.value, style: EmText.data),
              if (quoted.unit != null) ...[
                const SizedBox(width: EmSpace.xs),
                Text(
                  quoted.unit!,
                  style: EmText.label.copyWith(color: EmColors.textTertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          EmDelta(percent: price.change24h, fontSize: 12, showMark: false),
        ],
      ),
      showDivider: !isLast,
      onTap: owned
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetDetailScreen(asset: price.asset),
                ),
              )
          : null,
    );
  }
}
