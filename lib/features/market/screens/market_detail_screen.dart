import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/balance.dart';
import '../../../core/models/market.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/market_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../../asset/screens/asset_detail_screen.dart';
import '../widgets/candlestick_chart.dart';
import '../widgets/order_book_view.dart';

/// El mercado de un par.
///
/// Antes tocar una fila del mercado abría TU tenencia de esa moneda: la
/// pregunta "cuánto tengo" tapaba a "cómo está el mercado". Ahora abre el
/// mercado —velas, libro de órdenes, spread— y tu posición queda como una
/// tira, con un acceso al detalle del activo para quien la quiera.
class MarketDetailScreen extends StatefulWidget {
  final String symbol;
  final String exchange;

  const MarketDetailScreen({
    super.key,
    required this.symbol,
    this.exchange = 'binance',
  });

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  late final MarketService _market;
  MarketTimeframe _timeframe = MarketTimeframe.d1;

  /// El libro por REST, para los exchanges que no lo emiten en vivo.
  OrderBook? _restBook;

  String get _base => widget.symbol.split('/').first;
  String get _quote =>
      widget.symbol.split('/').length > 1 ? widget.symbol.split('/')[1].split(':').first : '';

  @override
  void initState() {
    super.initState();
    _market = MarketService(context.read<ApiService>());
    _load();

    final prices = context.read<PriceService>();
    prices.subscribe([widget.symbol]);
    prices.subscribeOrderBook(widget.exchange, widget.symbol);
    _subscribeKlines();
    // Si el exchange no manda profundidad, el servidor avisa y caemos a REST.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fallbackBook());
  }

  @override
  void dispose() {
    // El libro son cuatro mensajes por segundo y las velas un par: soltarlos
    // al salir no es una optimización, es no dejar el caño abierto.
    final prices = context.read<PriceService>();
    prices.unsubscribeOrderBook(widget.exchange, widget.symbol);
    prices.unsubscribeKlines(widget.exchange, widget.symbol, _timeframe.api);
    _market.dispose();
    super.dispose();
  }

  void _subscribeKlines() {
    context.read<PriceService>().subscribeKlines(
          widget.exchange,
          widget.symbol,
          _timeframe.api,
          _market.applyLiveCandle,
        );
  }

  Future<void> _load() async {
    await _market.load(
      exchange: widget.exchange,
      symbol: widget.symbol,
      timeframe: _timeframe,
    );
    if (mounted) {
      await _market.loadOpenOrders(
        exchange: widget.exchange,
        symbol: widget.symbol,
      );
    }
  }

