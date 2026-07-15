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

    final now = DateTime.now();

    DateTime getCutoff(String filter, String label) {
      final date = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
      if (filter == "1D") {
        if (label == "Today") return date;
        final hourMap = { "9 AM": 9, "12 PM": 12, "3 PM": 15, "6 PM": 18, "9 PM": 21 };
        final hr = hourMap[label] ?? 12;
        return DateTime(date.year, date.month, date.day, hr);
      }
      if (filter == "1W") {
        if (label == "Today") return date;
        final match = RegExp(r'^(\d+)d\sago$').firstMatch(label);
        final daysAgo = match != null ? int.parse(match.group(1)!) : 0;
        return date.subtract(Duration(days: daysAgo));
      }
      if (filter == "1M") {
        if (label == "Today") return date;
        final match = RegExp(r'^(\d+)w\sago$').firstMatch(label);
        final weeksAgo = match != null ? int.parse(match.group(1)!) : 0;
        return date.subtract(Duration(days: weeksAgo * 7));
      }
      if (filter == "3Y" || filter == "5Y") {
        if (label == "Today") return date;
        final match = RegExp(r'^(\d+)y\sago$').firstMatch(label);
        final yearsAgo = match != null ? int.parse(match.group(1)!) : 0;
        return DateTime(date.year - yearsAgo, date.month, date.day);
      }
      // 1Y Filter
      if (label == "Today") return date;
      final match = RegExp(r"^([A-Za-z]+)\s'(\d+)$").firstMatch(label);
      if (match != null) {
        final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        final mIdx = monthNames.indexOf(match.group(1)!);
        final year = 2000 + int.parse(match.group(2)!);
        return DateTime(year, mIdx + 2, 0, 23, 59, 59); // last day of month
      }
      return date;
    }

    double getPortfolioValueAt(DateTime cutoff) {
      double total = 0;
      bool hasAnyCard = false;
      for (final c in widget.cards) {
        final addedDate = c.addedAt.isNotEmpty ? DateTime.tryParse(c.addedAt) ?? DateTime(0) : DateTime(0);
        if (addedDate.isBefore(cutoff) || addedDate.isAtSameMomentAs(cutoff)) {
          total += c.currentValue * c.quantity;
          hasAnyCard = true;
        }
      }
      return hasAnyCard ? total : 0;
    }

    List<String> labels = [];
    List<double> values = [];

    bool isEmpty = widget.cards.isEmpty || (totalCost <= 0 && totalValue <= 0);
    double activeCost = totalCost;
    double activeValue = totalValue;

    if (isEmpty) {
      if (_timeFilter == "1D") {
        labels = ["9 AM", "12 PM", "3 PM", "6 PM", "9 PM", "Today"];
      } else if (_timeFilter == "1W") {
        labels = ["6d ago", "5d ago", "4d ago", "3d ago", "2d ago", "1d ago", "Today"];
      } else if (_timeFilter == "1M") {
        labels = ["4w ago", "3w ago", "2w ago", "1w ago", "Today"];
      } else if (_timeFilter == "3Y") {
        labels = ["3y ago", "2y ago", "1y ago", "Today"];
      } else if (_timeFilter == "5Y") {
        labels = ["5y ago", "4y ago", "3y ago", "2y ago", "1y ago", "Today"];
      } else { // 1Y
        final months = ["Jan '24", "Feb '24", "Mar '24", "Apr '24", "May '24", "Jun '24", "Jul '24", "Aug '24", "Sep '24", "Oct '24", "Nov '24", "Dec '24"];
        labels = [...months, "Today"];
      }
      for (int i = 0; i < labels.length; i++) {
        values.add(0.0);
      }
    } else {
      if (_timeFilter == "1D") {
        labels = ["9 AM", "12 PM", "3 PM", "6 PM", "9 PM", "Today"];
        for (final l in labels) {
          values.add(getPortfolioValueAt(getCutoff("1D", l)));
        }
      } else if (_timeFilter == "1W") {
        labels = ["6d ago", "5d ago", "4d ago", "3d ago", "2d ago", "1d ago", "Today"];
        for (final l in labels) {
          values.add(getPortfolioValueAt(getCutoff("1W", l)));
        }
      } else if (_timeFilter == "1M") {
        labels = ["4w ago", "3w ago", "2w ago", "1w ago", "Today"];
        for (final l in labels) {
          values.add(getPortfolioValueAt(getCutoff("1M", l)));
        }
      } else if (_timeFilter == "3Y") {
        labels = ["3y ago", "2y ago", "1y ago", "Today"];
        for (final l in labels) {
          values.add(getPortfolioValueAt(getCutoff("3Y", l)));
        }
      } else if (_timeFilter == "5Y") {
        labels = ["5y ago", "4y ago", "3y ago", "2y ago", "1y ago", "Today"];
        for (final l in labels) {
          values.add(getPortfolioValueAt(getCutoff("5Y", l)));
        }
      } else { // 1Y
        final months = <String>[];
        final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        for (int i = 11; i >= 0; i--) {
          final d = DateTime(now.year, now.month - i, 1);
          final yrShort = d.year.toString().substring(2);
          months.add("${monthNames[d.month - 1]} '$yrShort");
        }
        for (final m in months) {
          labels.add(m);
          values.add(getPortfolioValueAt(getCutoff("1Y", m)));
        }
        labels.add("Today");
        values.add(totalValue);
      }
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
                  child: isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.trending_up, size: 36, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text(
                              "No History Data Available",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Add cards to your Portfolio to start tracking history.",
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        )
                      : LineChart(
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
