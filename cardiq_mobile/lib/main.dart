import 'package:flutter/material';
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





// # Run this inside the cardiq_mobile directory:
// flutter run --dart-define-from-file=../cardiq/.env


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init deferred or failed: $e");
  }
  runApp(const CardIqApp());
}

class CardIqApp extends StatelessWidget {
  const CardIqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
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
                RichText(
                  text: const TextSpan(
                    text: "Card",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                    children: [
                      TextSpan(
                        text: "IQ",
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
                      text: _isSignUp ? "Already have an account? " : "New to CardIQ? ",
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

        final List<Widget> tabs = [
          PortfolioTab(uid: user.uid),
          HistoryTab(cards: cards),
          WatchlistTab(uid: user.uid),
          const GradingTab(),
          AdvisorTab(uid: user.uid),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Center(
                  child: Text(
                    user.email ?? "",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: tabs[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
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
            ],
          ),
        );
      },
    );
  }
}
