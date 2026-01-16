import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/price_service.dart';
import '../../../core/models/price.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/change_badge.dart';
import '../../../shared/widgets/empty_state.dart';

class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  Set<String> _selectedExchanges = {};
  Set<String> _selectedAssets = {};
  Set<String> _selectedQuotes = {};

  bool get _hasAdvancedFilters => _selectedAssets.isNotEmpty || _selectedQuotes.isNotEmpty;

  List<PriceUpdate> _getFilteredPrices(PriceService priceService) {
    var prices = priceService.priceList;

    // Apply exchange filter
    if (_selectedExchanges.isNotEmpty) {
      prices = prices.where((p) => p.source != null && _selectedExchanges.contains(p.source)).toList();
    }

    // Apply asset filter
    if (_selectedAssets.isNotEmpty) {
      prices = prices.where((p) => _selectedAssets.contains(p.asset)).toList();
    }

    // Apply quote filter
    if (_selectedQuotes.isNotEmpty) {
      prices = prices.where((p) => _selectedQuotes.contains(p.quote)).toList();
    }

    // Sort by asset name
    prices.sort((a, b) => a.asset.compareTo(b.asset));
    return prices;
  }

  void _showAdvancedFilters(BuildContext context, List<PriceUpdate> allPrices) {
    // Get unique assets and quotes from all prices
    final assets = allPrices.map((p) => p.asset).toSet().toList()..sort();
    final quotes = allPrices.map((p) => p.quote).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _AdvancedFiltersModal(
        assets: assets,
        quotes: quotes,
        selectedAssets: _selectedAssets,
        selectedQuotes: _selectedQuotes,
        onApply: (assets, quotes) {
          setState(() {
            _selectedAssets = assets;
            _selectedQuotes = quotes;
          });
          Navigator.pop(context);
        },
        onClear: () {
          setState(() {
            _selectedAssets = {};
            _selectedQuotes = {};
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceService = context.watch<PriceService>();
    final allPrices = priceService.priceList;
    final prices = _getFilteredPrices(priceService);

    // Get unique exchanges
    final exchanges = allPrices.map((p) => p.source).whereType<String>().toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Precios'),
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ConnectionStatus(
              isConnected: priceService.isConnected,
              binance: priceService.binanceConnected,
              kraken: priceService.krakenConnected,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _ExchangeFilterBar(
            exchanges: exchanges,
            selectedExchanges: _selectedExchanges,
            hasAdvancedFilters: _hasAdvancedFilters,
            onExchangeToggled: (e) => setState(() {
              if (_selectedExchanges.contains(e)) {
                _selectedExchanges.remove(e);
              } else {
                _selectedExchanges.add(e);
              }
            }),
            onAdvancedPressed: () => _showAdvancedFilters(context, allPrices),
          ),

          // Price list
          Expanded(
            child: priceService.isConnecting && prices.isEmpty
                ? const LoadingState(message: 'Conectando...')
                : prices.isEmpty
                    ? const EmptyState(
                        icon: Icons.show_chart,
                        title: 'Sin precios',
                        subtitle: 'No hay precios disponibles',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          // Reconnect to refresh prices
                          priceService.disconnect();
                          priceService.connect();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: prices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _PriceListItem(price: prices[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final bool binance;
  final bool kraken;

  const _ConnectionStatus({
    required this.isConnected,
    required this.binance,
    required this.kraken,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? AppColors.success : AppColors.warning,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? 'En vivo' : 'Offline',
          style: TextStyle(
            fontSize: 12,
            color: isConnected ? AppColors.success : AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _ExchangeFilterBar extends StatelessWidget {
  final List<String> exchanges;
  final Set<String> selectedExchanges;
  final bool hasAdvancedFilters;
  final ValueChanged<String> onExchangeToggled;
  final VoidCallback onAdvancedPressed;

  const _ExchangeFilterBar({
    required this.exchanges,
    required this.selectedExchanges,
    required this.hasAdvancedFilters,
    required this.onExchangeToggled,
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
                children: [
                  ...exchanges.map((e) {
                    final isSelected = selectedExchanges.contains(e);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(formatExchangeName(e)),
                        selected: isSelected,
                        onSelected: (_) => onExchangeToggled(e),
                        avatar: ExchangeLogo(exchange: e, size: 16),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.brandAccent.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? AppColors.brandAccent : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
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
  final List<String> assets;
  final List<String> quotes;
  final Set<String> selectedAssets;
  final Set<String> selectedQuotes;
  final void Function(Set<String> assets, Set<String> quotes) onApply;
  final VoidCallback onClear;

  const _AdvancedFiltersModal({
    required this.assets,
    required this.quotes,
    required this.selectedAssets,
    required this.selectedQuotes,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_AdvancedFiltersModal> createState() => _AdvancedFiltersModalState();
}

class _AdvancedFiltersModalState extends State<_AdvancedFiltersModal> {
  late Set<String> _selectedAssets;
  late Set<String> _selectedQuotes;

  @override
  void initState() {
    super.initState();
    _selectedAssets = Set.from(widget.selectedAssets);
    _selectedQuotes = Set.from(widget.selectedQuotes);
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
                  // Asset filter section
                  const Text(
                    'Activo (moneda base)',
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

                  const SizedBox(height: 24),

                  // Quote filter section
                  const Text(
                    'Moneda cotización (quote)',
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
                    children: widget.quotes.map((quote) {
                      final isSelected = _selectedQuotes.contains(quote);
                      return FilterChip(
                        label: Text(quote),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedQuotes.add(quote);
                            } else {
                              _selectedQuotes.remove(quote);
                            }
                          });
                        },
                        avatar: AssetLogo(asset: quote, size: 20),
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
                  onPressed: () => widget.onApply(_selectedAssets, _selectedQuotes),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandAccent,
                    foregroundColor: AppColors.bgPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Aplicar filtros${_selectedAssets.isNotEmpty || _selectedQuotes.isNotEmpty ? ' (${_selectedAssets.length + _selectedQuotes.length})' : ''}',
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

class _PriceListItem extends StatelessWidget {
  final PriceUpdate price;

  const _PriceListItem({required this.price});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: price.price >= 1 ? 2 : 6,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Pair logos (asset + quote)
          PairLogos(
            asset: price.asset,
            quote: price.quote,
            size: 44,
          ),
          const SizedBox(width: 12),

          // Asset info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.asset,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      price.symbol,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (price.source != null) ...[
                      const SizedBox(width: 8),
                      ExchangeLogo(exchange: price.source!, size: 14),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Price and change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(price.price),
                style: AppTextStyles.monoMedium,
              ),
              const SizedBox(height: 4),
              ChangeBadge(change: price.change24h, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
