import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/models/transaction.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/empty_state.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final txService = context.read<TransactionService>();
      if (!txService.isLoadingMore && txService.hasMore) {
        txService.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txService = context.watch<TransactionService>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Transacciones'),
        actions: [
          // Date range picker
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangePicker(context, txService),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => txService.refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Stats cards
            SliverToBoxAdapter(
              child: _StatsSection(
                stats: txService.stats,
                isLoading: txService.isLoading && txService.stats == null,
              ),
            ),

            // Filters
            SliverToBoxAdapter(
              child: _FiltersSection(
                selectedExchanges: txService.selectedExchanges,
                availableExchanges: txService.availableExchanges,
                hasAdvancedFilters: txService.selectedTypes.isNotEmpty ||
                    (txService.currentFilter.assets?.isNotEmpty ?? false),
                onExchangesChanged: (exchanges) =>
                    txService.setExchangeFilter(exchanges),
                onAdvancedPressed: () => _showAdvancedFilters(context, txService),
              ),
            ),

            // Transaction list
            if (txService.isLoading && txService.transactions.isEmpty)
              const SliverFillRemaining(child: _TransactionsSkeleton())
            else if (txService.transactions.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.swap_horiz,
                  title: 'Sin transacciones',
                  subtitle: 'No hay transacciones para mostrar',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < txService.transactions.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TransactionCard(
                            transaction: txService.transactions[index],
                          ),
                        );
                      }
                      // Loading indicator at bottom
                      if (txService.hasMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandAccent,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    childCount: txService.transactions.length +
                        (txService.hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(
    BuildContext context,
    TransactionService txService,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: txService.startDate != null && txService.endDate != null
          ? DateTimeRange(start: txService.startDate!, end: txService.endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              primaryContainer: AppColors.brandPrimary.withValues(alpha: 0.3),
              onPrimaryContainer: AppColors.textPrimary,
              surface: AppColors.bgCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      txService.setDateRange(picked.start, picked.end);
    }
  }

  void _showAdvancedFilters(BuildContext context, TransactionService txService) {
    // Get unique assets from stats
    final assets = txService.stats?.byAsset.keys.toList() ?? [];
    assets.sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _AdvancedFiltersModal(
        types: TransactionType.values,
        assets: assets,
        selectedTypes: Set.from(txService.selectedTypes),
        selectedAssets: Set.from(txService.currentFilter.assets ?? []),
        onApply: (types, assets) {
          txService.setTypeFilter(types.toList());
          txService.setAssetFilters(assets.isEmpty ? null : assets.toList());
          Navigator.pop(context);
        },
        onClear: () {
          txService.setTypeFilter([]);
          txService.setAssetFilters(null);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final TransactionStats? stats;
  final bool isLoading;

  const _StatsSection({this.stats, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _StatCardSkeleton()),
            const SizedBox(width: 12),
            Expanded(child: _StatCardSkeleton()),
            const SizedBox(width: 12),
            Expanded(child: _StatCardSkeleton()),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Total',
              value: stats?.totalCount.toString() ?? '--',
              icon: Icons.receipt_long,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Interest',
              value: stats?.totalInterestUsd != null
                  ? currencyFormat.format(stats!.totalInterestUsd)
                  : '--',
              icon: Icons.savings,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Fees',
              value: stats?.totalFeesUsd != null
                  ? currencyFormat.format(stats!.totalFeesUsd)
                  : '--',
              icon: Icons.money_off,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingShimmer(width: 18, height: 18),
          const SizedBox(height: 8),
          const LoadingShimmer(width: 60, height: 14),
          const SizedBox(height: 6),
          const LoadingShimmer(width: 40, height: 11),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color ?? AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersSection extends StatelessWidget {
  final List<String> selectedExchanges;
  final List<String> availableExchanges;
  final bool hasAdvancedFilters;
  final ValueChanged<List<String>> onExchangesChanged;
  final VoidCallback onAdvancedPressed;

  const _FiltersSection({
    required this.selectedExchanges,
    required this.availableExchanges,
    required this.hasAdvancedFilters,
    required this.onExchangesChanged,
    required this.onAdvancedPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Exchange chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableExchanges.map((e) {
                  final isSelected = selectedExchanges.contains(e);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(formatExchangeName(e)),
                      selected: isSelected,
                      onSelected: (s) {
                        final newExchanges = List<String>.from(selectedExchanges);
                        if (s) {
                          newExchanges.add(e);
                        } else {
                          newExchanges.remove(e);
                        }
                        onExchangesChanged(newExchanges);
                      },
                      avatar: ExchangeLogo(exchange: e, size: 18),
                      showCheckmark: false,
                      selectedColor: AppColors.brandAccent.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isSelected ? AppColors.brandAccent : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.border,
          ),

          // Advanced filter button
          IconButton(
            onPressed: onAdvancedPressed,
            icon: Badge(
              isLabelVisible: hasAdvancedFilters,
              smallSize: 8,
              child: const Icon(Icons.tune, size: 20),
            ),
            tooltip: 'Filtros avanzados',
            color: hasAdvancedFilters
                ? AppColors.brandAccent
                : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _AdvancedFiltersModal extends StatefulWidget {
  final List<TransactionType> types;
  final List<String> assets;
  final Set<TransactionType> selectedTypes;
  final Set<String> selectedAssets;
  final void Function(Set<TransactionType> types, Set<String> assets) onApply;
  final VoidCallback onClear;

  const _AdvancedFiltersModal({
    required this.types,
    required this.assets,
    required this.selectedTypes,
    required this.selectedAssets,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_AdvancedFiltersModal> createState() => _AdvancedFiltersModalState();
}

class _AdvancedFiltersModalState extends State<_AdvancedFiltersModal> {
  late Set<TransactionType> _selectedTypes;
  late Set<String> _selectedAssets;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set.from(widget.selectedTypes);
    _selectedAssets = Set.from(widget.selectedAssets);
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return 'Depósito';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.trade:
        return 'Trade';
      case TransactionType.interest:
        return 'Interés';
      case TransactionType.fee:
        return 'Fee';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.trade:
        return Icons.swap_horiz;
      case TransactionType.interest:
        return Icons.savings;
      case TransactionType.fee:
        return Icons.money_off;
      case TransactionType.transfer:
        return Icons.sync_alt;
    }
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdrawal:
        return AppColors.error;
      case TransactionType.trade:
        return AppColors.brandAccent;
      case TransactionType.interest:
        return AppColors.success;
      case TransactionType.fee:
        return AppColors.error;
      case TransactionType.transfer:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros avanzados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onClear,
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border),

            // Filters
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Type filter section
                  const Text(
                    'Tipo de transacción',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.types.map((type) {
                      final isSelected = _selectedTypes.contains(type);
                      final typeColor = _getTypeColor(type);
                      return FilterChip(
                        label: Text(_getTypeLabel(type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTypes.add(type);
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                        },
                        avatar: Icon(
                          _getTypeIcon(type),
                          size: 16,
                          color: typeColor,
                        ),
                        showCheckmark: false,
                        selectedColor: typeColor.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? typeColor : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Asset filter section
                  const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.assets.map((asset) {
                      final isSelected = _selectedAssets.contains(asset);
                      return FilterChip(
                        label: Text(asset),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAssets.add(asset);
                            } else {
                              _selectedAssets.remove(asset);
                            }
                          });
                        },
                        avatar: AssetLogo(asset: asset, size: 20),
                        showCheckmark: false,
                        selectedColor: AppColors.brandAccent.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? AppColors.brandAccent : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Apply button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onApply(_selectedTypes, _selectedAssets),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandAccent,
                    foregroundColor: AppColors.bgPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Aplicar filtros${_selectedTypes.isNotEmpty || _selectedAssets.isNotEmpty ? ' (${_selectedTypes.length + _selectedAssets.length})' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    final amountFormat = NumberFormat.decimalPattern();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              // Type icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getTypeColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(),
                  size: 18,
                  color: _getTypeColor(),
                ),
              ),
              const SizedBox(width: 12),

              // Type and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeLabel(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _getTypeColor(),
                      ),
                    ),
                    Text(
                      dateFormat.format(transaction.timestamp),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Exchange badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExchangeLogo(exchange: transaction.exchange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      formatExchangeName(transaction.exchange),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Details row
          Row(
            children: [
              // Asset
              AssetLogo(asset: transaction.asset, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.pair ?? transaction.asset,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (transaction.side != null)
                      Text(
                        transaction.side!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: transaction.side == 'buy'
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${amountFormat.format(transaction.amount)} ${transaction.asset}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color:
                          transaction.amount >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                  if (transaction.price != null)
                    Text(
                      '@\$${amountFormat.format(transaction.price)}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Fee info
          if (transaction.fee != null && transaction.fee! > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.info_outline,
                    size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Fee: ${amountFormat.format(transaction.fee)} ${transaction.feeAsset ?? transaction.asset}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getTypeLabel() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return 'Depósito';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.trade:
        return 'Trade';
      case TransactionType.interest:
        return 'Interés';
      case TransactionType.fee:
        return 'Fee';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.trade:
        return Icons.swap_horiz;
      case TransactionType.interest:
        return Icons.savings;
      case TransactionType.fee:
        return Icons.money_off;
      case TransactionType.transfer:
        return Icons.sync_alt;
    }
  }

  Color _getTypeColor() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdrawal:
        return AppColors.error;
      case TransactionType.trade:
        return AppColors.brandAccent;
      case TransactionType.interest:
        return AppColors.success;
      case TransactionType.fee:
        return AppColors.error;
      case TransactionType.transfer:
        return AppColors.warning;
    }
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ShimmerCard(height: 130),
          ),
        ),
      ),
    );
  }
}
