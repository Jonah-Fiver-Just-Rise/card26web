import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/gemini_service.dart';

class AdvisorTab extends StatefulWidget {
  final String uid;
  const AdvisorTab({super.key, required this.uid});

  @override
  State<AdvisorTab> createState() => _AdvisorTabState();
}

class _AdvisorTabState extends State<AdvisorTab> {
  final _messageController = TextEditingController();
  List<Map<String, String>> _messages = [
    {
      "role": "assistant",
      "content": "Hey! I'm your Kartis financial advisor. Ask me anything about valuations, buy/sell signals, grading strategy, or market trends."
    }
  ];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // Load chat history from Firestore
  void _loadChatHistory() {
    FirebaseFirestore.instance
        .doc('users/${widget.uid}/chats/history')
        .snapshots()
        .listen((docSnap) {
      if (docSnap.exists && docSnap.data()?['messages'] != null) {
        final List<dynamic> loadedRaw = docSnap.data()?['messages'];
        setState(() {
          _messages = loadedRaw
              .map((m) => {
                    "role": m["role"]?.toString() ?? "",
                    "content": m["content"]?.toString() ?? ""
                  })
              .where((m) {
                final content = m["content"] ?? "";
                return !content.contains("additionalCardContext is not defined") &&
                    !content.contains("Something went wrong");
              })
              .toList();
        });
      }
    });
  }

  // Save chat history to Firestore
  Future<void> _saveChatHistory(List<Map<String, String>> newMessages) async {
    try {
      await FirebaseFirestore.instance
          .doc('users/${widget.uid}/chats/history')
          .set({'messages': newMessages});
    } catch (e) {
      debugPrint("Error saving chat history: $e");
    }
  }

  List<Map<String, dynamic>> _buildGeminiContents(List<Map<String, String>> msgs) {
    final mapped = msgs.map((m) => {
      "role": m["role"] == "assistant" ? "model" : "user",
      "parts": [{"text": m["content"] ?? ""}]
    }).toList();

    int start = 0;
    while (start < mapped.length && mapped[start]["role"] == "model") {
      start++;
    }
    final trimmed = mapped.sublist(start);

    final List<Map<String, dynamic>> merged = [];
    for (final turn in trimmed) {
      if (merged.isNotEmpty && merged.last["role"] == turn["role"]) {
        final lastParts = List<Map<String, dynamic>>.from(merged.last["parts"]);
        final updatedText = "${lastParts[0]["text"]}\n\n${(turn["parts"] as List)[0]["text"]}";
        merged.last["parts"] = [{"text": updatedText}];
      } else {
        merged.add({
          "role": turn["role"],
          "parts": [{"text": (turn["parts"] as List)[0]["text"]}]
        });
      }
    }
    return merged;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _loading) return;

    final updatedMessages = List<Map<String, String>>.from(_messages);
    updatedMessages.add({"role": "user", "content": text});

    setState(() {
      _messages = updatedMessages;
      _messageController.clear();
      _loading = true;
    });
    await _saveChatHistory(updatedMessages);

