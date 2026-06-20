import 'package:flutter/material';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/glass_card.dart';

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
      "content": "Hey! I'm your CardIQ financial advisor. Ask me anything about valuations, buy/sell signals, grading strategy, or market trends."
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
      
      final cardsStr = snapshot.docs.map((doc) {
        final data = doc.data();
        final qty = data['quantity'] ?? 1;
        return "$qty\x ${data['year']} ${data['player']} (${data['set']}, ${data['grade']}) — buy price: \$${data['purchasePrice']}, est: \$${data['currentValue']}";
      }).join("\n");

      const apiKey = "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"; 

      if (apiKey == "YOUR_OPENAI_API_KEY_HERE") {
        final errorMessages = List<Map<String, String>>.from(_messages);
        errorMessages.add({
          "role": "assistant",
          "content": "Please configure your OpenAI API Key inside `lib/features/advisor/advisor_tab.dart` to test advisor responses."
        });
        setState(() {
          _messages = errorMessages;
        });
        await _saveChatHistory(errorMessages);
        return;
      }

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
              "content": "You are a sports card advisor. User's portfolio:\n$cardsStr\nGive direct advice under 150 words."
            },
            ..._messages.map((m) => {"role": m["role"], "content": m["content"]})
          ]
        }),
      );

      final data = jsonDecode(res.body);
      final reply = data['choices'][0]['message']['content'] ?? "No response.";

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
