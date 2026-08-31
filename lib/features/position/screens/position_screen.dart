import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/balance.dart';
import '../../../core/models/chart_data.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/services/pnl_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_balance_chart.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../../asset/screens/asset_detail_screen.dart';
import '../widgets/pnl_breakdown_sheet.dart';

/// Pantalla principal: cuánto tenés, cómo viene y en qué.
///
/// Antes esto eran dos pestañas —Dashboard y Balances— que mostraban la misma
/// tarjeta azul y casi los mismos datos. Son una sola, y la pestaña que se
/// libera es la de Ajustes, que no existía.
class PositionScreen extends StatefulWidget {
  const PositionScreen({super.key});

  @override
  State<PositionScreen> createState() => _PositionScreenState();
}

class _PositionScreenState extends State<PositionScreen> {
  bool _hideValues = false;
  ChartPoint? _scrubbed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final balance = context.read<BalanceService>();
    final chart = context.read<ChartService>();
    final pnl = context.read<PnlService>();
    final transactions = context.read<TransactionService>();

    await Future.wait([
      balance.loadBalance(),
      chart.loadChartData(),
      pnl.load(),
      transactions.loadStats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<BalanceService>();
    final chart = context.watch<ChartService>();

    // El delta SIEMPRE corresponde al período elegido: se mide contra el primer
    // punto de la serie dibujada, no contra un 24 h fijo. Antes el número
    // grande y el porcentaje se quedaban en "ahora / últimas 24 h" aunque
    // estuvieras mirando un año.
    final start = chart.startValue;
    final current = balance.totalValueUsd;
    final scrubbed = _scrubbed;
    final shown = scrubbed?.value ?? current;

    // El delta siempre se lee HACIA ADELANTE en el tiempo, desde una base hasta
    // un extremo:
    //  - sin tocar el gráfico, del inicio del período hasta ahora;
    //  - tocando un punto, DESDE ese punto hasta ahora — que es lo que uno
    //    quiere saber al mirar el pasado ("tenía esto, ahora tengo esto otro").
    // Medirlo al revés hacía que tocar un mínimo de hace un mes mostrara una
    // flecha roja aunque desde entonces la cartera hubiera subido.
    final base = scrubbed?.value ?? start;
    final head = scrubbed != null ? current : shown;
    final deltaUsd = (base != null && base > 0) ? head - base : null;

    // El porcentaje sólo se muestra cuando SIGNIFICA algo. Si en el período
    // entró o salió capital, el rendimiento sobre una base que cambió por
    // aportes no es rendimiento: con un año de historia daba "+179 %", que era
    // casi todo plata puesta, no ganada. En ese caso va sólo la variación
    // absoluta, y el aviso de abajo explica por qué.
    final hasCapitalMoves = chart.capitalEvents.isNotEmpty;
    final deltaPercent = (!hasCapitalMoves && base != null && base > 0)
        ? (head - base) / base * 100
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: EmColors.textPrimary,
          backgroundColor: EmColors.surface,
          // El padding lateral lo pone cada bloque, no la lista: así el
          // gráfico puede llegar a los dos bordes de la pantalla.
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: EmSpace.xs,
              bottom: EmSpace.xxl,
            ),
            children: [
              _padded(_header(context)),
              const SizedBox(height: EmSpace.md + 2),
              _padded(_total(
                shown,
                deltaUsd,
                deltaPercent,
                chart.selectedTimeframe,
                percentHidden: hasCapitalMoves,
              )),
              const SizedBox(height: EmSpace.lg + 2),
              _padded(_periodPicker(chart)),
              const SizedBox(height: EmSpace.lg),
              EmBalanceChart(
                points: chart.getChartPoints(),
                capitalEvents: chart.capitalEvents,
                footnote: _capitalFootnote(chart, deltaUsd),
                onScrub: (point) => setState(() => _scrubbed = point),
              ),
              const SizedBox(height: EmSpace.xl),
              _padded(_result(context)),
              const SizedBox(height: EmSpace.xl - 2),
              _padded(_assets(context, balance)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: EmSpace.screen),
        child: child,
      );

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Text('POSICIÓN', style: EmText.section),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _hideValues = !_hideValues),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(EmSpace.sm),
            child: Icon(
              _hideValues ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 19,
              color: EmColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _total(
    double value,
    double? deltaUsd,
    double? deltaPercent,
    ChartTimeframe timeframe, {
    bool percentHidden = false,
  }) {
    if (_hideValues) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('••••••••', style: EmText.display),
          const SizedBox(height: EmSpace.md - 2),
          Text('••••••', style: EmText.data.copyWith(color: EmColors.textTertiary)),
        ],
      );
    }

    final parts = formatMoney(value).split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                parts.first,
                style: EmText.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (parts.length > 1)
              Text(
                ',${parts[1]}',
                style: EmText.display.copyWith(color: EmColors.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: EmSpace.md - 2),
        Row(
          children: [
            EmDelta(usd: deltaUsd, percent: deltaPercent, fontSize: 17),
            const SizedBox(width: EmSpace.sm),
            Flexible(
              child: Text(
                _scrubbed != null
                    ? 'desde el ${formatDateTimeShort(_scrubbed!.timestamp)}'
                    : percentHidden
                        ? '${timeframe.sinceLabel}, con aportes'
                        : timeframe.sinceLabel,
                style: EmText.meta.copyWith(color: EmColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodPicker(ChartService chart) {
    return EmSegmented<ChartTimeframe>(
      options: [
        for (final tf in ChartTimeframe.values) (value: tf, label: tf.label),
      ],
      selected: chart.selectedTimeframe,
      onChanged: (tf) {
        setState(() => _scrubbed = null);
        chart.setTimeframe(tf);
      },
    );
  }

  /// La distinción que la app no hacía: un depósito no es una ganancia.
  /// Va como pie del gráfico, que es sobre lo que habla.
  String _capitalFootnote(ChartService chart, double? deltaUsd) {
    final events = chart.capitalEvents;
    if (events.isEmpty) return 'Todo el cambio es de mercado';

    final net = chart.netCapitalUsd;

    if (net == null) {
      return events.length == 1
          ? 'Incluye 1 movimiento de capital'
          : 'Incluye ${events.length} movimientos de capital';
    }

    if (net.abs() < 0.01) {
      return 'Aportes y retiros se compensan';
    }

    final market = deltaUsd != null ? deltaUsd - net : null;
    final capital = '${formatSignedMoney(net, decimals: 0)} de capital';
    return market != null
        ? '$capital · mercado ${formatSignedMoney(market, decimals: 0)}'
        : 'Incluye $capital';
  }

  /// Resultado de la cartera: lo que la app no mostraba en ninguna pantalla.
  Widget _result(BuildContext context) {
    final pnl = context.watch<PnlService>();
    final interest = context.watch<TransactionService>().stats?.totalInterestUsd;

    if (!pnl.hasData && !pnl.isLoading && interest == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmSectionHeader(title: 'Resultado', trailing: 'desde el inicio'),
        const SizedBox(height: EmSpace.sm + 2),
        Row(
          children: [
            Expanded(
              child: EmStat(
                value: _hideValues ? '••••' : formatSignedUsd(pnl.totalPnl, decimals: 0),
                label: 'P&L total',
                valueColor: EmDelta.colorFor(pnl.totalPnl),
                onTap: pnl.hasData
                    ? () => PnlBreakdownSheet.show(context, PnlBreakdownKind.total)
                    : null,
              ),
            ),
            const SizedBox(width: EmSpace.sm),
            Expanded(
              child: EmStat(
                value: _hideValues
                    ? '••••'
                    : formatSignedUsd(pnl.unrealizedPnl, decimals: 0),
                label: 'no realizado',
                valueColor: EmDelta.colorFor(pnl.unrealizedPnl),
                onTap: pnl.positions.isEmpty
                    ? null
                    : () => PnlBreakdownSheet.show(
                          context,
                          PnlBreakdownKind.unrealized,
                        ),
              ),
            ),
            const SizedBox(width: EmSpace.sm),
            Expanded(
              child: EmStat(
                value: interest == null
                    ? '—'
                    : _hideValues
                        ? '••••'
                        : formatSignedUsd(interest, decimals: 0),
                label: 'intereses',
                valueColor: interest == null ? null : EmColors.up,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _assets(BuildContext context, BalanceService balance) {
    final assets = balance.sortedAssetsByValue
        .where((a) => a.priceUsd != null || (a.valueUsd ?? 0) > 0)
        .toList();

    if (assets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: EmSpace.xxl),
        child: EmEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Todavía no hay saldos',
          subtitle: 'Conectá un exchange para ver tu posición.',
        ),
      );
    }

    final exchangeCount = balance.exchanges.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmSectionHeader(
          title: 'Activos',
          trailing: exchangeCount > 0
              ? '${assets.length} · $exchangeCount ${exchangeCount == 1 ? 'exchange' : 'exchanges'}'
              : '${assets.length}',
        ),
        for (final asset in assets)
          _assetRow(context, asset, isLast: asset == assets.last),
      ],
    );
  }

  Widget _assetRow(BuildContext context, AssetBalance asset, {required bool isLast}) {
    final prices = context.watch<PriceService>();
    final change = prices.getChange24hByAsset(asset.asset) ?? asset.change24h;

    return EmListRow(
      leading: AssetLogo(asset: asset.asset, size: 32),
      title: assetName(asset.asset),
      subtitle: _hideValues
          ? '•••••• · ${formatExchangeList(asset.exchanges)}'
          : '${formatAssetQuantity(asset.total, asset.asset)}'
              '${asset.exchanges.isEmpty ? '' : ' · ${formatExchangeList(asset.exchanges)}'}',
      value: _hideValues
          ? '••••••'
          : asset.valueUsd != null
              ? formatMoney(asset.valueUsd!)
              : '—',
      valueBelow: _hideValues
          ? null
          : EmDelta(percent: change, fontSize: 12, showMark: false),
      showDivider: !isLast,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(asset: asset.asset),
        ),
      ),
    );
  }
}
