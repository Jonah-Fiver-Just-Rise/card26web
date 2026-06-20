import 'package:flutter/material';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final _quantityController = TextEditingController(text: "1");
  final _searchController = TextEditingController();
  
  String _selectedSport = "Basketball";
  bool _autoPricing = false;
  bool _searchingCatalog = false;
  List<dynamic> _searchResults = [];

  Future<void> _runCatalogSearch(StateSetter setModalState) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setModalState(() {
      _searchingCatalog = true;
      _searchResults = [];
    });

    try {
      const apiKey = "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";
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": "You are a sports card database API. Return a valid JSON array of objects representing the top 5 closest matching real sports cards matching the user query. Each object must have properties: 'player', 'year' (number), 'set' (product line/brand name), 'sport' (one of: Basketball, Baseball, Football, Hockey, Soccer), and 'estimatedPrice' (number). Return ONLY the raw JSON block without markdown formatting or code blocks."
            },
            {
              "role": "user",
              "content": "Search query: $query"
            }
          ]
        }),
      );
      final data = jsonDecode(res.body);
      final reply = data['choices'][0]['message']['content'] ?? "";
      final cleanedResult = reply.substring(reply.indexOf("["), reply.lastIndexOf("]") + 1);
      final parsed = jsonDecode(cleanedResult) as List<dynamic>;
      setModalState(() {
        _searchResults = parsed;
      });
    } catch (e) {
      debugPrint("Catalog search failed: $e");
    } finally {
      setModalState(() {
        _searchingCatalog = false;
      });
    }
  }

  Future<void> _runAutoPricing() async {
    final player = _playerController.text.trim();
    if (player.isEmpty) return;
    setState(() => _autoPricing = true);

    try {
      const apiKey = "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";
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": "You are a sports card valuation tool. Reply with ONLY a single raw number representing the estimated market value of the card requested. No dollar signs, no units, no text (e.g. 450)."
            },
            {
              "role": "user",
              "content": "Estimated market value of sports card: ${_yearController.text} $player ${_setController.text} ${_gradeController.text}"
            }
          ]
        }),
      );
      final data = jsonDecode(res.body);
      final reply = data['choices'][0]['message']['content'] ?? "";
      final double price = double.tryParse(reply.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      _valueController.text = price.toStringAsFixed(0);
    } catch (e) {
      debugPrint("Auto pricing failed: $e");
    } finally {
      setState(() => _autoPricing = false);
    }
  }

  void _showAddCardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    // Quick Search Bar
                    const Text("SEARCH CARD CATALOG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(hintText: "e.g. 2003 LeBron James Topps"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _searchingCatalog ? null : () => _runCatalogSearch(setModalState),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
                            child: _searchingCatalog
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2))
                                : const Text("Search"),
                          ),
                        ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        maxHeight: 150,
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          border: Border.all(color: AppColors.borderInput),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, idx) {
                            final item = _searchResults[idx];
                            return ListTile(
                              title: Text("${item['year']} ${item['player']} (${item['set']})"),
                              subtitle: Text(item['sport']),
                              trailing: Text("\$${item['estimatedPrice']}", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                              onTap: () {
                                setModalState(() {
                                  _playerController.text = item['player'];
                                  _yearController.text = item['year'].toString();
                                  _setController.text = item['set'];
                                  _valueController.text = item['estimatedPrice'].toString();
                                  _purchaseController.text = item['estimatedPrice'].toString();
                                  _selectedSport = item['sport'];
                                  _gradeController.text = "Raw";
                                  _searchResults = [];
                                  _searchController.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.borderDark),
                    const SizedBox(height: 10),
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
                              if (v != null) setModalState(() => _selectedSport = v);
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
                    const SizedBox(height: 10),
                    TextField(controller: _quantityController, decoration: const InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
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
                                  'quantity': int.tryParse(_quantityController.text) ?? 1,
                                  'addedAt': DateTime.now().toIso8601String(),
                                });
                                _playerController.clear();
                                _yearController.clear();
                                _setController.clear();
                                _gradeController.clear();
                                _purchaseController.clear();
                                _valueController.clear();
                                _quantityController.text = "1";
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.bg,
                              ),
                              child: const Text("Save Card", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _autoPricing ? null : () async {
                                await _runAutoPricing();
                                setModalState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.borderInput),
                              ),
                              child: _autoPricing
                                  ? const CircularProgressIndicator(color: AppColors.gold)
                                  : const Text("AI Auto-Price", style: TextStyle(color: AppColors.gold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
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

        double totalCost = cards.fold(0.0, (sum, item) => sum + (item.purchasePrice * item.quantity));
        double totalValue = cards.fold(0.0, (sum, item) => sum + (item.currentValue * item.quantity));
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
                            final qty = card.quantity;
                            final cost = card.purchasePrice * qty;
                            final val = card.currentValue * qty;
                            final gain = val - cost;
                            final pct = cost > 0 ? (gain / cost) * 100 : 0.0;
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
                                          "${qty}x ${card.year} ${card.player}",
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
                                          Text("\$${val.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.extrabold, fontSize: 15)),
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
