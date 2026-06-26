import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/glass_card.dart';

class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  final _queryController = TextEditingController();
  String _analysisResult = "";
  bool _loading = false;
  List<dynamic> _searchResults = [];
  bool _searchingCatalog = false;
  String _searchError = "";
  dynamic _selectedCard;

  final List<Map<String, dynamic>> _trendingMovements = [
    { "name": "Wembanyama RC 2023", "query": "2023 Victor Wembanyama Prizm RC", "price": 625.00, "change": 14.2, "trend": "up" },
    { "name": "Shohei Ohtani Chrome Auto", "query": "2018 Shohei Ohtani Bowman Chrome Auto", "price": 1420.00, "change": 8.5, "trend": "up" },
    { "name": "Patrick Mahomes Prizm", "query": "2017 Patrick Mahomes Prizm RC", "price": 2850.00, "change": -2.4, "trend": "down" },
    { "name": "Caitlin Clark RC", "query": "2024 Caitlin Clark Topps Chrome RC", "price": 310.00, "change": 22.1, "trend": "up" },
    { "name": "Luka Dončić Prizm PSA 10", "query": "2018 Luka Dončić Prizm PSA 10", "price": 780.00, "change": 5.8, "trend": "up" },
    { "name": "Connor McDavid Young Guns", "query": "2015 Connor McDavid Upper Deck Young Guns", "price": 1250.00, "change": -1.8, "trend": "down" }
  ];

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
    return "Basketball";
  }

  Future<void> _runMarketSearch(String queryStr) async {
    final q = queryStr.trim();
    if (q.isEmpty || _searchingCatalog) return;

    setState(() {
      _searchingCatalog = true;
      _searchResults = [];
      _searchError = "";
      _analysisResult = "";
      _selectedCard = null;
    });

    try {
      final cardSightKey = AppConstants.cardSightApiKey;
      if (cardSightKey.isEmpty || cardSightKey == "YOUR_CARDSIGHT_API_KEY") {
        throw Exception("CardSight AI API key is not configured.");
      }

      final searchUri = Uri.parse("https://api.cardsight.ai/v1/catalog/search?q=${Uri.encodeComponent(q)}");
      final searchRes = await http.get(
        searchUri,
        headers: {
          "X-API-Key": cardSightKey,
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      if (searchRes.statusCode == 200) {
        final searchData = jsonDecode(searchRes.body);
        final list = searchData['results'] ?? searchData['data'];
        if (list != null && list is List && list.isNotEmpty) {
          setState(() {
            _searchResults = list.take(8).toList();
          });
        } else {
          setState(() {
            _searchError = "No matching cards found. Try a different query.";
          });
        }
      } else {
        setState(() {
          _searchError = "Search failed (HTTP ${searchRes.statusCode}).";
        });
      }
    } catch (e) {
      setState(() {
        _searchError = "Search failed: $e";
      });
    } finally {
      setState(() {
        _searchingCatalog = false;
      });
    }
  }

  Future<void> _runMarketAnalysisForCard(dynamic card) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _analysisResult = "";
      _selectedCard = card;
    });

    try {
      final apiKey = AppConstants.geminiApiKey;
      if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
        throw Exception("Gemini API key is not configured.");
      }

      final cardSightKey = AppConstants.cardSightApiKey;
      String apiContext = "";
      final cardId = card['id'];

      if (cardSightKey.isNotEmpty && cardSightKey != "YOUR_CARDSIGHT_API_KEY") {
        List<dynamic> allComps = [];
        try {
          final pricingUri = Uri.parse("https://api.cardsight.ai/v1/pricing/$cardId");
          final pricingRes = await http.get(
            pricingUri,
            headers: {
              "X-API-Key": cardSightKey,
              "Content-Type": "application/json",
            },
          ).timeout(const Duration(seconds: 6));

          if (pricingRes.statusCode == 200) {
            final pricingData = jsonDecode(pricingRes.body);
            if (pricingData != null) {
              final rawSales = pricingData['raw']?['records'] ?? [];
              final gradedSales = pricingData['graded'] ?? [];
              allComps = [...rawSales, ...gradedSales];
            }
          }
        } catch (e) {
          debugPrint("Pricing fetch failed for market analysis: $e");
        }

        List<dynamic> activeListings = [];
        try {
          final marketUri = Uri.parse("https://api.cardsight.ai/v1/marketplace/$cardId");
          final marketRes = await http.get(
            marketUri,
            headers: {
              "X-API-Key": cardSightKey,
              "Content-Type": "application/json",
            },
          ).timeout(const Duration(seconds: 6));

          if (marketRes.statusCode == 200) {
            final marketData = jsonDecode(marketRes.body);
            if (marketData != null && marketData['raw']?['records'] != null) {
              activeListings = marketData['raw']['records'] as List;
            }
          }
        } catch (e) {
          debugPrint("Marketplace fetch failed for market analysis: $e");
        }

        final compsBuffer = StringBuffer();
        for (var s in allComps.take(10)) {
          final p = s['price'] ?? s['price_usd'] ?? s['value'];
          if (p != null) {
            final priceVal = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final date = s['date'] ?? s['sold_date'] ?? 'Recent';
            final grade = s['grade'] ?? 'Raw';
            final source = s['source'] ?? 'eBay';
            compsBuffer.writeln("- Date: $date, Price: ${_formatCurrency(priceVal)}, Grade: $grade, Source: $source");
          }
        }

        final activeBuffer = StringBuffer();
        for (var a in activeListings.take(5)) {
          final p = a['price'] ?? a['price_usd'] ?? a['value'];
          if (p != null) {
            final priceVal = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final title = a['title'] ?? card['name'] ?? 'Sports Card';
            activeBuffer.writeln("- Active Listing: $title, Price: ${_formatCurrency(priceVal)}");
          }
        }

        final detectedSport = _detectSport(
          card['name'] ?? '',
          card['releaseName'] ?? '',
          card['setName'] ?? '',
        );

        apiContext = """
Card Details from Catalog API:
- Name: ${card['name'] ?? card['player'] ?? ''}
- Year: ${card['year'] ?? ''}
- Set/Product: ${card['releaseName'] ?? ''} ${card['setName'] ?? ''}
- Parallel/Variation: ${card['parallelName'] ?? 'Base'}
- Sport: $detectedSport

Real-Time Market Comps:
${compsBuffer.isNotEmpty ? compsBuffer.toString() : "No completed sales records found."}

Active Listings:
${activeBuffer.isNotEmpty ? activeBuffer.toString() : "No active listings found."}
""";
      } else {
        apiContext = "CardSight AI API key is not configured. Falling back to Gemini knowledge base.";
      }

      final systemPrompt = """You are an expert sports card market analyst and financial advisor.
You MUST analyze the card using the real-time CardSight AI API data provided below.
In addition to the API data, you must integrate recent player news, performance trends (injuries, hot streaks, trades, college stats vs pro projection), and overall market trends for the sport and set.
To prevent hallucinating card values, you must strictly align your advice with the actual pricing comps and active listings provided in the Live API Data. Do not invent or assume sales prices or active listings that contradict the provided data. If the data is empty or indicates the card does not exist yet, base your advice on draft expectations, comparable player trends, and state this clearly.

You MUST format your output using EXACTLY the following five bold headings (no variations, no extra headings, no missing headings):
**1. Current Price Ranges & Grade Premium Spreads**
[Analysis of price ranges, raw vs graded spread, and comps here]

**2. Trend Direction**
[Analysis of recent transaction dates and price movement directions here]

**3. Player News & Latest Performance Context**
[Analysis of recent player performance, injuries, stats, projection, and news here]

**4. Key Value Drivers**
[Analysis of set popularity, rookie card status, print runs, and scarcity here]

**5. Recommendation & Justification**
[Clear BUY / HOLD / SELL recommendation with reasoning based on the above sections here]

Keep the analysis professional, specific with numbers, and under 250 words.""";

      final models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"];
      String? reply;
      dynamic lastError;

      for (final model in models) {
        try {
          final res = await http.post(
            Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent"),
            headers: {
              "Content-Type": "application/json",
              "X-goog-api-key": apiKey,
            },
            body: jsonEncode({
              "systemInstruction": {
                "parts": [{ "text": systemPrompt }]
              },
              "contents": [{
                "role": "user",
                "parts": [{ "text": "Analyze the sports card market for: \"${card['year']} ${card['name']} ${card['releaseName']} ${card['parallelName']}\"\n\nLive API Data:\n$apiContext" }]
              }],
              "generationConfig": {
                "maxOutputTokens": 2048,
                "temperature": 0.7
              }
            }),
          ).timeout(const Duration(seconds: 25));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              if (content != null) {
                final parts = content['parts'] as List?;
                if (parts != null && parts.isNotEmpty) {
                  reply = parts[0]['text'] as String?;
                  if (reply != null && reply.trim().isNotEmpty) {
                    break;
                  }
                }
              }
            }
          } else {
            lastError = "HTTP ${res.statusCode}: ${res.body}";
          }
        } catch (e) {
          lastError = e;
        }
      }

      if (reply == null) {
        throw Exception(lastError ?? "Empty response from Gemini.");
      }

      setState(() {
        _analysisResult = reply!;
      });
    } catch (e) {
      setState(() {
        _analysisResult = "⚠️ Failed to fetch market analysis: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "MARKET INTELLIGENCE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Enter any player, card, or set to search the database and run a buy/hold/sell analysis.",
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: "e.g. 2018 Luka Dončić Prizm PSA 10",
                    ),
                    onSubmitted: (val) {
                      _runMarketSearch(val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _searchingCatalog ? null : () => _runMarketSearch(_queryController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    child: _searchingCatalog
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2),
                          )
                        : const Text("Search", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_searchError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lossRed.withOpacity(0.1),
                  border: Border.all(color: AppColors.lossRed.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _searchError,
                  style: const TextStyle(color: AppColors.lossRed, fontSize: 13),
                ),
              ),
            ],
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "MATCHING CARDS (SELECT ONE TO ANALYZE)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final card = _searchResults[index];
                  final parallel = card['parallelName'] ?? '';
                  final setDesc = "${card['releaseName'] ?? ''} ${card['setName'] ?? ''} ${parallel.isNotEmpty ? '($parallel)' : ''}".trim();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        "${card['year']} ${card['name'] ?? card['player'] ?? ''}",
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(setDesc, style: const TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                _runMarketAnalysisForCard(card);
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          _loading && _selectedCard?['id'] == card['id']
                              ? "Analyzing..."
                              : "Analyze",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              "🔥 DYNAMIC TRENDING MOVEMENTS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: _trendingMovements.length,
              itemBuilder: (context, index) {
                final item = _trendingMovements[index];
                final isUp = item['trend'] == "up";
                return InkWell(
                  onTap: () {
                    _queryController.text = item['query'];
                    _runMarketSearch(item['query']);
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: Border.all(
                      color: isUp ? AppColors.gainGreen.withOpacity(0.2) : AppColors.lossRed.withOpacity(0.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "\$${item['price'].toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUp ? AppColors.gainGreen.withOpacity(0.1) : AppColors.lossRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${isUp ? '+' : ''}${item['change']}%",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isUp ? AppColors.gainGreen : AppColors.lossRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_analysisResult.isNotEmpty || _loading) ...[
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderDark),
              const SizedBox(height: 12),
              Text(
                _selectedCard != null
                    ? "ANALYSIS RESULT: ${_selectedCard['year']} ${_selectedCard['name'] ?? _selectedCard['player'] ?? ''} (${_selectedCard['parallelName'] ?? 'Base'})"
                    : "ANALYSIS RESULT",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: _loading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(color: AppColors.gold),
                          ),
                        )
                      : Text(
                          _analysisResult,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
