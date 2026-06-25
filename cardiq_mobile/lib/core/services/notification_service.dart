import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/card_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Keep track of card IDs we have already sent notifications for in this session
  // to avoid spamming the user every time the stream updates.
  static final Set<String> _notifiedCardIds = {};

  /// Initialize notifications for iOS and Android
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification clicked: ${response.payload}");
        },
      );
      debugPrint("NotificationService initialized successfully.");
    } catch (e) {
      debugPrint("NotificationService initialization failed: $e");
    }
  }

  /// Request permissions for push/local notifications
  static Future<void> requestPermissions() async {
    try {
      // For Android 13+ (API 33+)
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // For iOS
      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint("Failed to request notification permissions: $e");
    }
  }

  /// Send a native peak-sell recommendation notification
  static Future<void> showPeakSellNotification({
    required int id,
    required String cardName,
    required double roiPercent,
    required double currentValue,
  }) async {
    final title = "🔥 Market Peak: Sell $cardName!";
    final body = "Your card is up +${roiPercent.toStringAsFixed(1)}% (Valued at \$${currentValue.toStringAsFixed(0)}). Market trends indicate this is the peak time to take profits!";

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cardiq_peak_sell_channel',
      'Market Sell Alerts',
      channelDescription: 'Notifications for sports card peak valuation sell recommendations',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFC9A84C), // Gold color to match theme
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: cardName,
      );
    } catch (e) {
      debugPrint("Failed to show notification: $e");
    }
  }

  /// Evaluates portfolio cards and sends a notification for any card that has hit
  /// a peak sell trend threshold (defined here as >= 30% ROI/gain).
  static void evaluatePortfolioAndNotify(List<CardModel> cards) {
    if (cards.isEmpty) return;

    for (var card in cards) {
      // Skip if card has invalid pricing or if we've already notified about it
      if (card.purchasePrice <= 0 || card.currentValue <= 0) continue;
      if (_notifiedCardIds.contains(card.id)) continue;

      final roi = card.currentValue - card.purchasePrice;
      final roiPct = (roi / card.purchasePrice) * 100;

      // Peak sell threshold: 30% or more ROI
      if (roiPct >= 30.0) {
        _notifiedCardIds.add(card.id);
        
        // Generate a unique integer ID from the card's document ID hash
        final notificationId = card.id.hashCode;

        showPeakSellNotification(
          id: notificationId,
          cardName: "${card.year} ${card.player} (${card.set})",
          roiPercent: roiPct,
          currentValue: card.currentValue,
        );
      }
    }
  }

  /// Simulate a peak sell alert after a delay (used for manual user testing/verification)
  static Future<void> simulatePeakSellAlert(CardModel card, {int delaySeconds = 4}) async {
    final roi = card.currentValue - card.purchasePrice;
    final roiPct = card.purchasePrice > 0 ? (roi / card.purchasePrice) * 100 : 35.0;

    Future.delayed(Duration(seconds: delaySeconds), () async {
      await showPeakSellNotification(
        id: 9999,
        cardName: "${card.year} ${card.player} (${card.set})",
        roiPercent: roiPct > 0 ? roiPct : 35.0,
        currentValue: card.currentValue > 0 ? card.currentValue : 780.0,
      );
    });
  }

  /// Reset the session notifications history
  static void clearNotifiedSession() {
    _notifiedCardIds.clear();
  }
}
