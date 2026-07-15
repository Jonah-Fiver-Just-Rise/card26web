import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class GeminiService {
  static Future<String> callGemini({
    required String systemInstruction,
    required List<dynamic> contents,
    double temperature = 0.7,
    int maxOutputTokens = 2048,
  }) async {
    final apiKey = AppConstants.geminiApiKey;
    if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
      throw Exception("Gemini API key is not configured.");
    }

    final models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"];
    String? reply;
    dynamic lastError;

    for (final model in models) {
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final res = await http.post(
            Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent"),
            headers: {
              "Content-Type": "application/json",
              "X-goog-api-key": apiKey,
            },
            body: jsonEncode({
              "systemInstruction": {
                "parts": [{"text": systemInstruction}]
              },
              "contents": contents,
              "generationConfig": {
                "maxOutputTokens": maxOutputTokens,
                "temperature": temperature,
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
                    return reply; // Success!
                  }
                }
              }
            }
            throw Exception("Empty or invalid response structure from model.");
          } else if (res.statusCode == 429) {
            retryCount++;
            debugPrint("Gemini quota exceeded (429) for model $model. Retry $retryCount/$maxRetries after delay...");
            if (retryCount < maxRetries) {
              // Wait 2s, 4s, 8s
              await Future.delayed(Duration(seconds: retryCount * 2));
              continue;
            }
            lastError = "HTTP 429: Rate limit exceeded after retries.";
            break;
          } else {
            lastError = "HTTP ${res.statusCode}: ${res.body}";
            break; // Try next model on other errors
          }
        } catch (e) {
          lastError = e;
          break; // Try next model on exceptions (e.g. timeout)
        }
      }
    }

    throw Exception(lastError ?? "Failed to get response from Gemini.");
  }
}
