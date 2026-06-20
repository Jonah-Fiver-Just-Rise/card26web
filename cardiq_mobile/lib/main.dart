import 'package:flutter/material';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (will boot using local google-services config files on build)
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
      title: 'CardIQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFFC9A84C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9A84C),
          secondary: Color(0xFF6B6B8A),
          surface: Color(0xFF111118),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF111118),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFF1E1E2E)),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF0D0D18),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2A2A3E)),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFC9A84C)),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          labelStyle: TextStyle(color: Color(0xFF6B6B8A)),
          hintStyle: TextStyle(color: Color(0xFF3A3A5E)),
        ),
      ),
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
              child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
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
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111118),
              border: Border.all(color: const Color(0xFF2A2A3E)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "CardIQ",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Sports Card Investment & AI Advisor",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B6B8A)),
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
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: const Color(0xFF0A0A0F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A0A0F),
                            ),
                          )
                        : Text(
                            _isSignUp ? "Create Account" : "Sign In",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
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
                      style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isSignUp ? "Sign In" : "Sign Up",
                          style: const TextStyle(
                            color: Color(0xFFC9A84C),
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

  final List<Widget> _tabs = [
    const Center(child: Text("Portfolio Tab (Loads Firestore Collection)")),
    const Center(child: Text("History Analytics Chart")),
    const Center(child: Text("Watchlist Favorites")),
    const Center(child: Text("Grading ROI Calculator")),
    const Center(child: Text("AI Advisor Chat")),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text(
          "CardIQ",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Text(
                  user.email ?? "",
                  style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111118),
        selectedItemColor: const Color(0xFFC9A84C),
        unselectedItemColor: const Color(0xFF6B6B8A),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Portfolio'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Watchlist'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Grading'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Advisor'),
        ],
      ),
    );
  }
}
