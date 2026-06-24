class AppConstants {
  static const String appName = "CardIQ";
  static const String appSubtitle = "Sports Card Advisor";
  static const String appVersion = "1.0.0";
  
  // Firebase Collections
  static const String colUsers = "users";
  static const String colPortfolios = "portfolios";
  static const String colWatchlists = "watchlists";
  static const String colChats = "chats";

  // CardSight AI (Get your key from cardsight.ai)
  static const String cardSightApiKey = String.fromEnvironment('VITE_CARDSIGHTAI_API_KEY');

  // Gemini AI Key (Get your key from Google AI Studio)
  static const String geminiApiKey = String.fromEnvironment('VITE_GEMINI_API_KEY');
}

