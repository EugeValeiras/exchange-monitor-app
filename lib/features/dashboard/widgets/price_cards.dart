import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/price_service.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/change_badge.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/favorite_button.dart';

class PriceCardsWidget extends StatelessWidget {
  const PriceCardsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final balanceService = context.watch<BalanceService>();
    final priceService = context.watch<PriceService>();
    final chartService = context.watch<ChartService>();
    final favoritesService = context.watch<FavoritesService>();

    // Get favorites
    final favorites = favoritesService.favorites;

    if (favoritesService.isLoading) {
      return const _PriceCardsSkeleton();
    }

    if (favorites.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.star_border,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay favoritos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Marca activos como favoritos desde Balances',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and connection indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mercados Favoritos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (chartService.hasAssetFilter)
                GestureDetector(
                  onTap: () => chartService.clearAssetFilter(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: AppColors.brandAccent),
                        SizedBox(width: 4),
                        Text(
                          'Limpiar filtro',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _ConnectionIndicator(isConnected: priceService.isConnected),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: favorites.length.clamp(0, 6),
          itemBuilder: (context, index) {
            final assetSymbol = favorites[index];
            final balanceAsset = balanceService.assets.where((a) => a.asset.toUpperCase() == assetSymbol).firstOrNull;
            final isSelected = chartService.isAssetSelected(assetSymbol);
            return _PriceCard(
              asset: assetSymbol,
              price: priceService.getPriceByAsset(assetSymbol) ?? balanceAsset?.priceUsd,
              change24h: priceService.getChange24hByAsset(assetSymbol) ?? balanceAsset?.change24h,
              isSelected: isSelected,
              onTap: () => chartService.toggleAsset(assetSymbol),
            );
          },
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String asset;
  final double? price;
  final double? change24h;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PriceCard({
    required this.asset,
    this.price,
    this.change24h,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: price != null && price! >= 1 ? 2 : 4,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandAccent.withValues(alpha: 0.15)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brandAccent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header with logo and name
                  Row(
                    children: [
                      AssetLogo(asset: asset, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          asset,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isSelected ? AppColors.brandAccent : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Price
                  Text(
                    price != null ? currencyFormat.format(price) : '--',
                    style: AppTextStyles.monoMedium,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Change
                  ChangeBadge(change: change24h, compact: true),
                ],
              ),
            ),
            // Favorite button - top right
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(asset: asset, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const _ConnectionIndicator({required this.isConnected});

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
          isConnected ? 'En vivo' : 'Conectando...',
          style: TextStyle(
            fontSize: 12,
            color: isConnected ? AppColors.success : AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _PriceCardsSkeleton extends StatelessWidget {
  const _PriceCardsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LoadingShimmer(width: 80, height: 20),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => const ShimmerCard(),
        ),
      ],
    );
  }
}
