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

  final List<Map<String, dynamic>> _trendingMovements = [
    { "name": "Wembanyama RC 2023", "query": "2023 Victor Wembanyama Prizm RC", "price": 625.00, "change": 14.2, "trend": "up" },
    { "name": "Shohei Ohtani Chrome Auto", "query": "2018 Shohei Ohtani Bowman Chrome Auto", "price": 1420.00, "change": 8.5, "trend": "up" },
    { "name": "Patrick Mahomes Prizm", "query": "2017 Patrick Mahomes Prizm RC", "price": 2850.00, "change": -2.4, "trend": "down" },
    { "name": "Caitlin Clark RC", "query": "2024 Caitlin Clark Topps Chrome RC", "price": 310.00, "change": 22.1, "trend": "up" },
    { "name": "Luka Dončić Prizm PSA 10", "query": "2018 Luka Dončić Prizm PSA 10", "price": 780.00, "change": 5.8, "trend": "up" },
    { "name": "Connor McDavid Young Guns", "query": "2015 Connor McDavid Upper Deck Young Guns", "price": 1250.00, "change": -1.8, "trend": "down" }
  ];

  Future<void> _runMarketAnalysis(String queryToAnalyze) async {
    final q = queryToAnalyze.trim();
    if (q.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _analysisResult = "";
    });

    try {
      final apiKey = AppConstants.geminiApiKey;
      if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
        throw Exception("Gemini API key is not configured.");
      }

      final systemPrompt = "You are a sports card market analyst. Give detailed analysis: current price ranges, trend direction, key value drivers, PSA 9 vs 10 grade premium spread, and a clear BUY / HOLD / SELL recommendation with reasoning. Be specific with numbers. Under 250 words.";

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
                "parts": [{ "text": "Analyze the sports card market for: $q" }]
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
              "Enter any player, card, or set for a buy/hold/sell analysis.",
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
                      _runMarketAnalysis(val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _runMarketAnalysis(_queryController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2),
                          )
                        : const Text("Analyze", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
                childAspectRatio: 1.6,
              ),
              itemCount: _trendingMovements.length,
              itemBuilder: (context, index) {
                final item = _trendingMovements[index];
                final isUp = item['trend'] == "up";
                return InkWell(
                  onTap: () {
                    _queryController.text = item['query'];
                    _runMarketAnalysis(item['query']);
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
              const Text(
                "ANALYSIS RESULT",
                style: TextStyle(
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
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
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
