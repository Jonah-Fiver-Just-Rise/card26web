import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../core/constants/app_constants.dart';

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
        "Wembanyama RC 2023: current price \$625.0 (+14.2% 📈)",
        "Shohei Ohtani Chrome Auto: current price \$1420.0 (+8.5% 📈)",
        "Patrick Mahomes Prizm: current price \$2850.0 (-2.4% 📉)",
        "Caitlin Clark RC: current price \$310.0 (+22.1% 📈)",
        "Luka Dončić Prizm PSA 10: current price \$780.0 (+5.8% 📈)",
        "Connor McDavid Young Guns: current price \$1250.0 (-1.8% 📉)",
      ].join("\n");

      final systemPrompt = """
You are Kartis, the client's premium sports card financial advisor. Your sole purpose is to analyze the market, player performance/news, market trends, and the client's portfolio to tell them exactly when to BUY, SELL, or HOLD. You do all the analytical work and give clear, decisive instructions so the client does not have to think.

Client's Active Portfolio:
${cardsStr.isEmpty ? 'Empty portfolio' : cardsStr}
Total Invested: \$${totalCost.toStringAsFixed(2)} | Current Value: \$${totalValue.toStringAsFixed(2)} | Return: ${totalGainPct.toStringAsFixed(1)}%

Current Market Trends:
$trendsStr

Instructions:
- Take all portfolio details and current market trends, news, and pricing into account.
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
                "parts": [{"text": systemPrompt}]
              },
              "contents": _buildGeminiContents(_messages),
              "generationConfig": {
                "maxOutputTokens": 2048,
                "temperature": 0.7
              }
            }),
          );

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
