import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/transaction.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import '../widgets/movement_row.dart';

/// Períodos rápidos. El selector de rango de Material queda para el caso raro:
/// nueve de cada diez veces lo que se quiere es "este mes" o "todo".
enum MovementPeriod {
  month('Este mes'),
  quarter('90 días'),
  year('Este año'),
  all('Todo');

  final String label;
  const MovementPeriod(this.label);

  DateTime? get start {
    final now = DateTime.now();
    switch (this) {
      case MovementPeriod.month:
        return DateTime(now.year, now.month, 1);
      case MovementPeriod.quarter:
        return now.subtract(const Duration(days: 90));
      case MovementPeriod.year:
        return DateTime(now.year, 1, 1);
      case MovementPeriod.all:
        return null;
    }
  }
}

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  final ScrollController _scroll = ScrollController();
  MovementPeriod _period = MovementPeriod.month;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPeriod(_period));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      final service = context.read<TransactionService>();
      if (!service.isLoadingMore && service.hasMore) service.loadMore();
    }
  }

  void _applyPeriod(MovementPeriod period) {
    setState(() => _period = period);
    context.read<TransactionService>().setDateRange(period.start, null);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<TransactionService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: service.refresh,
          color: EmColors.textPrimary,
          backgroundColor: EmColors.surface,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  EmSpace.screen,
                  EmSpace.xs,
                  EmSpace.screen,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MOVIMIENTOS', style: EmText.section),
                      const SizedBox(height: EmSpace.lg),
                      _periodChips(),
                      const SizedBox(height: EmSpace.lg),
                      _summary(service),
                    ],
                  ),
                ),
              ),
              _list(service),
              if (service.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: EmSpace.xl),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: EmSpace.xxl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in MovementPeriod.values) ...[
            EmChip(
              label: period.label,
              selected: _period == period,
              onTap: () => _applyPeriod(period),
            ),
            if (period != MovementPeriod.values.last)
              const SizedBox(width: EmSpace.sm - 1),
          ],
        ],
      ),
    );
  }

  Widget _summary(TransactionService service) {
    final stats = service.stats;

    return Row(
      children: [
        Expanded(
          child: EmStat(
            value: stats == null ? '—' : formatMoney(stats.totalCount.toDouble(), decimals: 0),
            label: 'movimientos',
          ),
        ),
        const SizedBox(width: EmSpace.sm),
        Expanded(
          child: EmStat(
            value: stats?.totalInterestUsd == null
                ? '—'
                : formatSignedMoney(stats!.totalInterestUsd!, decimals: 0),
            label: 'intereses',
            valueColor: stats?.totalInterestUsd == null ? null : EmColors.up,
          ),
        ),
        const SizedBox(width: EmSpace.sm),
        Expanded(
          child: EmStat(
            // La API todavía no calcula el total en dólares de las comisiones;
            // decir "—" es honesto, mostrar 0 no lo sería.
            value: stats?.totalFeesUsd == null
                ? '—'
                : formatSignedMoney(-stats!.totalFeesUsd!.abs(), decimals: 0),
            label: 'comisiones',
            valueColor: stats?.totalFeesUsd == null ? null : EmColors.down,
          ),
        ),
      ],
    );
  }

  Widget _list(TransactionService service) {
    if (service.isLoading && service.transactions.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.only(top: EmSpace.xxxl),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final sections = service.sections;

    if (sections.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Sin movimientos',
          subtitle: 'No hay movimientos en el período elegido.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: EmSpace.screen),
      sliver: SliverList.builder(
        itemCount: sections.length,
        itemBuilder: (context, index) => _section(sections[index]),
      ),
    );
  }

  Widget _section(DaySection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, EmSpace.lg + 2, 0, EmSpace.xs + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatDayHeader(section.day),
                style: EmText.label.copyWith(
                  color: EmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                section.movementCount == 1
                    ? '1 movimiento'
                    : '${section.movementCount} movimientos',
                style: EmText.meta.copyWith(color: EmColors.textMuted),
              ),
            ],
          ),
        ),
        for (final entry in section.entries)
          entry.isGroup
              ? GroupedMovementRow(
                  transactions: entry.items,
                  showDivider: entry != section.entries.last,
                )
              : MovementRow(
                  transaction: entry.first,
                  showDivider: entry != section.entries.last,
                ),
      ],
    );
  }
}
