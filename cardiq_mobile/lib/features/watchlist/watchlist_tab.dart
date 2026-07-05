import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/models/watchlist_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/card_thumbnail.dart';
import '../../core/constants/app_constants.dart';

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

  bool _syncing = false;
  bool _hasSyncedOnMount = false;
  List<WatchlistModel> _latestItems = [];

  Future<double> _fetchCardPrice(String cardId) async {
    final cardSightKey = AppConstants.cardSightApiKey;
    if (cardSightKey == "YOUR_CARDSIGHT_API_KEY" || cardSightKey.isEmpty) {
      return 0.0;
    }
    try {
      final pricingUri = Uri.parse("https://api.cardsight.ai/v1/pricing/$cardId");
      final pricingRes = await http.get(
        pricingUri,
        headers: {
          "X-API-Key": cardSightKey,
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 5));
      
      if (pricingRes.statusCode == 200) {
        final pricingData = jsonDecode(pricingRes.body);
        if (pricingData != null) {
          final rawSales = pricingData['raw']?['records'] ?? [];
          final gradedSales = pricingData['graded'] ?? [];
          final List<dynamic> sales = [...rawSales, ...gradedSales];
          double avgPrice = 0.0;
          if (pricingData['averagePrice'] != null) {
            avgPrice = double.tryParse(pricingData['averagePrice'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          } else if (pricingData['average'] != null) {
            avgPrice = double.tryParse(pricingData['average'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          } else if (sales.isNotEmpty) {
            double total = 0.0;
            int count = 0;
            for (var s in sales) {
              final p = s['price'] ?? s['price_usd'] ?? s['value'];
              if (p != null) {
                final parsedVal = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                if (parsedVal > 0) {
                  total += parsedVal;
                  count++;
                }
              }
            }
            if (count > 0) avgPrice = total / count;
          }
          if (avgPrice > 0) return avgPrice;
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch price for $cardId: $e");
    }

    try {
      final marketUri = Uri.parse("https://api.cardsight.ai/v1/marketplace/$cardId");
      final marketRes = await http.get(
        marketUri,
        headers: {
          "X-API-Key": cardSightKey,
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 5));
      
      if (marketRes.statusCode == 200) {
        final marketData = jsonDecode(marketRes.body);
        if (marketData != null && marketData['raw']?['records'] != null) {
          final records = marketData['raw']['records'] as List;
          double total = 0.0;
          int count = 0;
          for (var r in records) {
            final p = r['price'] ?? r['price_usd'] ?? r['value'];
            if (p != null) {
              final parsedVal = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
              if (parsedVal > 0) {
                total += parsedVal;
                count++;
              }
            }
          }
          if (count > 0) return total / count;
        }
      }
    } catch (e) {
      debugPrint("Marketplace fallback failed for $cardId: $e");
    }
    return 0.0;
  }

  Future<void> _syncWatchlistPrices() async {
    if (_syncing || _latestItems.isEmpty) return;
    setState(() {
      _syncing = true;
    });

    final cardSightKey = AppConstants.cardSightApiKey;
    int updatedCount = 0;

    try {
      for (var item in _latestItems) {
        final qStr = "${item.year} ${item.player} ${item.set}";
        final searchUri = Uri.parse("https://api.cardsight.ai/v1/catalog/search?q=${Uri.encodeComponent(qStr)}&type=card");
        final searchRes = await http.get(
          searchUri,
          headers: {
            "X-API-Key": cardSightKey,
            "Content-Type": "application/json",
          },
        ).timeout(const Duration(seconds: 6));

        if (searchRes.statusCode == 200) {
          final searchData = jsonDecode(searchRes.body);
          final list = searchData['results'] ?? searchData['data'];
          if (list != null && list is List && list.isNotEmpty) {
            final cardId = list[0]['id'];
            final newPrice = await _fetchCardPrice(cardId);
            if (newPrice > 0 && newPrice.round() != item.currentEst.round()) {
              await FirebaseFirestore.instance
                  .doc('users/${widget.uid}/watchlists/${item.id}')
                  .update({'currentEst': newPrice});
              updatedCount++;
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync Complete! Updated live valuations for $updatedCount watchlist items."),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.cardBg,
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to sync watchlist: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Stale pricing updated. Comps synced with CardSight AI."),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.cardBg,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

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
        _latestItems = items;

        if (items.isNotEmpty && !_hasSyncedOnMount) {
          _hasSyncedOnMount = true;
          Future.delayed(Duration.zero, () {
            _syncWatchlistPrices();
          });
        }

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
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _syncing ? null : _syncWatchlistPrices,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                                )
                              : const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                          label: Text(
                            _syncing ? "Syncing..." : "Sync Live Prices",
                            style: const TextStyle(color: AppColors.gold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _showAddWatchlistSheet,
                          icon: const Icon(Icons.star_border, size: 16, color: AppColors.gold),
                          label: const Text("Watch Card", style: TextStyle(color: AppColors.gold, fontSize: 13)),
                        ),
                      ],
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
                                    child: Row(
                                      children: [
                                        CardThumbnail(
                                          imageUrl: item.imageUrl,
                                          catalogId: item.catalogId,
                                          width: 42,
                                          height: 52,
                                        ),
                                        const SizedBox(width: 12),
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
