import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/models/card_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/card_thumbnail.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/gemini_service.dart';

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
  String? _selectedCatalogId;
  String? _selectedImageUrl;

  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? "-" : "";
    if (absAmount == 0.0) return "\$0";
    if (absAmount < 10.0) {
      return "$sign\$${absAmount.toStringAsFixed(2)}";
    }
    return "$sign\$${absAmount.round().toString()}";
  }

  String _detectSport(String name, String releaseName, String setName) {
    final text = "$name $releaseName $setName".toLowerCase();
    
    // Specific players mapping first
    if (RegExp(r'\bohtani\b|\bjudge\b|\btrout\b|\bacuna\b|\bsoto\b|\bharper\b|\bbetts\b|\bguerrero\b|\bpujols\b|\bripken\b|\bpiazza\b|\bortiz\b|\bmcgwire\b|\brodriguez\b|\bbaseball\b|\bmlb\b').hasMatch(text)) {
      return "Baseball";
    }
    if (RegExp(r'\bwembanyama\b|\blebron\b|\bcurry\b|\bjordan\b|\bdoncic\b|\bclark\b|\btatum\b|\bkobe\b|\bshaq\b|\bbasketball\b|\bnba\b').hasMatch(text)) {
      return "Basketball";
    }
    if (RegExp(r'\bmahomes\b|\bbrady\b|\bdart\b|\bburrow\b|\bjackson\b|\bstroud\b|\bpurdy\b|\ballen\b|\bhurts\b|\bcarter\b|\bskattebo\b|\bward\b|\bsanders\b|\bshough\b|\bmanning\b|\btarkenton\b|\bfootball\b|\bnfl\b').hasMatch(text)) {
      return "Football";
    }
    if (RegExp(r'\bmcdavid\b|\bcrosby\b|\bbedard\b|\bovechkin\b|\bgretzky\b|\bhockey\b|\bnhl\b').hasMatch(text)) {
      return "Hockey";
    }
    if (RegExp(r'\bmessi\b|\bronaldo\b|\bmbappe\b|\bhaaland\b|\bsoccer\b|\bfutbol\b|\bpremier league\b|\bchampions league\b|\bla liga\b').hasMatch(text)) {
      return "Soccer";
    }

    // Broad keyword matching
    if (text.contains("bowman") || text.contains("topps chrome") || text.contains("heritage") || text.contains("stadium club") || text.contains("allen & ginter")) {
      return "Baseball";
    }
    if (text.contains("hoops") || text.contains("prizm basketball") || text.contains("court kings") || text.contains("nba hoops")) {
      return "Basketball";
    }
    if (text.contains("prizm football") || text.contains("donruss") || text.contains("score") || text.contains("gridiron")) {
      return "Football";
    }
    if (text.contains("young guns") || text.contains("upper deck") || text.contains("o-pee-chee")) {
      return "Hockey";
    }
    
    return "Basketball"; // Default fallback
  }

  Future<void> _runCatalogSearch(StateSetter setModalState) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setModalState(() {
      _searchingCatalog = true;
      _searchResults = [];
    });

    final cardSightKey = AppConstants.cardSightApiKey;
    if (cardSightKey != "YOUR_CARDSIGHT_API_KEY" && cardSightKey.isNotEmpty) {
      try {
        final uri = Uri.parse("https://api.cardsight.ai/v1/catalog/search?q=${Uri.encodeComponent(query)}&type=card&take=10");
        final res = await http.get(
          uri,
          headers: {
            "X-API-Key": cardSightKey,
            "Content-Type": "application/json",
          },
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data != null) {
            final list = data['results'] ?? data['data'];
            if (list != null && list is List) {
              final topItems = list.take(10).toList();
              final cardIds = topItems.map((item) => item['id']).where((id) => id != null).toList();

              final Map<String, double> pricingMap = {};
              try {
                final pricingBulkUri = Uri.parse("https://api.cardsight.ai/v1/pricing/");
                final bulkRes = await http.post(
                  pricingBulkUri,
                  headers: {
                    "X-API-Key": cardSightKey,
                    "Content-Type": "application/json",
                  },
                  body: jsonEncode({
                    "card_ids": cardIds,
                    "period": "all",
                    "listing_type": "both"
                  }),
                ).timeout(const Duration(seconds: 8));

                if (bulkRes.statusCode == 200) {
                  final bulkData = jsonDecode(bulkRes.body);
                  if (bulkData != null && bulkData['results'] is List) {
                    for (var r in bulkData['results']) {
                      if (r['success'] == true && r['data'] != null) {
                        final pricingData = r['data'];
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
                        pricingMap[r['card_id']] = avgPrice;
                      }
                    }
                  }
                }
              } catch (e) {
                debugPrint("Failed to fetch bulk pricing: $e");
              }

              final parsed = topItems.map((item) {
                final cardId = item['id'];
                final price = pricingMap[cardId] ?? 0.0;
                final releaseName = item['releaseName'] ?? '';
                final setName = item['setName'] ?? item['set'] ?? '';
                final parallelName = item['parallelName'] ?? '';
                final name = item['name'] ?? item['player'] ?? '';
                final detected = _detectSport(name, releaseName, setName);

                String setDesc = "$releaseName $setName";
                if (parallelName.isNotEmpty) {
                  setDesc += " ($parallelName)";
                }
                setDesc = setDesc.trim();

                return {
                  'id': cardId,
                  'player': name,
                  'year': int.tryParse(item['year']?.toString() ?? '') ?? DateTime.now().year,
                  'set': setDesc.isNotEmpty ? setDesc : setName,
                  'sport': detected,
                  'estimatedPrice': price,
                };
              }).toList();

              final RegExp yearRegex = RegExp(r'\b\d{4}\b');
              final Match? yearMatch = yearRegex.firstMatch(query);
              final int? searchYear = yearMatch != null ? int.tryParse(yearMatch.group(0) ?? '') : null;
              final bool isRookieQuery = query.toLowerCase().contains(RegExp(r'\b(rc|rookie|rookies)\b'));

              parsed.sort((a, b) {
                // Rule 1: Prioritize explicit year match
                if (searchYear != null) {
                  final int aYear = a['year'] as int? ?? 0;
                  final int bYear = b['year'] as int? ?? 0;
                  final bool aMatches = aYear == searchYear;
                  final bool bMatches = bYear == searchYear;
                  if (aMatches && !bMatches) return -1;
                  if (!aMatches && bMatches) return 1;
                }

                // Rule 2: Prioritize older cards if asking for a rookie card
                if (isRookieQuery) {
                  final int aYear = a['year'] as int? ?? 9999;
                  final int bYear = b['year'] as int? ?? 9999;
                  if (aYear != bYear) {
                    return aYear.compareTo(bYear);
                  }
                }

                // Rule 3: Prioritize cards with known pricing comps (non-zero value)
                final double aPrice = a['estimatedPrice'] as double? ?? 0.0;
                final double bPrice = b['estimatedPrice'] as double? ?? 0.0;
                final bool aHasPrice = aPrice > 0.0;
                final bool bHasPrice = bPrice > 0.0;
                if (aHasPrice && !bHasPrice) return -1;
                if (!aHasPrice && bHasPrice) return 1;

                // Rule 4: Sort by price descending
                return bPrice.compareTo(aPrice);
              });

              setModalState(() {
                _searchResults = parsed;
                _searchingCatalog = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint("CardSight catalog search failed: $e. Falling back to simulation.");
      }
    }

    // Fallback: Gemini simulation
    try {
      final reply = await GeminiService.callGemini(
        systemInstruction: "You are a sports card database API. Return a valid JSON array of objects representing the top 5 closest matching real sports cards matching the user query. Each object must have properties: 'player', 'year' (number), 'set' (product line/brand name), 'sport' (one of: Basketball, Baseball, Football, Hockey, Soccer), and 'estimatedPrice' (number). Return ONLY the raw JSON block without markdown formatting or code blocks. Do not wrap in ```json or any other formatting.",
        contents: [{
          "role": "user",
          "parts": [{"text": "Search query: $query"}]
        }],
        temperature: 0.2,
      );

      String cleanedResult = reply.trim();
      if (cleanedResult.contains("```")) {
        if (cleanedResult.startsWith("```json")) {
          cleanedResult = cleanedResult.substring(7);
        } else if (cleanedResult.startsWith("```")) {
          cleanedResult = cleanedResult.substring(3);
        }
        if (cleanedResult.endsWith("```")) {
          cleanedResult = cleanedResult.substring(0, cleanedResult.length - 3);
        }
        cleanedResult = cleanedResult.trim();
      }
      
      final parsed = jsonDecode(cleanedResult) as List<dynamic>;
      setModalState(() {
        _searchResults = parsed;
      });
    } catch (e) {
      debugPrint("Catalog search fallback failed: $e");
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

    final cardSightKey = AppConstants.cardSightApiKey;
    if (cardSightKey != "YOUR_CARDSIGHT_API_KEY" && cardSightKey.isNotEmpty) {
      try {
        final searchUri = Uri.parse("https://api.cardsight.ai/v1/catalog/search?q=${Uri.encodeComponent("${_yearController.text} $player ${_setController.text}")}");
        final searchRes = await http.get(
          searchUri,
          headers: {
            "X-API-Key": cardSightKey,
            "Content-Type": "application/json",
          },
        ).timeout(const Duration(seconds: 10));

        if (searchRes.statusCode == 200) {
          final searchData = jsonDecode(searchRes.body);
          if (searchData != null) {
            final searchResults = searchData['results'] ?? searchData['data'];
            if (searchResults != null && searchResults is List && searchResults.isNotEmpty) {
              final cardId = searchResults[0]['id'];
              final pricingUri = Uri.parse("https://api.cardsight.ai/v1/pricing/$cardId");
              final pricingRes = await http.get(
                pricingUri,
                headers: {
                  "X-API-Key": cardSightKey,
                  "Content-Type": "application/json",
                },
              ).timeout(const Duration(seconds: 10));

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
                      final priceVal = s['price'] ?? s['price_usd'] ?? s['value'];
                      if (priceVal != null) {
                        final parsedVal = double.tryParse(priceVal.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                        if (parsedVal > 0) {
                          total += parsedVal;
                          count++;
                        }
                      }
                    }
                    if (count > 0) avgPrice = total / count;
                  }
                  if (avgPrice > 0) {
                    setState(() {
                      _valueController.text = avgPrice.toStringAsFixed(0);
                      _autoPricing = false;
                    });
                    return;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("CardSight auto pricing failed: $e. Falling back to simulation.");
      }
    }

    // Fallback: Gemini simulation
    try {
      final reply = await GeminiService.callGemini(
        systemInstruction: "You are a sports card valuation tool. Reply with ONLY a single raw number representing the estimated market value of the card requested. No dollar signs, no units, no text (e.g. 450).",
        contents: [{
          "role": "user",
          "parts": [{"text": "Estimated market value of sports card: ${_yearController.text} $player ${_setController.text} ${_gradeController.text}"}]
        }],
        temperature: 0.2,
      );

      final double price = double.tryParse(reply.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      _valueController.text = price.toStringAsFixed(2);
    } catch (e) {
      debugPrint("Auto pricing fallback failed: $e");
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
                        constraints: const BoxConstraints(maxHeight: 150),
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
                               trailing: Text(_formatCurrency((item['estimatedPrice'] as num).toDouble()), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                              onTap: () {
                                setModalState(() {
                                  _playerController.text = item['player'];
                                  _yearController.text = item['year'].toString();
                                  _setController.text = item['set'];
                                  final estVal = (item['estimatedPrice'] as num).toDouble();
                                  _valueController.text = estVal > 0 ? estVal.toStringAsFixed(0) : "";
                                  _purchaseController.text = estVal > 0 ? estVal.toStringAsFixed(0) : "";
                                  _selectedSport = item['sport'];
                                  _gradeController.text = "Raw";
                                  _selectedCatalogId = item['id'];
                                  _selectedImageUrl = item['imageUrl'];
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
                                  'catalogId': _selectedCatalogId,
                                  'imageUrl': _selectedImageUrl,
                                });
                                _playerController.clear();
                                _yearController.clear();
                                _setController.clear();
                                _gradeController.clear();
                                _purchaseController.clear();
                                _valueController.clear();
                                _quantityController.text = "1";
                                _selectedCatalogId = null;
                                _selectedImageUrl = null;
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
                            Text(_formatCurrency(totalValue), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text("${cards.length} cards", style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
                            Text(_formatCurrency(totalCost), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text("cost basis", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
                              "${totalReturn >= 0 ? '+' : ''}${_formatCurrency(totalReturn)}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: totalReturn >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${totalReturn >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 10,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  child: RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.cardBg,
                    onRefresh: () async {
                      NotificationService.clearNotifiedSession();
                      await Future.delayed(const Duration(seconds: 1));
                      NotificationService.evaluatePortfolioAndNotify(cards);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Portfolio refreshed. Peak-sell checks re-evaluated!"),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.cardBg,
                          ),
                        );
                      }
                    },
                    child: cards.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text("Your portfolio is empty.", style: TextStyle(color: AppColors.textMuted)),
                              ),
                            ],
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CardThumbnail(
                                            imageUrl: card.imageUrl,
                                            catalogId: card.catalogId,
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
                                                    Expanded(
                                                      child: Text(
                                                        "${qty}x ${card.year} ${card.player}",
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (pct >= 30.0) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.lossRed.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: AppColors.lossRed.withOpacity(0.3)),
                                                        ),
                                                        child: const Text(
                                                          "SELL PEAK",
                                                          style: TextStyle(
                                                            color: AppColors.lossRed,
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  "${card.set} · ${card.grade} · ${card.sport}",
                                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                                            Text(_formatCurrency(val), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                            Text(
                                              "${gain >= 0 ? '+' : ''}${_formatCurrency(gain)} (${pct.toStringAsFixed(1)}%)",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: gain >= 0 ? AppColors.gainGreen : AppColors.lossRed,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        if (pct >= 30.0) ...[
                                          IconButton(
                                            icon: const Icon(Icons.notifications_active, color: AppColors.gold, size: 18),
                                            tooltip: "Simulate peak sell alert",
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("Triggering alert in 4 seconds. Go to your home screen now to test!"),
                                                  duration: Duration(seconds: 3),
                                                  backgroundColor: AppColors.cardBg,
                                                ),
                                              );
                                              NotificationService.simulatePeakSellAlert(card, delaySeconds: 4);
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
