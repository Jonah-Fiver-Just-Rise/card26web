import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/watchlist_model.dart';
import '../../widgets/glass_card.dart';

class WatchlistTab extends StatefulWidget {
  final String uid;
  const WatchlistTab({super.key, required this.uid});

  @override
  State<WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends State<WatchlistTab> {
  final _playerController = TextEditingController();
  final _yearController = TextEditingController();
  final _setController = TextEditingController();
  final _gradeController = TextEditingController();
  final _targetController = TextEditingController();
  final _estController = TextEditingController();
  String _selectedSport = "Basketball";

  String _formatCurrency(double amount) {
    if (amount <= 0) return "\$0";
    if (amount < 10.0) {
      return "\$${amount.toStringAsFixed(2)}";
    }
    return "\$${amount.round().toString()}";
  }

  void _showAddWatchlistSheet() {
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
                  "Add Card to Watchlist",
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
                    Expanded(child: TextField(controller: _targetController, decoration: const InputDecoration(labelText: "Target Buy Price (\$)"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _estController, decoration: const InputDecoration(labelText: "Current Est. Value (\$)"), keyboardType: TextInputType.number)),
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
                          .collection('users/${widget.uid}/watchlists')
                          .add({
                        'player': _playerController.text.trim(),
                        'year': int.tryParse(_yearController.text) ?? DateTime.now().year,
                        'sport': _selectedSport,
                        'set': _setController.text.trim(),
                        'grade': _gradeController.text.trim(),
                        'targetBuy': double.tryParse(_targetController.text) ?? 0.0,
                        'currentEst': double.tryParse(_estController.text) ?? 0.0,
                        'alert': false,
                        'addedAt': DateTime.now().toIso8601String(),
                      });
                      _playerController.clear();
                      _yearController.clear();
                      _setController.clear();
                      _gradeController.clear();
                      _targetController.clear();
                      _estController.clear();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    child: const Text("Add to Watchlist", style: TextStyle(fontWeight: FontWeight.bold)),
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
          .collection('users/${widget.uid}/watchlists')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        final items = snapshot.data!.docs.map((doc) => WatchlistModel.fromFirestore(doc)).toList();

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "WATCHLIST",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1),
                    ),
                    TextButton.icon(
                      onPressed: _showAddWatchlistSheet,
                      icon: const Icon(Icons.star_border, size: 16, color: AppColors.gold),
                      label: const Text("Watch Card", style: TextStyle(color: AppColors.gold, fontSize: 13)),
                    ),
                  ],
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text("Your watchlist is empty.", style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final diff = item.currentEst - item.targetBuy;
                            final pct = item.targetBuy > 0 ? (diff / item.targetBuy) * 100 : 0.0;
                            final atTarget = diff <= 0;

                            return GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "${item.year} ${item.player}",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                            if (atTarget) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.gainGreen.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text("BUY ZONE", style: TextStyle(fontSize: 9, color: AppColors.gainGreen, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${item.set} · ${item.grade} · ${item.sport}",
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Target: ${_formatCurrency(item.targetBuy)}",
                                          style: const TextStyle(color: AppColors.gold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(_formatCurrency(item.currentEst), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          Text(
                                            "${diff > 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs target",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: diff <= 0 ? AppColors.gainGreen : AppColors.lossRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .doc('users/${widget.uid}/watchlists/${item.id}')
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
