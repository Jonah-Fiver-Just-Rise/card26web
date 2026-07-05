import 'package:cloud_firestore/cloud_firestore.dart';

class WatchlistModel {
  final String id;
  final String player;
  final int year;
  final String set;
  final String grade;
  final String sport;
  final double targetBuy;
  final double currentEst;
  final bool alert;
  final String addedAt;
  final String? imageUrl;
  final String? catalogId;

  WatchlistModel({
    required this.id,
    required this.player,
    required this.year,
    required this.set,
    required this.grade,
    required this.sport,
    required this.targetBuy,
    required this.currentEst,
    required this.alert,
    required this.addedAt,
    this.imageUrl,
    this.catalogId,
  });

  factory WatchlistModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WatchlistModel(
      id: doc.id,
      player: data['player'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      set: data['set'] ?? '',
      grade: data['grade'] ?? '',
      sport: data['sport'] ?? 'Basketball',
      targetBuy: (data['targetBuy'] ?? 0.0).toDouble(),
      currentEst: (data['currentEst'] ?? 0.0).toDouble(),
      alert: data['alert'] ?? false,
      addedAt: data['addedAt'] ?? '',
      imageUrl: data['imageUrl'],
      catalogId: data['catalogId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'player': player,
      'year': year,
      'set': set,
      'grade': grade,
      'sport': sport,
      'targetBuy': targetBuy,
      'currentEst': currentEst,
      'alert': alert,
      'addedAt': addedAt,
      'imageUrl': imageUrl,
      'catalogId': catalogId,
    };
  }
}
