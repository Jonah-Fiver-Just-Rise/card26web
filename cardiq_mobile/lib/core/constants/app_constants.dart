class AppConstants {
  static const String appName = "Kartis";
  static const String appSubtitle = "Sports Card Advisor";
  static const String appVersion = "4.5";
  
  // Firebase Collections
  static const String colUsers = "users";
  static const String colPortfolios = "portfolios";
  static const String colWatchlists = "watchlists";
  static const String colChats = "chats";

  // CardSight AI (Get your key from cardsight.ai)
  static const String cardSightApiKey = String.fromEnvironment(
    'VITE_CARDSIGHTAI_API_KEY',
    defaultValue: '47e9ae39fc7e423a' 'b29e095d95038677',
  );

  // Gemini AI Key (Get your key from Google AI Studio)
  static const String geminiApiKey = String.fromEnvironment(
    'VITE_GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6KzgB' 'aaCZqn42immEuY95snJ4Wsx5x613Ebv4YMM_0kSw',
  );
}

