import 'package:flutter/material.dart';

import '../../../core/models/transaction.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/em/em_primitives.dart';

/// Color e ícono de un tipo de movimiento.
///
/// Verde y rojo se reservan para RESULTADO (intereses, comisiones, el lado de
/// una operación). Los depósitos y retiros son capital que entra o sale por tu
/// mano: van en ámbar, porque un depósito no es una ganancia.
({IconData icon, Color color}) movementStyle(Transaction t) {
  switch (t.type) {
    case TransactionType.deposit:
      return (icon: Icons.arrow_downward, color: EmColors.flow);
    case TransactionType.withdrawal:
      return (icon: Icons.arrow_upward, color: EmColors.flow);
    case TransactionType.transfer:
      return (icon: Icons.swap_vert, color: EmColors.flow);
    case TransactionType.interest:
      return (icon: Icons.add, color: EmColors.up);
    case TransactionType.fee:
      return (icon: Icons.remove, color: EmColors.down);
    case TransactionType.trade:
      return (
        icon: Icons.swap_horiz,
        color: t.isOutflow ? EmColors.down : EmColors.up,
      );
  }
}

/// Título de un movimiento: "Depósito BTC", "Venta NEXO / USDT".
String movementTitle(Transaction t) {
  if (t.type == TransactionType.trade) {
    final verb = t.isBuy ? 'Compra' : (t.isSell ? 'Venta' : 'Operación');
    return t.pair != null
        ? '$verb ${t.pair!.replaceAll('/', ' / ')}'
        : '$verb ${t.asset.toUpperCase()}';
  }
  return '${t.type.label} ${t.asset.toUpperCase()}';
}

/// Una fila de movimiento: 52 pt en vez de la tarjeta de dos pisos de ~150 pt
/// que había antes para mostrar los mismos cinco datos.
class MovementRow extends StatelessWidget {
  final Transaction transaction;
  final bool showDivider;
  final bool showTime;

  const MovementRow({
    super.key,
    required this.transaction,
    this.showDivider = true,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = movementStyle(transaction);
    final usd = transaction.usdValue;

    final metaParts = <String>[
      if (showTime) formatTime(transaction.timestamp),
      formatExchangeName(transaction.exchange),
      if (transaction.type == TransactionType.trade && transaction.price != null)
        'a ${formatAssetAmount(transaction.price!)}',
    ];

    return EmListRow(
      leading: EmIconTile(icon: style.icon, color: style.color),
      title: movementTitle(transaction),
      subtitle: metaParts.join(' · '),
      value: null,
      showDivider: showDivider,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatSignedQuantity(transaction.signedAmount, transaction.asset),
            style: EmText.data.copyWith(fontSize: 14, color: style.color),
          ),
          if (usd != null) ...[
            const SizedBox(height: 2),
            Text(formatMoney(usd), style: EmText.meta),
          ],
        ],
      ),
    );
  }
}

/// Varios movimientos idénticos del mismo día, plegados en una fila.
///
/// Nexo acredita intereses una docena de veces por día con el mismo importe y
/// la misma hora: sin agrupar, tres días de intereses tapan todo lo demás.
class GroupedMovementRow extends StatefulWidget {
  final List<Transaction> transactions;
  final bool showDivider;

  const GroupedMovementRow({
    super.key,
    required this.transactions,
    this.showDivider = true,
  });

  @override
  State<GroupedMovementRow> createState() => _GroupedMovementRowState();
}

class _GroupedMovementRowState extends State<GroupedMovementRow> {
  bool _expanded = false;

  /// Un traspaso entre exchanges propios: sus puntas se anulan entre sí.
  bool get _esTraspaso => widget.transactions.first.transferGroupId != null;

  /// De dónde salió y adónde entró. Es lo que el traspaso tiene para decir.
  ({Transaction salida, Transaction entrada})? get _puntas {
    if (!_esTraspaso || widget.transactions.length < 2) return null;
    Transaction? salida, entrada;
    for (final t in widget.transactions) {
      if (t.type == TransactionType.withdrawal) salida = t;
      if (t.type == TransactionType.deposit) entrada = t;
    }
    return (salida == null || entrada == null)
        ? null
        : (salida: salida, entrada: entrada);
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.transactions.first;
    final puntas = _puntas;
    final style = puntas != null
        ? (icon: Icons.swap_horiz, color: EmColors.flow)
        : movementStyle(first);

    // Un traspaso no mueve tu plata: sumar +0,579 y −0,579 daría cero, que es
    // cierto y no dice nada. Se muestra CUÁNTO se movió, sin signo.
    final totalAmount = puntas != null
        ? puntas.entrada.amount.abs()
        : widget.transactions.fold<double>(0, (sum, t) => sum + t.signedAmount);

    // Sólo se suma en dólares si TODOS los movimientos se pueden valorizar.
    // En un traspaso se muestra el valor de lo movido, no la suma de las dos
    // puntas, que se cancelan.
    double? totalUsd = 0;
    if (puntas != null) {
      totalUsd = puntas.entrada.usdValue?.abs();
    } else {
      for (final t in widget.transactions) {
        final usd = t.usdValue;
        if (usd == null) {
          totalUsd = null;
          break;
        }
        totalUsd = totalUsd! + usd;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(vertical: EmSpace.md),
            decoration: widget.showDivider && !_expanded
                ? const BoxDecoration(
                    border: Border(bottom: BorderSide(color: EmColors.strokeSoft)),
                  )
                : null,
            child: Row(
              children: [
                EmIconTile(icon: style.icon, color: style.color),
                const SizedBox(width: EmSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              puntas != null
                                  ? 'Traspaso ${first.asset.toUpperCase()}'
                                  : movementTitle(first),
                              style: EmText.rowLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: EmSpace.sm - 1),
                          if (puntas == null) Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: EmSpace.xs + 2,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: EmColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(EmRadii.pill),
                              border: Border.all(color: EmColors.stroke),
                            ),
                            child: Text(
                              '${widget.transactions.length}',
                              style: EmText.meta.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        puntas != null
                            // De dónde a dónde: es la única pregunta que un
                            // traspaso deja abierta.
                            ? '${formatExchangeName(puntas.salida.exchange)} → '
                                '${formatExchangeName(puntas.entrada.exchange)}'
                            : '${formatTime(first.timestamp)} · '
                                '${formatExchangeName(first.exchange)}',
                        style: EmText.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: EmSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      puntas != null
                          ? formatAssetQuantity(totalAmount, first.asset)
                          : formatSignedQuantity(totalAmount, first.asset),
                      style: EmText.data.copyWith(fontSize: 14, color: style.color),
                    ),
                    if (totalUsd != null) ...[
                      const SizedBox(height: 2),
                      Text(formatMoney(totalUsd), style: EmText.meta),
                    ],
                  ],
                ),
                const SizedBox(width: EmSpace.sm - 2),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: EmColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: EmSpace.xxl + EmSpace.sm),
            child: Column(
              children: [
                for (final t in widget.transactions)
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(vertical: EmSpace.sm),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: EmColors.strokeSoft)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatTime(t.timestamp),
                            style: EmText.meta,
                          ),
                        ),
                        Text(
                          formatSignedQuantity(t.signedAmount, t.asset),
                          style: EmText.meta.copyWith(color: style.color),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
