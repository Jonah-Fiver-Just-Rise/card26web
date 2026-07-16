import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/custom_button.dart';
import 'core/models/card_model.dart';

// Tabs
import 'features/portfolio/portfolio_tab.dart';
import 'features/history/history_tab.dart';
import 'features/watchlist/watchlist_tab.dart';
import 'features/grading/grading_tab.dart';
import 'features/advisor/advisor_tab.dart';
import 'features/market/market_tab.dart';
import 'features/profile/profile_screen.dart';
import 'features/splash/splash_screen.dart';

import 'core/services/notification_service.dart';

// # Run this inside the cardiq_mobile directory:
// flutter run --dart-define-from-file=../cardiq/.env
// flutter build apk --release --dart-define-from-file=../cardiq/.env


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.cardSightApiKey.isEmpty) {
    debugPrint("⚠️ WARNING: CardSight API Key is empty! Make sure to run the app with: flutter run --dart-define-from-file=../cardiq/.env");
  } else {
    debugPrint("✅ CardSight API Key loaded successfully.");
  }
  if (AppConstants.geminiApiKey.isEmpty) {
    debugPrint("⚠️ WARNING: Gemini API Key is empty! Make sure to run the app with: flutter run --dart-define-from-file=../cardiq/.env");
  } else {
    debugPrint("✅ Gemini API Key loaded successfully.");
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init deferred or failed: $e");
  }
  
  // Initialize notification service
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  
  runApp(const KartisApp());
}

class KartisApp extends StatelessWidget {
  const KartisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  String _errorMessage = "";
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _errorMessage = "";
      _loading = true;
    });
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Authentication failed";
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                ),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    text: "Kart",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                    children: [
                      TextSpan(
                        text: "is",
                        style: TextStyle(color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppConstants.appSubtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email Address"),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                  obscureText: true,
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: AppColors.lossRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                CustomButton(
                  text: _isSignUp ? "Create Account" : "Sign In",
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = "";
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isSignUp ? "Already have an account? " : "New to Kartis? ",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isSignUp ? "Sign In" : "Sign Up",
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "Version V.4.5",
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  "Developed by Just Rise Technologies WLL",
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users/${user.uid}/portfolios')
          .snapshots(),
      builder: (context, snapshot) {
        final cards = snapshot.hasData
            ? snapshot.data!.docs.map((doc) => CardModel.fromFirestore(doc)).toList()
            : <CardModel>[];

        if (snapshot.hasData) {
          NotificationService.evaluatePortfolioAndNotify(cards);
        }

        final List<Widget> tabs = [
          PortfolioTab(uid: user.uid),
          HistoryTab(cards: cards),
          WatchlistTab(uid: user.uid),
          const GradingTab(),
          AdvisorTab(uid: user.uid),
          const MarketTab(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline, size: 22, color: AppColors.gold),
                tooltip: "My Profile",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                tooltip: "Sign Out",
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: tabs[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Portfolio'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Watchlist'),
              BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Grading'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Advisor'),
              BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Market'),
            ],
          ),
        );
      },
    );
  }
}
