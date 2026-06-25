import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/glass_card.dart';

class GradingTab extends StatefulWidget {
  const GradingTab({super.key});

  @override
  State<GradingTab> createState() => _GradingTabState();
}

class _GradingTabState extends State<GradingTab> {
  final _playerController = TextEditingController();
  final _rawController = TextEditingController();
  final _psa10Controller = TextEditingController();
  final _psa9Controller = TextEditingController();
  final _costController = TextEditingController(text: "50");
  String _selectedTier = "Value";
  String _aiAdvice = "";
  bool _loading = false;

  void _calculate() {
    double raw = double.tryParse(_rawController.text) ?? 0.0;
    double p10 = double.tryParse(_psa10Controller.text) ?? 0.0;
    double p9 = double.tryParse(_psa9Controller.text) ?? 0.0;
    double cost = double.tryParse(_costController.text) ?? 50.0;

    if (raw == 0.0) return;

    double roi10 = ((p10 - raw - cost) / (raw + cost)) * 100;
    double roi9 = ((p9 - raw - cost) / (raw + cost)) * 100;
    double breakeven = raw + cost;

    String verdict = "Skip";
    Color verdictColor = AppColors.lossRed;
    if (roi10 > 30) {
      verdict = "Submit";
      verdictColor = AppColors.gainGreen;
    } else if (roi10 > 0) {
      verdict = "Maybe";
      verdictColor = Colors.orange;
    }

    setState(() {
      _aiAdvice = "ROI PSA 10: ${roi10.toStringAsFixed(1)}%\nROI PSA 9: ${roi9.toStringAsFixed(1)}%\nBreakeven: \$${breakeven.toStringAsFixed(0)}\nVerdict: $verdict";
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("GRADING ROI CALCULATOR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text("Find out if submitting to PSA/BGS is worth it before you pay.", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextField(controller: _playerController, decoration: const InputDecoration(labelText: "Player / Card")),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _rawController, decoration: const InputDecoration(labelText: "Raw Value (\$)"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _psa10Controller, decoration: const InputDecoration(labelText: "PSA 10 Value (\$)"), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _psa9Controller, decoration: const InputDecoration(labelText: "PSA 9 Value (\$)"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _costController, decoration: const InputDecoration(labelText: "Grading Cost (\$)"), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
              ),
              child: const Text("Calculate ROI", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_aiAdvice.isNotEmpty) ...[
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CALCULATION RESULTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Text(_aiAdvice, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
