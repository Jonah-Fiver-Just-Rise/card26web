import 'package:flutter/material';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/card_model.dart';
import '../../widgets/glass_card.dart';

class PortfolioTab extends StatefulWidget {
  final String uid;
  const PortfolioTab({super.key, required this.uid});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  final _playerController = TextEditingController();
  final _yearController = TextEditingController();
  final _setController = TextEditingController();
  final _gradeController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedSport = "Basketball";

  void _showAddCardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add Card to Collection",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(controller: _playerController, decoration: const InputDecoration(labelText: "Player Name")),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _yearController, decoration: const InputDecoration(labelText: "Year"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSport,
                        decoration: const InputDecoration(labelText: "Sport"),
                        dropdownColor: AppColors.cardBg,
                        items: ["Basketball", "Baseball", "Football", "Hockey", "Soccer"]
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedSport = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _setController, decoration: const InputDecoration(labelText: "Set / Product")),
                const SizedBox(height: 10),
                TextField(controller: _gradeController, decoration: const InputDecoration(labelText: "Grade (e.g. PSA 10)")),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _purchaseController, decoration: const InputDecoration(labelText: "Purchase Price (\$)"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _valueController, decoration: const InputDecoration(labelText: "Current Value (\$)"), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_playerController.text.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('users/${widget.uid}/portfolios')
                          .add({
                        'player': _playerController.text.trim(),
                        'year': int.tryParse(_yearController.text) ?? DateTime.now().year,
                        'sport': _selectedSport,
                        'set': _setController.text.trim(),
                        'grade': _gradeController.text.trim(),
                        'purchasePrice': double.tryParse(_purchaseController.text) ?? 0.0,
                        'currentValue': double.tryParse(_valueController.text) ?? 0.0,
                        'addedAt': DateTime.now().toIso8601String(),
                      });
                      _playerController.clear();
                      _yearController.clear();
                      _setController.clear();
                      _gradeController.clear();
                      _purchaseController.clear();
                      _valueController.clear();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    child: const Text("Save Card", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users/${widget.uid}/portfolios')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        final cards = snapshot.data!.docs.map((doc) => CardModel.fromFirestore(doc)).toList();

        double totalCost = cards.fold(0.0, (sum, item) => sum + item.purchasePrice);
        double totalValue = cards.fold(0.0, (sum, item) => sum + item.currentValue);
        double totalReturn = totalValue - totalCost;
        double returnPct = totalCost > 0 ? (totalReturn / totalCost) * 100 : 0.0;

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Top Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Value", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text("\$${totalValue.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Invested", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text("\$${totalCost.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Return", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text(
                              "${totalReturn >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: totalReturn >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    const Text(
                      "COLLECTION",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1),
                    ),
                    TextButton.icon(
                      onPressed: _showAddCardSheet,
                      icon: const Icon(Icons.add, size: 16, color: AppColors.gold),
                      label: const Text("Add Card", style: TextStyle(color: AppColors.gold, fontSize: 13)),
                    ),
                  ],
                ),
                Expanded(
                  child: cards.isEmpty
                      ? const Center(
                          child: Text("Your portfolio is empty.", style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.separated(
                          itemCount: cards.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            final gain = card.currentValue - card.purchasePrice;
                            final pct = card.purchasePrice > 0 ? (gain / card.purchasePrice) * 100 : 0.0;
                            return GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.between,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${card.year} ${card.player}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${card.set} · ${card.grade} · ${card.sport}",
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("\$${card.currentValue.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.extrabold, fontSize: 15)),
                                          Text(
                                            "${gain >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: gain >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .doc('users/${widget.uid}/portfolios/${card.id}')
                                              .delete();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
