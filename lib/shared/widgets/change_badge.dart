import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ChangeBadge extends StatelessWidget {
  final double? change;
  final bool showIcon;
  final bool compact;

  const ChangeBadge({
    super.key,
    this.change,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (change == null) {
      return const SizedBox.shrink();
    }

    final isPositive = change! >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final bgColor = color.withOpacity(0.15);
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = isPositive ? '+' : '';
    final text = '$sign${change!.toStringAsFixed(2)}%';

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: AppTextStyles.monoXSmall.copyWith(color: color),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTextStyles.monoSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeText extends StatelessWidget {
  final double? change;
  final double fontSize;
  final bool showSign;

  const ChangeText({
    super.key,
    this.change,
    this.fontSize = 14,
    this.showSign = true,
  });

  @override
  Widget build(BuildContext context) {
    if (change == null) {
      return Text(
        '--',
        style: TextStyle(
          fontSize: fontSize,
          color: AppColors.textTertiary,
        ),
      );
    }

    final isPositive = change! >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final sign = showSign && isPositive ? '+' : '';

    return Text(
      '$sign${change!.toStringAsFixed(2)}%',
      style: AppTextStyles.monoSmall.copyWith(
        color: color,
        fontSize: fontSize,
      ),
    );
  }
}

class PriceChange extends StatelessWidget {
  final double? changeUsd;
  final double? changePercent;

  const PriceChange({
    super.key,
    this.changeUsd,
    this.changePercent,
  });

  @override
  Widget build(BuildContext context) {
    if (changeUsd == null && changePercent == null) {
      return const SizedBox.shrink();
    }

    final isPositive = (changeUsd ?? changePercent ?? 0) >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final bgColor = color.withOpacity(0.15);
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (changeUsd != null)
            Text(
              '$sign\$${changeUsd!.abs().toStringAsFixed(2)}',
              style: AppTextStyles.monoSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (changeUsd != null && changePercent != null)
            const SizedBox(width: 6),
          if (changePercent != null)
            Text(
              '($sign${changePercent!.toStringAsFixed(2)}%)',
              style: AppTextStyles.monoXSmall.copyWith(color: color),
            ),
        ],
      ),
    );
  }
}
