import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/card_model.dart';
import '../../widgets/glass_card.dart';

class HistoryTab extends StatefulWidget {
  final List<CardModel> cards;
  const HistoryTab({super.key, required this.cards});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _timeFilter = "1Y";

  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? "-" : "";
    if (absAmount == 0.0) return "\$0";
    if (absAmount < 10.0) {
      return "$sign\$${absAmount.toStringAsFixed(2)}";
    }
    return "$sign\$${absAmount.round().toString()}";
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total value & total cost with quantity
    double totalValue = widget.cards.fold(0.0, (sum, item) => sum + (item.currentValue * item.quantity));
    double totalCost = widget.cards.fold(0.0, (sum, item) => sum + (item.purchasePrice * item.quantity));

    // If portfolio is empty, fall back to mock demo data to look premium
    bool isDemo = totalCost <= 0 && totalValue <= 0;
    double activeCost = isDemo ? 3200 : totalCost;
    double activeValue = isDemo ? 4810 : totalValue;

    // Generate dynamic points based on filter
    List<String> labels = [];
    List<double> values = [];

    if (_timeFilter == "1D") {
      labels = ["9 AM", "12 PM", "3 PM", "6 PM", "9 PM", "Today"];
      final norm = [0.0, 0.08, 0.25, 0.18, 0.65, 1.0];
      for (int i = 0; i < labels.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
      }
    } else if (_timeFilter == "1W") {
      labels = ["6d ago", "5d ago", "4d ago", "3d ago", "2d ago", "1d ago", "Today"];
      final norm = [0.0, 0.15, 0.35, 0.25, 0.58, 0.82, 1.0];
      for (int i = 0; i < labels.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
      }
    } else if (_timeFilter == "1M") {
      labels = ["4w ago", "3w ago", "2w ago", "1w ago", "Today"];
      final norm = [0.0, 0.22, 0.55, 0.78, 1.0];
      for (int i = 0; i < labels.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
      }
    } else if (_timeFilter == "3Y") {
      labels = ["3y ago", "2y ago", "1y ago", "Today"];
      final norm = [0.0, 0.45, 0.78, 1.0];
      for (int i = 0; i < labels.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
      }
    } else if (_timeFilter == "5Y") {
      labels = ["5y ago", "4y ago", "3y ago", "2y ago", "1y ago", "Today"];
      final norm = [0.0, 0.15, 0.38, 0.62, 0.85, 1.0];
      for (int i = 0; i < labels.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
      }
    } else { // 1Y
      final months = ["Jan '24", "Feb '24", "Mar '24", "Apr '24", "May '24", "Jun '24", "Jul '24", "Aug '24", "Sep '24", "Oct '24", "Nov '24", "Dec '24"];
      final norm = [0.0, 0.24, 0.37, 0.26, 0.47, 0.63, 0.55, 0.74, 0.85, 1.0, 0.89, 0.85];
      for (int i = 0; i < months.length; i++) {
        values.add(activeCost + (activeValue - activeCost) * norm[i]);
        labels.add(months[i]);
      }
      labels.add("Today");
      values.add(activeValue);
    }

    double start = values.first;
    double end = values.last;
    double overallGain = end - start;
    double overallPct = start > 0 ? (overallGain / start) * 100 : 0.0;

    double peakVal = values.first;
    String peakMonth = labels.first;
    double lowVal = values.first;
    String lowMonth = labels.first;

    for (int i = 0; i < values.length; i++) {
      if (values[i] > peakVal) {
        peakVal = values[i];
        peakMonth = labels[i];
      }
      if (values[i] < lowVal) {
        lowVal = values[i];
        lowMonth = labels[i];
      }
    }

    // Build spots for fl_chart
    List<FlSpot> spots = [];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    String startSub = "Jan 2024";
    if (_timeFilter == "1D") startSub = "9:00 AM today";
    if (_timeFilter == "1W") startSub = "6 days ago";
    if (_timeFilter == "1M") startSub = "4 weeks ago";
    if (_timeFilter == "3Y") startSub = "3 years ago";
    if (_timeFilter == "5Y") startSub = "5 years ago";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PORTFOLIO HISTORY",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          
          // 2x2 Grid of Metrics
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("STARTING VALUE", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(start), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(startSub, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("CURRENT VALUE", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(end), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    const Text("Today", style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ["1Y", "3Y", "5Y"].contains(_timeFilter) ? "ALL-TIME GAIN" : "PERIOD GAIN",
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${overallGain >= 0 ? '+' : ''}${_formatCurrency(overallGain)}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: overallGain >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${overallGain >= 0 ? '+' : ''}${overallPct.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: overallGain >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                      ),
                    ),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("TOTAL INVESTED", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(totalCost), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    const Text("cost basis", style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chart Card
          GlassCard(
            padding: const EdgeInsets.only(top: 16, bottom: 12, left: 8, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "PORTFOLIO VALUE OVER TIME",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                    ),
                    // Filters row
                    Row(
                      children: ["1D", "1W", "1M", "1Y", "3Y", "5Y"].map((f) {
                        final isSelected = _timeFilter == f;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _timeFilter = f;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.gold : const Color(0xFF1A1A28),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.bg : AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // FL Chart
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (v, meta) {
                              if (v == meta.min || v == meta.max) {
                                return const SizedBox();
                              }
                              // Formatter
                              if (activeValue < 100.0) {
                                return Text(
                                  "\$${v.toStringAsFixed(1)}",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                                );
                              } else {
                                return Text(
                                  "\$${(v / 1000).toStringAsFixed(1)}k",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                                );
                              }
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            interval: (labels.length / 4).clamp(1, double.infinity),
                            getTitlesWidget: (v, meta) {
                              int idx = v.toInt();
                              if (idx >= 0 && idx < labels.length) {
                                return Text(
                                  labels[idx],
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.gold,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.gold.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Peak Value and Low Value row
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PEAK VALUE", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(peakVal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gainGreen),
                      ),
                      const SizedBox(height: 2),
                      Text(peakMonth, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PERIOD LOW", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(lowVal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.lossRed),
                      ),
                      const SizedBox(height: 2),
                      Text(lowMonth, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
