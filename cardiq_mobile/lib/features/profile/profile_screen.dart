import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String _message = "";
  bool _isError = false;

  Future<void> _changePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _message = "Please enter a new password.";
        _isError = true;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _message = "Password must be at least 6 characters long.";
        _isError = true;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _message = "Passwords do not match.";
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = "";
      _isError = false;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(password);
        setState(() {
          _message = "Password updated successfully!";
          _isError = false;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        throw Exception("No authenticated user found.");
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isError = true;
        if (e.code == 'requires-recent-login') {
          _message = "For security reasons, this action requires you to sign out and log back in first.";
        } else {
          _message = e.message ?? "Failed to update password.";
        }
      });
    } catch (e) {
      setState(() {
        _message = "Error: ${e.toString()}";
        _isError = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "USER PROFILE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: AppColors.gold, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Email Address",
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? "Not logged in",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "SECURITY SETTINGS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Change Password",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                      hintText: "Enter at least 6 characters",
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: "Confirm New Password",
                      hintText: "Re-enter new password",
                    ),
                    obscureText: true,
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isError ? AppColors.lossRed.withValues(alpha: 0.1) : AppColors.gainGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isError ? AppColors.lossRed.withValues(alpha: 0.3) : AppColors.gainGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _isError ? AppColors.lossRed : AppColors.gainGreen,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Update Password",
                    loading: _loading,
                    onPressed: _changePassword,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
