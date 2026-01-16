import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/models/chart_data.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class BalanceChartWidget extends StatelessWidget {
  const BalanceChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final chartService = context.watch<ChartService>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with timeframe toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance History',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                _TimeframeToggle(
                  selected: chartService.selectedTimeframe,
                  onChanged: (tf) => chartService.setTimeframe(tf),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chart
            SizedBox(
              height: 200,
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
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, ChartService chartService) {
    final points = chartService.getChartPoints();
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final isPositive = chartService.changePercent >= 0;
    final lineColor = isPositive ? AppColors.success : AppColors.error;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${_formatNumber(value)}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (spots.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox();

                final date = points[index].timestamp;
                String label;
                switch (chartService.selectedTimeframe) {
                  case ChartTimeframe.h24:
                    label = DateFormat('HH:mm').format(date);
                    break;
                  case ChartTimeframe.d7:
                    label = DateFormat('E d').format(date);
                    break;
                  case ChartTimeframe.m1:
                  case ChartTimeframe.y1:
                    label = DateFormat('d MMM').format(date);
                    break;
                }

                return Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.length.toDouble() - 1,
        minY: minY - padding,
        maxY: maxY + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.bgElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index < points.length ? points[index].timestamp : DateTime.now();
                return LineTooltipItem(
                  '${DateFormat('dd/MM HH:mm').format(date)}\n\$${NumberFormat('#,##0.00').format(spot.y)}',
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.4,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ChartTimeframe.values.map((tf) {
          final isSelected = tf == selected;
          return GestureDetector(
            onTap: () => onChanged(tf),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tf.label,
                style: TextStyle(
                  color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
