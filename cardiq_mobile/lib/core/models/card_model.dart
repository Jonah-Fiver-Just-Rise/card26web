import 'package:cloud_firestore/cloud_firestore.dart';

class CardModel {
  final String id;
  final String player;
  final int year;
  final String set;
  final String grade;
  final String sport;
  final double purchasePrice;
  final double currentValue;
  final int quantity;
  final String addedAt;

  CardModel({
    required this.id,
    required this.player,
    required this.year,
    required this.set,
    required this.grade,
    required this.sport,
    required this.purchasePrice,
    required this.currentValue,
    required this.quantity,
    required this.addedAt,
  });

  factory CardModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CardModel(
      id: doc.id,
      player: data['player'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      set: data['set'] ?? '',
      grade: data['grade'] ?? '',
      sport: data['sport'] ?? 'Basketball',
      purchasePrice: (data['purchasePrice'] ?? 0.0).toDouble(),
      currentValue: (data['currentValue'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 1,
      addedAt: data['addedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'player': player,
      'year': year,
      'set': set,
      'grade': grade,
      'sport': sport,
      'purchasePrice': purchasePrice,
      'currentValue': currentValue,
      'quantity': quantity,
      'addedAt': addedAt,
    };
  }
}
