import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/models/balance.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/change_badge.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/empty_state.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({super.key});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  Set<String> _selectedExchanges = {};
  bool _hideSmallBalances = false;

  double _getFilteredTotalValue(BalanceService balanceService) {
    if (_selectedExchanges.isEmpty) {
      return balanceService.totalValueUsd;
    }

    double total = 0;
    for (final exchangeBalance in balanceService.exchanges) {
      if (_selectedExchanges.contains(exchangeBalance.exchange)) {
        total += exchangeBalance.totalValueUsd;
      }
    }
    return total;
  }

  /// Calculate filtered 24h change in USD and percent based on selected exchanges
  ({double? changeUsd, double? changePercent}) _getFilteredChange24h(
    BalanceService balanceService,
    PriceService priceService,
  ) {
    if (_selectedExchanges.isEmpty) {
      return (changeUsd: balanceService.changeUsd24h, changePercent: balanceService.change24h);
    }

    // Get filtered assets
    final Map<String, AssetBalance> mergedAssets = {};
    for (final exchangeBalance in balanceService.exchanges) {
      if (_selectedExchanges.contains(exchangeBalance.exchange)) {
        for (final assetBalance in exchangeBalance.balances) {
          if (assetBalance.valueUsd == null || assetBalance.valueUsd == 0) continue;

          if (mergedAssets.containsKey(assetBalance.asset)) {
            final existing = mergedAssets[assetBalance.asset]!;
            mergedAssets[assetBalance.asset] = AssetBalance(
              asset: assetBalance.asset,
              free: existing.free + assetBalance.free,
              locked: existing.locked + assetBalance.locked,
              total: existing.total + assetBalance.total,
              priceUsd: assetBalance.priceUsd ?? existing.priceUsd,
              valueUsd: (existing.valueUsd ?? 0) + (assetBalance.valueUsd ?? 0),
              change24h: assetBalance.change24h ?? existing.change24h,
              exchanges: [...existing.exchanges, exchangeBalance.exchange],
            );
          } else {
            mergedAssets[assetBalance.asset] = assetBalance;
          }
        }
      }
    }

    // Calculate total current value and value 24h ago
    double totalCurrentValue = 0;
    double totalValue24hAgo = 0;

    for (final asset in mergedAssets.values) {
      final currentValue = asset.valueUsd ?? 0;
      if (currentValue == 0) continue;

      totalCurrentValue += currentValue;

      // Get change24h from PriceService or asset
      final change24h = priceService.getChange24hByAsset(asset.asset) ?? asset.change24h ?? 0;

      // Calculate value 24h ago: currentValue = value24hAgo * (1 + change/100)
      // So: value24hAgo = currentValue / (1 + change/100)
      final value24hAgo = currentValue / (1 + change24h / 100);
      totalValue24hAgo += value24hAgo;
    }

    if (totalValue24hAgo == 0) {
      return (changeUsd: null, changePercent: null);
    }

    final changeUsd = totalCurrentValue - totalValue24hAgo;
    final changePercent = ((totalCurrentValue - totalValue24hAgo) / totalValue24hAgo) * 100;

    return (changeUsd: changeUsd, changePercent: changePercent);
  }

  @override
  Widget build(BuildContext context) {
    final balanceService = context.watch<BalanceService>();
    final priceService = context.watch<PriceService>();
    final transactionService = context.watch<TransactionService>();

    // Get exchange names list
    final exchangeNames = balanceService.exchanges.map((e) => e.exchange).toList();

    // Calculate filtered change values
    final filteredChange = _getFilteredChange24h(balanceService, priceService);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Balances'),
      ),
      body: RefreshIndicator(
        onRefresh: () => balanceService.loadBalance(),
        child: balanceService.isLoading && !balanceService.hasData
            ? const _BalancesSkeleton()
            : CustomScrollView(
                slivers: [
                  // Total balance header
                  SliverToBoxAdapter(
                    child: _TotalBalanceHeader(
                      totalValue: _getFilteredTotalValue(balanceService),
                      change24h: filteredChange.changePercent,
                      changeUsd24h: filteredChange.changeUsd,
                      totalInterestUsd: transactionService.stats?.totalInterestUsd,
                      hideSmallBalances: _hideSmallBalances,
                      onToggleSmallBalances: () => setState(() => _hideSmallBalances = !_hideSmallBalances),
                    ),
                  ),

                  // Exchange filter chips
                  SliverToBoxAdapter(
                    child: _ExchangeFilters(
                      exchanges: exchangeNames,
                      selectedExchanges: _selectedExchanges,
                      onExchangeToggled: (e) => setState(() {
                        if (_selectedExchanges.contains(e)) {
                          _selectedExchanges.remove(e);
                        } else {
                          _selectedExchanges.add(e);
                        }
                      }),
                    ),
                  ),

                  // Assets list
                  _buildAssetsList(balanceService),
                ],
              ),
      ),
    );
  }

  Widget _buildAssetsList(BalanceService balanceService) {
    List<AssetBalance> assets;

    // Filter by exchange (multi-select) - use exchange-specific balances
    if (_selectedExchanges.isNotEmpty) {
      // Get balances from selected exchanges and merge same assets
      final Map<String, AssetBalance> mergedAssets = {};

      for (final exchangeBalance in balanceService.exchanges) {
        if (_selectedExchanges.contains(exchangeBalance.exchange)) {
          for (final assetBalance in exchangeBalance.balances) {
            if (mergedAssets.containsKey(assetBalance.asset)) {
              // Merge with existing
              final existing = mergedAssets[assetBalance.asset]!;
              mergedAssets[assetBalance.asset] = AssetBalance(
                asset: assetBalance.asset,
                free: existing.free + assetBalance.free,
                locked: existing.locked + assetBalance.locked,
                total: existing.total + assetBalance.total,
                priceUsd: assetBalance.priceUsd ?? existing.priceUsd,
                valueUsd: (existing.valueUsd ?? 0) + (assetBalance.valueUsd ?? 0),
                change24h: assetBalance.change24h ?? existing.change24h,
                exchanges: [...existing.exchanges, exchangeBalance.exchange],
              );
            } else {
              mergedAssets[assetBalance.asset] = AssetBalance(
                asset: assetBalance.asset,
                free: assetBalance.free,
                locked: assetBalance.locked,
                total: assetBalance.total,
                priceUsd: assetBalance.priceUsd,
                valueUsd: assetBalance.valueUsd,
                change24h: assetBalance.change24h,
                exchanges: [exchangeBalance.exchange],
              );
            }
          }
        }
      }
      assets = mergedAssets.values.toList();
    } else {
      assets = balanceService.assets;
    }

    // Only show assets with price
    assets = assets.where((a) => a.priceUsd != null).toList();

    // Sort by value descending
    assets.sort((a, b) => (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0));

    if (assets.isEmpty) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.account_balance_wallet,
          title: 'Sin balances',
          subtitle: 'No hay balances para mostrar',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AssetBalanceCard(
              asset: assets[index],
              hideValues: _hideSmallBalances,
            ),
          ),
          childCount: assets.length,
        ),
      ),
    );
  }
}

