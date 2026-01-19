import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/balance_service.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/change_badge.dart';

class BalanceCard extends StatelessWidget {
  final bool? hideSmallBalances;
  final VoidCallback? onToggleSmallBalances;
  final double? overrideValue;
  final DateTime? overrideDate;
  final String? filterLabel;
  final double? filteredChangePercent;
  final double? filteredChangeUsd;

  const BalanceCard({
    super.key,
    this.hideSmallBalances,
    this.onToggleSmallBalances,
    this.overrideValue,
    this.overrideDate,
    this.filterLabel,
    this.filteredChangePercent,
    this.filteredChangeUsd,
  });

  @override
  Widget build(BuildContext context) {
    final balanceService = context.watch<BalanceService>();
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (balanceService.isLoading && !balanceService.hasData) {
      return const _BalanceCardSkeleton();
    }

    // Use override value if provided, otherwise use current balance
    final displayValue = overrideValue ?? balanceService.totalValueUsd;
    final isShowingOverride = overrideValue != null;
    final isShowingFilter = filterLabel != null;

    // Determine the label
    String label;
    if (filterLabel != null) {
      label = filterLabel!;
    } else if (isShowingOverride) {
      label = 'Balance Histórico';
    } else {
      label = 'Balance Total';
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
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
          const SizedBox(height: 8),

          // Total value
          Text(
            hideSmallBalances == true
                ? '••••••'
                : currencyFormat.format(displayValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),

          // Show change - historical diff when touching chart, otherwise 24h change
          if (hideSmallBalances == true)
            const Text(
              '••••••',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            )
          else if (isShowingOverride) ...[
            // Show difference from current value to historical point
            Builder(builder: (context) {
              final currentValue = balanceService.totalValueUsd;
              final historicalValue = overrideValue!;
              final diffUsd = historicalValue - currentValue;
              final diffPercent = currentValue != 0
                  ? (diffUsd / currentValue) * 100
                  : 0.0;
              return PriceChange(
                changeUsd: diffUsd,
                changePercent: diffPercent,
                label: 'vs ahora',
              );
            }),
          ] else ...[
            if (isShowingFilter && (filteredChangePercent != null || filteredChangeUsd != null))
              PriceChange(
                changeUsd: filteredChangeUsd,
                changePercent: filteredChangePercent,
              )
            else if (!isShowingFilter &&
                (balanceService.change24h != null ||
                    balanceService.changeUsd24h != null))
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingShimmer(width: 100, height: 14),
          SizedBox(height: 16),
          LoadingShimmer(width: 180, height: 36),
          SizedBox(height: 16),
          LoadingShimmer(width: 140, height: 28),
        ],
      ),
    );
  }
}