  Future<void> _fallbackBook() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final prices = context.read<PriceService>();
    if (prices.orderBook(widget.exchange, widget.symbol) != null) return;
    final book = await _market.fetchOrderBook(
      exchange: widget.exchange,
      symbol: widget.symbol,
    );
    if (mounted) setState(() => _restBook = book);
  }

  void _setTimeframe(MarketTimeframe tf) {
    if (tf == _timeframe) return;
    // Las velas en vivo son de un intervalo concreto: hay que soltar el
    // anterior antes de pedir el nuevo, o llegarían las dos series mezcladas.
    context.read<PriceService>()
        .unsubscribeKlines(widget.exchange, widget.symbol, _timeframe.api);
    setState(() => _timeframe = tf);
    _subscribeKlines();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final prices = context.watch<PriceService>();
    final favorites = context.watch<FavoritesService>();
    final balances = context.watch<BalanceService>();

    final live = prices.getPrice(widget.symbol);
    final book = prices.orderBook(widget.exchange, widget.symbol) ?? _restBook;
    final isLive = prices.orderBook(widget.exchange, widget.symbol) != null;
    AssetBalance? holding;
    for (final a in balances.assets) {
      if (a.asset.toUpperCase() == _base.toUpperCase()) {
        holding = a;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AssetLogo(asset: _base, size: 26),
            const SizedBox(width: EmSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.symbol, style: EmText.headline),
                Text(
                  formatExchangeName(widget.exchange),
                  style: EmText.meta.copyWith(color: EmColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (holding != null && holding.total > 0) _holdingChip(holding, live),
          IconButton(
            tooltip: favorites.isFavorite(_base) ? 'Quitar de favoritos' : 'Marcar favorito',
            icon: Icon(
              favorites.isFavorite(_base) ? Icons.star : Icons.star_border,
              color: favorites.isFavorite(_base)
                  ? EmColors.textPrimary
                  : EmColors.textTertiary,
              size: 21,
            ),
            onPressed: () => favorites.toggleFavorite(_base),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _market,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              EmSpace.screen,
              EmSpace.sm,
              EmSpace.screen,
              EmSpace.xxl,
            ),
            children: [
              _price(live),
              const SizedBox(height: EmSpace.lg),
              _stats(live),
              const SizedBox(height: EmSpace.xl),
              EmSegmented<MarketTimeframe>(
                options: [
                  for (final tf in MarketTimeframe.values)
                    (value: tf, label: tf.label),
                ],
                selected: _timeframe,
                onChanged: _setTimeframe,
              ),
              const SizedBox(height: EmSpace.md),
              if (_market.isLoading && _market.ohlc == null)
                const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                CandlestickChart(
                  candles: _market.ohlc?.candles ?? const [],
                  livePrice: live?.price,
                  avgCost: holding?.avgBuyPriceUsdt,
                  orders: _market.ordersFor(widget.symbol),
                ),
              if (_market.error != null) ...[
                const SizedBox(height: EmSpace.sm),
                const EmNotice(
                  text: "No se pudieron actualizar las velas. Deslizá para reintentar.",
                ),
              ],
              if (_market.ordersFor(widget.symbol).isNotEmpty) ...[
                const SizedBox(height: EmSpace.xl),
                const EmSectionHeader(title: 'Tus órdenes abiertas'),
                const SizedBox(height: EmSpace.sm),
                for (final o in _market.ordersFor(widget.symbol))
                  _order(o, last: o == _market.ordersFor(widget.symbol).last),
              ],
              const SizedBox(height: EmSpace.xl),
              const EmSectionHeader(title: 'Libro de órdenes'),
              const SizedBox(height: EmSpace.sm),
              OrderBookView(book: book, live: isLive),
              if (holding != null && holding.total > 0 && holding.avgBuyPriceUsdt != null) ...[
                const SizedBox(height: EmSpace.xl),
                const EmSectionHeader(title: 'Tu posición'),
                const SizedBox(height: EmSpace.sm),
                _position(holding, live),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Tu tenencia, arriba del todo.
  ///
  /// La pregunta "¿tengo de esto?" se contesta de un vistazo o no sirve:
  /// abajo, después del gráfico y del libro, había que ir a buscarla. Va sólo
  /// la cantidad —el precio promedio y el resultado no entran en una barra— y
  /// abre el detalle del activo.
  Widget _holdingChip(AssetBalance holding, dynamic live) {
    final price = live?.price as double?;
    final avg = holding.avgBuyPriceUsdt;
    final delta = (avg != null && avg > 0 && price != null) ? (price - avg) / avg * 100 : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: _base)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: EmSpace.sm, vertical: 4),
        constraints: const BoxConstraints(maxWidth: 132),
        decoration: BoxDecoration(
          color: EmColors.surfaceHigh,
          borderRadius: BorderRadius.circular(EmRadii.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatAssetAmount(holding.total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EmText.meta.copyWith(
                color: EmColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (delta != null)
              Text(
                formatSignedPercent(delta),
                maxLines: 1,
                style: EmText.section.copyWith(color: EmDelta.colorFor(delta)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _price(dynamic live) {
    final price = live?.price as double?;
    final change = live?.change24h as double?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          price == null ? '—' : formatQuotePrice(price, _quote),
          style: EmText.display,
        ),
        const SizedBox(height: EmSpace.xs),
        Row(
          children: [
            EmDelta(percent: change, fontSize: 15),
            const SizedBox(width: EmSpace.sm),
            Text(
              'últimas 24 h',
              style: EmText.meta.copyWith(color: EmColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  /// Máximo, mínimo y volumen salen de las velas que ya están en pantalla: son
  /// del intervalo que estás mirando, no de un "24 h" que contradiga al gráfico.
  Widget _stats(dynamic live) {
    final o = _market.ohlc;
    final entries = <({String label, String value})>[
      (label: 'Máximo', value: o?.high == null ? '—' : formatQuotePrice(o!.high!, _quote)),
      (label: 'Mínimo', value: o?.low == null ? '—' : formatQuotePrice(o!.low!, _quote)),
      (label: 'Volumen', value: o == null ? '—' : formatCompactMoney(o.volume)),
    ];
    return Row(
      children: [
        for (final e in entries) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.label.toUpperCase(),
                    style: EmText.section.copyWith(color: EmColors.textTertiary)),
                const SizedBox(height: 2),
                Text(e.value, style: EmText.data.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Una orden esperando. El subtítulo dice cuánto lleva ejecutado sólo
  /// cuando algo se ejecutó: "0 de 0,5" en todas las filas es ruido.
  Widget _order(OpenOrder o, {required bool last}) {
    final color = o.isBuy ? EmColors.up : EmColors.down;
    final precio = o.chartPrice;
    return EmListRow(
      leading: EmIconTile(
        icon: o.isBuy ? Icons.south_west : Icons.north_east,
        color: color,
        tinted: false,
      ),
      title: '${o.isBuy ? 'Compra' : 'Venta'} de ${formatAssetAmount(o.amount)} $_base',
      subtitle: [
        o.type.replaceAll('_', ' '),
        if (o.filled > 0)
          '${formatAssetAmount(o.filled)} ejecutado',
      ].join(' · '),
      trailing: Text(
        precio == null ? 'a mercado' : formatQuotePrice(precio, _quote),
        style: EmText.data.copyWith(fontSize: 14, color: color),
      ),
      showDivider: !last,
    );
  }

  Widget _position(AssetBalance holding, dynamic live) {
    final amount = holding.total;
    final avg = holding.avgBuyPriceUsdt;
    final price = live?.price as double?;
    final unrealized =
        (avg != null && price != null) ? amount * (price - avg) : null;

    return EmListRow(
      leading: const EmIconTile(
        icon: Icons.account_balance_wallet_outlined,
        color: EmColors.textSecondary,
        tinted: false,
      ),
      title: formatAssetQuantity(amount, _base),
      subtitle: avg == null ? null : 'PPC ${formatQuotePrice(avg, _quote)}',
      trailing: unrealized == null
          ? null
          : Text(
              formatSignedUsd(unrealized),
              style: EmText.data.copyWith(
                fontSize: 14,
                color: EmDelta.colorFor(unrealized),
              ),
            ),
      showDivider: false,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: _base)),
      ),
    );
  }
}
