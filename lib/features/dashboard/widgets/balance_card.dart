import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/balance_service.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/change_badge.dart';

class BalanceCard extends StatelessWidget {
  final bool? hideSmallBalances;
  final VoidCallback? onToggleSmallBalances;

  const BalanceCard({
    super.key,
    this.hideSmallBalances,
    this.onToggleSmallBalances,
  });

  @override
  Widget build(BuildContext context) {
    final balanceService = context.watch<BalanceService>();
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (balanceService.isLoading && !balanceService.hasData) {
      return const _BalanceCardSkeleton();
    }

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              if (hideSmallBalances != null && onToggleSmallBalances != null)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: onToggleSmallBalances,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      hideSmallBalances! ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.white54,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Total value
          Text(
            hideSmallBalances == true
                ? '••••••'
                : currencyFormat.format(balanceService.totalValueUsd),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),

          // 24h change
          if (balanceService.change24h != null ||
              balanceService.changeUsd24h != null) ...[
            if (hideSmallBalances == true)
              const Text(
                '••••••',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
            else
              PriceChange(
                changeUsd: balanceService.changeUsd24h,
                changePercent: balanceService.change24h,
              ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingShimmer(width: 100, height: 14),
          const SizedBox(height: 16),
          const LoadingShimmer(width: 180, height: 36),
          const SizedBox(height: 16),
          const LoadingShimmer(width: 140, height: 28),
        ],
      ),
    );
  }
}
