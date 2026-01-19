import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/models/chart_data.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class BalanceChartWidget extends StatelessWidget {
  final void Function(double? value, DateTime? date)? onTouchValue;

  const BalanceChartWidget({
    super.key,
    this.onTouchValue,
  });

  @override
  Widget build(BuildContext context) {
    final chartService = context.watch<ChartService>();

    return Column(
      children: [
        // Chart
        SizedBox(
          height: 250,
          child: chartService.isLoading
              ? const _ChartSkeleton()
              : chartService.hasData
                  ? _buildChart(context, chartService)
                  : const Center(
                      child: Text(
                        'No hay datos para este periodo',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
        ),
        const SizedBox(height: 16),
        // Timeframe toggles below chart
        _TimeframeToggle(
          selected: chartService.selectedTimeframe,
          onChanged: (tf) => chartService.setTimeframe(tf),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, ChartService chartService) {
    final balanceService = context.watch<BalanceService>();
    final points = chartService.getChartPoints();
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Create list of timestamps including current balance as last point
    final timestamps = points.map((p) => p.timestamp).toList();
    timestamps.add(DateTime.now());

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }
    // Add current value as the last point (filtered if there's a filter)
    final lastValue = chartService.hasAssetFilter
        ? (chartService.getFilteredLastValue() ?? points.last.value)
        : balanceService.totalValueUsd;
    spots.add(FlSpot(points.length.toDouble(), lastValue));

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.length.toDouble() - 1,
        minY: minY - padding,
        maxY: maxY + padding,
        lineTouchData: LineTouchData(
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlPanEndEvent || event is FlTapUpEvent || event is FlLongPressEnd) {
              // Touch ended - reset to current value
              onTouchValue?.call(null, null);
            } else if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              final index = spot.x.toInt();
              if (index >= 0 && index < timestamps.length) {
                onTouchValue?.call(spot.y, timestamps[index]);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipColor: (_) => AppColors.bgElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final isLastPoint = index == timestamps.length - 1;
                final date = index < timestamps.length ? timestamps[index] : DateTime.now();
                return LineTooltipItem(
                  isLastPoint ? 'Ahora' : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()),
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                const FlLine(
                  color: Colors.white38,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: AppColors.brandPrimary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.brandPrimary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.3),
                  AppColors.brandPrimary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeframeToggle extends StatelessWidget {
  final ChartTimeframe selected;
  final ValueChanged<ChartTimeframe> onChanged;

  const _TimeframeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ChartTimeframe.values.map((tf) {
        final isSelected = tf == selected;
        return GestureDetector(
          onTap: () => onChanged(tf),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tf.label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerCard(height: 200);
  }
}