    try {
      String additionalCardContext = "";
      try {
        final stopWords = {
          "should", "i", "buy", "sell", "hold", "do", "you", "think", "what", "is", "how", "much", "about", 
          "card", "rookie", "rc", "cardiq", "advisor", "shall", "buys", "him", "he", "hot", "player", "now",
          "the", "a", "an", "for", "check", "me", "please", "tell", "are", "was", "were", "be", "been", "being",
          "have", "has", "had", "having", "does", "did", "doing", "and", "but", "or", "as", "if", "because",
          "of", "at", "by", "with", "against", "between", "into", "through", "during", "before", "after",
          "above", "below", "to", "from", "up", "down", "in", "out", "on", "off", "over", "under", "again",
          "further", "then", "once", "here", "there", "when", "where", "why", "all", "any", "both", "each",
          "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so",
          "than", "too", "very", "can", "will", "just", "would", "could", "want", "gets"
        };
        
        final cleanedQuery = text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty && !stopWords.contains(w))
            .join(' ')
            .trim();

        List? results;
        if (cleanedQuery.length > 2) {
          debugPrint("[Advisor Chat] Cleaned search term: '$cleanedQuery'");
          // Try AI query first
          try {
            final searchUrl = Uri.parse("https://api.cardsight.ai/v1/ai/query");
            final searchRes = await http.post(
              searchUrl,
              headers: {
                "X-API-Key": AppConstants.cardSightApiKey,
                "Content-Type": "application/json",
              },
              body: jsonEncode({"query": cleanedQuery}),
            ).timeout(const Duration(seconds: 8));
            
            if (searchRes.statusCode == 200) {
              final searchData = jsonDecode(searchRes.body);
              results = searchData['results'] as List?;
            }
          } catch (e) {
            debugPrint("AI query endpoint failed, falling back to catalog search");
          }

          // Fallback: If AI query returned no results, try fuzzy search with cleaned query
          if (results == null || results.isEmpty) {
            final fallbackUrl = Uri.parse("https://api.cardsight.ai/v1/catalog/search?q=${Uri.encodeComponent(cleanedQuery)}&type=card&take=5");
            final fallbackRes = await http.get(fallbackUrl, headers: {
              "X-API-Key": AppConstants.cardSightApiKey,
              "Content-Type": "application/json",
            });
            if (fallbackRes.statusCode == 200) {
              final fallbackData = jsonDecode(fallbackRes.body);
              results = fallbackData['results'] as List?;
            }
          }
        }
        
        if (results != null && results.isNotEmpty) {
          final topCards = results.take(5).toList();
          final cardIds = topCards.map((c) => c['id']).where((id) => id != null).toList();
          
          final Map<String, double> bulkPricingMap = {};
          try {
            final pricingBulkUri = Uri.parse("https://api.cardsight.ai/v1/pricing/");
            final bulkRes = await http.post(
              pricingBulkUri,
              headers: {
                "X-API-Key": AppConstants.cardSightApiKey,
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
                    final rawSales = pricingData['raw']?['records'] as List? ?? [];
                    final gradedSales = pricingData['graded'] as List? ?? [];
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
                    bulkPricingMap[r['card_id']] = avgPrice;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint("Bulk pricing for advisor failed: $e");
          }

          final mainCard = topCards[0];
          final mainCardId = mainCard['id'];

          final pricingUrl = Uri.parse("https://api.cardsight.ai/v1/pricing/$mainCardId");
          final pricingRes = await http.get(pricingUrl, headers: {
            "X-API-Key": AppConstants.cardSightApiKey,
            "Content-Type": "application/json",
          });

          final marketUrl = Uri.parse("https://api.cardsight.ai/v1/marketplace/$mainCardId");
          final marketRes = await http.get(marketUrl, headers: {
            "X-API-Key": AppConstants.cardSightApiKey,
            "Content-Type": "application/json",
          });

          String topCardsSummary = "";
          for (int i = 0; i < topCards.length; i++) {
            final c = topCards[i];
            final price = bulkPricingMap[c['id']] ?? 0.0;
            final priceStr = price > 0 ? "\$${price.round().toString()}" : "N/A";
            topCardsSummary += "${i+1}. ${c['year']} ${c['name'] ?? c['player'] ?? ''} (${c['releaseName'] ?? ''} ${c['setName'] ?? ''}) - Est. Value: $priceStr\n";
          }
          topCardsSummary = topCardsSummary.trim();

          String compsList = "";
          String activeList = "";
          String yearlyTrendStr = "";

          if (pricingRes.statusCode == 200) {
            final pricingData = jsonDecode(pricingRes.body);
            final rawSales = pricingData['raw']?['records'] as List? ?? [];
            final gradedObj = pricingData['graded'];
            final List gradedSales = (gradedObj is List) ? gradedObj : (gradedObj?['records'] as List? ?? []);
            final List sales = [...rawSales, ...gradedSales];

            final List sortedSales = [...sales];
            sortedSales.sort((a, b) {
              final aDate = DateTime.tryParse(a['date']?.toString() ?? a['sold_date']?.toString() ?? '') ?? DateTime(1970);
              final bDate = DateTime.tryParse(b['date']?.toString() ?? b['sold_date']?.toString() ?? '') ?? DateTime(1970);
              return aDate.compareTo(bDate);
            });

            if (sortedSales.length > 1) {
              final firstSale = sortedSales.first;
              final lastSale = sortedSales.last;
              final double firstVal = double.tryParse((firstSale['price'] ?? firstSale['price_usd'] ?? firstSale['value'] ?? 0.0).toString()) ?? 0.0;
              final double lastVal = double.tryParse((lastSale['price'] ?? lastSale['price_usd'] ?? lastSale['value'] ?? 0.0).toString()) ?? 0.0;
              final firstDate = firstSale['date'] ?? firstSale['sold_date'] ?? 'Past';
              final lastDate = lastSale['date'] ?? lastSale['sold_date'] ?? 'Recent';
              final diffPct = firstVal > 0 ? (((lastVal - firstVal) / firstVal) * 100).toStringAsFixed(1) : "0";
              final sign = (double.tryParse(diffPct) ?? 0.0) > 0 ? "+" : "";
              yearlyTrendStr = "Historical Price Trend (Last 1 Year) for \"${mainCard['year']} ${mainCard['name'] ?? mainCard['player'] ?? ''}\":\n- Starting Price on $firstDate: \$$firstVal\n- Latest Price on $lastDate: \$$lastVal\n- Change over the period: $sign$diffPct%";
            }

            compsList = sales.take(8).map((s) {
              final val = s['price'] ?? s['price_usd'] ?? s['value'] ?? 0.0;
              final date = s['date'] ?? s['sold_date'] ?? 'Recent';
              final grade = s['grade'] ?? 'Raw';
              return "- Sold Date: $date, Price: \$$val, Grade: $grade";
            }).join("\n");
          }

          if (marketRes.statusCode == 200) {
            final marketData = jsonDecode(marketRes.body);
            final records = marketData['raw']?['records'] as List? ?? [];
            activeList = records.take(5).map((a) {
              final val = a['price'] ?? a['price_usd'] ?? a['value'] ?? 0.0;
              return "- Active Listing: ${a['title'] ?? mainCard['name']}, Price: \$$val";
            }).join("\n");
          }

          additionalCardContext = "\n\nLive API data gathered for \"${mainCard['name'] ?? mainCard['player'] ?? ''}\":\n\nTop Cards Found in Catalog:\n$topCardsSummary\n\n${yearlyTrendStr.isNotEmpty ? yearlyTrendStr : 'Historical 1-year cost data trend: N/A (single sale record or new player).'}\n\nRecent Pricing Comps:\n${compsList.isNotEmpty ? compsList : 'None found.'}\n\nActive Marketplace Listings:\n${activeList.isNotEmpty ? activeList : 'None found.'}";
        }
      } catch (e) {
        debugPrint("CardSight advisor pre-gathering failed: $e");
      }

      // Fetch portfolio items to inject into system prompt context
      final snapshot = await FirebaseFirestore.instance
          .collection('users/${widget.uid}/portfolios')
          .get();
      
      double totalCost = 0.0;
      double totalValue = 0.0;
      final cardsStr = snapshot.docs.map((doc) {
        final data = doc.data();
        final qty = (data['quantity'] ?? 1) as num;
        final buyPrice = (data['purchasePrice'] ?? 0.0) as num;
        final currVal = (data['currentValue'] ?? 0.0) as num;
        totalCost += buyPrice * qty;
        totalValue += currVal * qty;
        return "${qty}x ${data['year']} ${data['player']} (${data['set']}, ${data['grade']}) — buy price: \$${buyPrice.toStringAsFixed(2)}, est: \$${currVal.toStringAsFixed(2)}";
      }).join("\n");

      final double totalGainPct = totalCost > 0 ? ((totalValue - totalCost) / totalCost) * 100 : 0.0;

      final trendsStr = [
        "Wembanyama Prizm RC: current price \$40.0 (+5.2% 📈)",
        "Shohei Ohtani Chrome Auto: current price \$1420.0 (+8.5% 📈)",
        "Patrick Mahomes Prizm: current price \$2850.0 (-2.4% 📉)",
        "Caitlin Clark Select RC: current price \$92.0 (+12.1% 📈)",
        "Luka Doncic Prizm RC: current price \$150.0 (+5.8% 📈)",
        "Connor Bedard Young Guns: current price \$225.0 (+14.5% 📈)",
      ].join("\n");

      final systemPrompt = """
You are Kartis, the client's premium sports card financial advisor. Your sole purpose is to analyze the market, player performance/news, market trends, and the client's portfolio to tell them exactly when to BUY, SELL, or HOLD. You do all the analytical work and give clear, decisive instructions so the client does not have to think.

Client's Active Portfolio:
${cardsStr.isEmpty ? 'Empty portfolio' : cardsStr}
Total Invested: \$${totalCost.toStringAsFixed(2)} | Current Value: \$${totalValue.toStringAsFixed(2)} | Return: ${totalGainPct.toStringAsFixed(1)}%

Current Market Trends:
$trendsStr
$additionalCardContext

Instructions:
- IMPORTANT: Prioritize the live API data provided above (under Live API data gathered) as the absolute source of truth for pricing, comps, and trends. Never claim there is no pricing data, no completed sales, or that the market is undeveloped if estimated values or sales are listed in the live API data.
- Act as a decisive financial advisor. Tell the client exactly when to BUY, SELL, or HOLD specific cards in their portfolio or watchlists. Do not give generic or passive advice.
- When suggesting actions, prioritize the client's risk management and ROI maximization.
- Keep responses concise, direct, and under 200 words. Speak like a professional card fund manager. Use bold headings and clean formatting.
""";

      final apiKey = AppConstants.geminiApiKey;

      if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
        final errorMessages = List<Map<String, String>>.from(_messages);
        errorMessages.add({
          "role": "assistant",
          "content": "Please configure your Gemini API Key inside `lib/core/constants/app_constants.dart` to test advisor responses."
        });
        setState(() {
          _messages = errorMessages;
        });
        await _saveChatHistory(errorMessages);
        return;
      }

      final reply = await GeminiService.callGemini(
        systemInstruction: systemPrompt,
        contents: _buildGeminiContents(_messages),
        temperature: 0.7,
      );

      final finalMessages = List<Map<String, String>>.from(_messages);
      finalMessages.add({"role": "assistant", "content": reply});

      setState(() {
        _messages = finalMessages;
      });
      await _saveChatHistory(finalMessages);
    } catch (e) {
      final errorMessages = List<Map<String, String>>.from(_messages);
      errorMessages.add({"role": "assistant", "content": "Error calling AI: $e"});
      setState(() {
        _messages = errorMessages;
      });
      await _saveChatHistory(errorMessages);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                "Should I sell anything?",
                "What performance is best?",
                "What to add?"
              ].map((q) => Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  backgroundColor: AppColors.cardBg,
                  onPressed: () {
                    _messageController.text = q;
                  },
                ),
              )).toList(),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg["role"] == "user";
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: GlassCard(
                  color: isUser ? AppColors.gold : AppColors.cardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Text(
                      msg["content"] ?? "",
                      style: TextStyle(
                        fontSize: 13,
                        color: isUser ? AppColors.bg : AppColors.textPrimary,
                        fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(hintText: "Ask about a card, trend..."),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.gold),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
