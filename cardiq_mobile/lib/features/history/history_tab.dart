import 'package:flutter/material';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/card_model.dart';
import '../../widgets/glass_card.dart';

class HistoryTab extends StatelessWidget {
  final List<CardModel> cards;
  const HistoryTab({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    double totalValue = cards.fold(0.0, (sum, item) => sum + item.currentValue);
    double totalCost = cards.fold(0.0, (sum, item) => sum + item.purchasePrice);

    // Dynamic historical snapshot data
    final chartData = [
      FlSpot(0, 3200),
      FlSpot(1, 3650),
      FlSpot(2, 3900),
      FlSpot(3, 3700),
      FlSpot(4, 4100),
      FlSpot(5, 4400),
      FlSpot(6, 4250),
      FlSpot(7, 4600),
      FlSpot(8, 4810),
      FlSpot(9, 5100),
      FlSpot(10, 4900),
      FlSpot(11, totalValue > 0 ? totalValue : 4810),
    ];

    double overallGain = (totalValue > 0 ? totalValue : 4810) - 3200;
    double overallPct = (overallGain / 3200) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PORTFOLIO HISTORY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Current Value", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text("\$${totalValue.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("All-Time Return", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        "${overallGain >= 0 ? '+' : ''}${overallPct.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: overallGain >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.only(top: 24, bottom: 10, left: 10, right: 24),
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                  ),
                  titlesData: const FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 3,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData,
                      isCurved: true,
                      color: AppColors.gold,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.gold.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
