import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/pnl.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/pnl_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../../asset/screens/asset_detail_screen.dart';

/// Qué resultado se está desarmando.
enum PnlBreakdownKind {
  /// Lo que se ganó o perdió sobre lo que todavía se tiene.
  unrealized,

  /// Realizado + no realizado.
  total,
}

/// De qué está hecho un número de la fila de resultado.
///
/// Un "−$618" sin abrir no dice nada accionable: puede ser un activo hundido o
/// cuatro que se compensan. Acá se ve qué activo lo explica, y desde cada fila
/// se entra a su detalle.
class PnlBreakdownSheet extends StatelessWidget {
  final PnlBreakdownKind kind;

  const PnlBreakdownSheet({super.key, required this.kind});

  static Future<void> show(BuildContext context, PnlBreakdownKind kind) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EmColors.surface,
      builder: (_) => PnlBreakdownSheet(kind: kind),
    );
  }

  String get _title => switch (kind) {
        PnlBreakdownKind.unrealized => 'No realizado',
        PnlBreakdownKind.total => 'P&L total',
      };

  String get _subtitle => switch (kind) {
        PnlBreakdownKind.unrealized =>
          'Lo que llevás ganado o perdido sobre lo que todavía tenés, contra tu precio promedio de compra.',
        PnlBreakdownKind.total =>
          'Lo realizado en operaciones cerradas más lo no realizado de lo que seguís teniendo.',
      };

  @override
  Widget build(BuildContext context) {
    final pnl = context.watch<PnlService>();
    final balance = context.watch<BalanceService>();
    final rows = _rows(pnl);
    final total = rows.fold<double>(0, (sum, r) => sum + r.amount);

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
                      Expanded(child: Text(_title, style: EmText.title)),
                      Text(
                        formatSignedUsd(total),
                        style: EmText.title.copyWith(color: EmDelta.colorFor(total)),
                      ),
                    ],
                  ),
                  const SizedBox(height: EmSpace.sm),
                  Text(
                    _subtitle,
                    style: EmText.body.copyWith(color: EmColors.textTertiary),
                  ),
                  const SizedBox(height: EmSpace.xl),

                  if (_mismatched(rows, balance).isNotEmpty) ...[
                    EmNotice(
                      accent: EmColors.flow,
                      text: _mismatchNotice(_mismatched(rows, balance), rows.length),
                    ),
                    const SizedBox(height: EmSpace.lg),
                  ],

                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: EmSpace.xl),
                      child: Text(
                        'Todavía no hay lotes de compra registrados, así que no se '
                        'puede desarmar el resultado por activo.',
                        style: EmText.label.copyWith(color: EmColors.textTertiary),
                      ),
                    )
                  else ...[
                    const EmSectionHeader(title: 'Por activo'),
                    for (final row in rows)
                      _BreakdownRow(
                        row: row,
                        isLast: row == rows.last,
                        mismatched: _mismatched(rows, balance).contains(row.asset),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssetDetailScreen(asset: row.asset),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double? _balanceAmount(BalanceService balance, String asset) {
    for (final a in balance.assets) {
      if (a.asset.toUpperCase() == asset.toUpperCase()) return a.total;
    }
    return null;
  }

  /// Activos cuya contabilidad de lotes no cuadra con el saldo real.
  Set<String> _mismatched(List<_BreakdownEntry> rows, BalanceService balance) {
    final out = <String>{};
    for (final row in rows) {
      final real = _balanceAmount(balance, row.asset);
      if (real == null || real == 0 || row.lotAmount == 0) continue;
      if ((row.lotAmount - real).abs() / real.abs() > 0.01) out.add(row.asset);
    }
    return out;
  }

  /// Un solo aviso arriba en vez de uno por fila: repetido en cada activo el
  /// panel se vuelve un muro de advertencias y deja de leerse.
  String _mismatchNotice(Set<String> mismatched, int total) {
    if (mismatched.length == total) {
      return 'La contabilidad de lotes no coincide con tus saldos reales, así que '
          'estos números pueden estar desfasados.';
    }
    final nombres = mismatched.map(assetName).join(', ');
    return 'En $nombres la contabilidad de lotes no coincide con el saldo real: '
        'esos números pueden estar desfasados.';
  }

  /// Las filas, ordenadas por cuánto pesan: lo que explica el número va primero,
  /// sin importar el signo.
  List<_BreakdownEntry> _rows(PnlService pnl) {
    final entries = <_BreakdownEntry>[];

    switch (kind) {
      case PnlBreakdownKind.unrealized:
        for (final p in pnl.positions) {
          if (p.unrealizedPnl == 0 && p.amount == 0) continue;
          entries.add(_BreakdownEntry(
            asset: p.asset,
            amount: p.unrealizedPnl,
            percent: p.unrealizedPnlPercent,
            avgBuyPrice: p.avgBuyPrice,
            lotAmount: p.amount,
          ));
        }
      case PnlBreakdownKind.total:
        for (final a in pnl.summary?.byAsset ?? const <AssetPnl>[]) {
          if (a.totalPnl == 0) continue;
          entries.add(_BreakdownEntry(
            asset: a.asset,
            amount: a.totalPnl,
            realized: a.realizedPnl,
            unrealized: a.unrealizedPnl,
            avgBuyPrice: a.avgBuyPrice,
            lotAmount: a.totalAmount,
          ));
        }
    }

    entries.sort((x, y) => y.amount.abs().compareTo(x.amount.abs()));
    return entries;
  }
}

class _BreakdownEntry {
  final String asset;
  final double amount;
  final double? percent;
  final double? realized;
  final double? unrealized;
  final double? avgBuyPrice;
  final double lotAmount;

  const _BreakdownEntry({
    required this.asset,
    required this.amount,
    this.percent,
    this.realized,
    this.unrealized,
    this.avgBuyPrice,
    this.lotAmount = 0,
  });
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownEntry row;
  final bool isLast;

  /// Los lotes de este activo no cuadran con su saldo real. El detalle lo da el
  /// aviso de arriba; acá alcanza con una marca.
  final bool mismatched;
  final VoidCallback onTap;

  const _BreakdownRow({
    required this.row,
    required this.isLast,
    required this.mismatched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (row.avgBuyPrice != null) 'PPC ${formatAssetAmount(row.avgBuyPrice!)}',
      if (row.realized != null && row.realized != 0)
        'realizado ${formatSignedMoney(row.realized!, decimals: 0)}',
      if (row.unrealized != null && row.unrealized != 0)
        'no realizado ${formatSignedMoney(row.unrealized!, decimals: 0)}',
    ];

    return EmListRow(
      leading: AssetLogo(asset: row.asset, size: 30),
      title: assetName(row.asset),
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      value: formatSignedUsd(row.amount, decimals: 0),
      valueBelow: row.percent == null
          ? null
          : EmDelta(percent: row.percent, fontSize: 12, showMark: false),
      showDivider: !isLast,
      onTap: onTap,
      trailing: mismatched
          ? Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: EmSpace.sm),
              decoration: const BoxDecoration(
                color: EmColors.flow,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