class _TotalBalanceHeader extends StatelessWidget {
  final double totalValue;
  final double? change24h;
  final double? changeUsd24h;
  final double? totalInterestUsd;
  final bool hideSmallBalances;
  final VoidCallback onToggleSmallBalances;

  const _TotalBalanceHeader({
    required this.totalValue,
    required this.hideSmallBalances,
    required this.onToggleSmallBalances,
    this.change24h,
    this.changeUsd24h,
    this.totalInterestUsd,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Balance Total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onToggleSmallBalances,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    hideSmallBalances ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hideSmallBalances ? '••••••' : currencyFormat.format(totalValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          if (change24h != null || changeUsd24h != null) ...[
            const SizedBox(height: 12),
            if (hideSmallBalances)
              const Text(
                '••••••',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
            else
              PriceChange(
                changeUsd: changeUsd24h,
                changePercent: change24h,
              ),
          ],
          if (totalInterestUsd != null && totalInterestUsd! > 0) ...[
            const SizedBox(height: 12),
            if (hideSmallBalances)
              const Text(
                '••••••',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.savings,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Intereses: ${currencyFormat.format(totalInterestUsd)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _ExchangeFilters extends StatelessWidget {
  final List<String> exchanges;
  final Set<String> selectedExchanges;
  final ValueChanged<String> onExchangeToggled;

  const _ExchangeFilters({
    required this.exchanges,
    required this.selectedExchanges,
    required this.onExchangeToggled,
  });

  @override
  Widget build(BuildContext context) {
    if (exchanges.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: exchanges.map((e) {
            final isSelected = selectedExchanges.contains(e);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(formatExchangeName(e)),
                selected: isSelected,
                onSelected: (_) => onExchangeToggled(e),
                avatar: ExchangeLogo(exchange: e, size: 16),
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
    );
  }
}

class _AssetBalanceCard extends StatefulWidget {
  final AssetBalance asset;
  final bool hideValues;

  const _AssetBalanceCard({
    required this.asset,
    this.hideValues = false,
  });

  @override
  State<_AssetBalanceCard> createState() => _AssetBalanceCardState();
}

class _AssetBalanceCardState extends State<_AssetBalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final favoritesService = context.read<FavoritesService>();

    HapticFeedback.mediumImpact();
    _animationController.forward(from: 0);

    await favoritesService.toggleFavorite(widget.asset.asset);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final amountFormat = NumberFormat.decimalPattern();

    final priceService = context.watch<PriceService>();
    final favoritesService = context.watch<FavoritesService>();
    final change24h = priceService.getChange24hByAsset(widget.asset.asset) ?? widget.asset.change24h;
    final isFavorite = favoritesService.isFavorite(widget.asset.asset);

    final isPositive = (change24h ?? 0) >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.error;

    return GestureDetector(
      onLongPress: _toggleFavorite,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Stack(
              children: [
                // Subtle gradient indicator based on change
                if (change24h != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            changeColor.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                      ),
                    ),
                  ),
                // Favorite indicator
                if (isFavorite)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: Icon(
                      Icons.star,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Logo
                      AssetLogo(asset: widget.asset.asset, size: 48),
                      const SizedBox(width: 14),

                      // Asset info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name and exchanges
                            Row(
                              children: [
                                Text(
                                  widget.asset.asset,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (widget.asset.exchanges.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  ...widget.asset.exchanges.take(3).map((e) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: ExchangeLogo(exchange: e, size: 18),
                                  )),
                                  if (widget.asset.exchanges.length > 3)
                                    Text(
                                      '+${widget.asset.exchanges.length - 3}',
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Amount
                            Text(
                              widget.hideValues
                                  ? '•••••••• ${widget.asset.asset}'
                                  : '${amountFormat.format(widget.asset.total)} ${widget.asset.asset}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Value and change
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // USD Value
                          Text(
                            widget.hideValues
                                ? '••••••'
                                : (widget.asset.valueUsd != null
                                    ? currencyFormat.format(widget.asset.valueUsd)
                                    : '--'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Change badge - more prominent
                          if (widget.hideValues)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.textTertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '••••',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: changeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                    color: changeColor,
                                    size: 20,
                                  ),
                                  Text(
                                    '${isPositive ? '+' : ''}${(change24h ?? 0).toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: changeColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _BalancesSkeleton extends StatelessWidget {
  const _BalancesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          const ShimmerCard(height: 140),
          const SizedBox(height: 16),
          // Filter chips skeleton
          Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LoadingShimmer(width: 80, height: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Asset cards skeleton
          ...List.generate(
            4,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerCard(height: 160),
            ),
          ),
        ],
      ),
    );
  }
}
