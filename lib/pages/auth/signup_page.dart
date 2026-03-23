// lib/pages/auth/signup_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading = false;

  static const _blue       = Color(0xFF2196F3);
  static const _indigoText = Color(0xFF5C6BC0);

  SupabaseClient get _supabase => Supabase.instance.client;

  // ── Password strength ─────────────────────────────────────────────────────

  int _strengthScore(String p) {
    int score = 0;
    if (p.length >= 8)  score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) score++;
    return score.clamp(0, 4);
  }

  Color _strengthColor(int score) {
    switch (score) {
      case 1:  return Colors.red;
      case 2:  return Colors.orange;
      case 3:  return Colors.amber;
      case 4:  return Colors.green;
      default: return Colors.grey[300]!;
    }
  }

  String _strengthLabel(int score) {
    switch (score) {
      case 1:  return 'Weak';
      case 2:  return 'Fair';
      case 3:  return 'Good';
      case 4:  return 'Strong';
      default: return '';
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validatePassword(String password) {
    if (password.length < 8)  return 'At least 8 characters required.';
    if (password.length > 16) return 'Maximum 16 characters allowed.';
    if (!RegExp(r'[A-Z]').hasMatch(password))
      return 'Include at least one uppercase letter (A-Z).';
    if (!RegExp(r'[a-z]').hasMatch(password))
      return 'Include at least one lowercase letter (a-z).';
    if (!RegExp(r'[0-9]').hasMatch(password))
      return 'Include at least one number (0-9).';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password))
      return 'Include at least one symbol (!@#\$%^&*...).';
    return null;
  }

  // ── Sign up ───────────────────────────────────────────────────────────────

  Future<void> _handleSignUp() async {
    final email    = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _snack('Please fill in all fields', error: true);
      return;
    }
    if (!GetUtils.isEmail(email)) {
      _snack('Please enter a valid email address', error: true);
      return;
    }
    final passError = _validatePassword(password);
    if (passError != null) {
      _snack(passError, error: true);
      return;
    }
    if (password != confirm) {
      _snack('Passwords do not match', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session != null) {
        _snack('Account created! Welcome 🎉');
        Get.offAllNamed('/home');
        return;
      }

      if (response.user != null) {
        _snack('Account created! Check your email to confirm your account.');
        Get.offAll(() => SignInPage());
        return;
      }

      _snack('Signup failed. Please try again.', error: true);
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(_friendlyAuthError(e.message), error: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already registered. Try signing in.';
    }
    if (lower.contains('password')) {
      return 'Password is too weak. Use a stronger one.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return msg;
  }

  void _snack(String message, {bool error = false}) {
    Get.snackbar(
      error ? 'Error' : 'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error ? Colors.red : Colors.green,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordCtrl.text;
    final score    = _strengthScore(password);
    final color    = _strengthColor(score);
    final label    = _strengthLabel(score);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Logo ─────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security, color: _blue, size: 38),
                ),
              ),
              const SizedBox(height: 24),

              const Text("Let's get started",
                  style: TextStyle(fontSize: 28,
                      fontWeight: FontWeight.bold, color: _blue)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Get.to(() => SignInPage()),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                    children: [
                      TextSpan(text: 'Already have an account? '),
                      TextSpan(text: 'Sign in',
                          style: TextStyle(color: _blue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Email ────────────────────────────────────────────────────
              _label('Email'),
              const SizedBox(height: 8),
              _buildField(
                controller: _emailCtrl,
                hint: 'your@email.com',
                keyboard: TextInputType.emailAddress,
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),

              // ── Password ─────────────────────────────────────────────────
              _label('Password'),
              const SizedBox(height: 8),
              _buildField(
                controller: _passwordCtrl,
                hint: '••••••••',
                obscure: _obscurePassword,
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey, size: 20),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // ── Strength bar ─────────────────────────────────────────────
              if (password.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    ...List.generate(4, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < score ? color : Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Text(label,
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600, color: color)),
                  ],
                ),
                const SizedBox(height: 10),
                _req('8–16 characters',
                    password.length >= 8 && password.length <= 16),
                _req('Uppercase & lowercase letters',
                    RegExp(r'[A-Z]').hasMatch(password) &&
                        RegExp(r'[a-z]').hasMatch(password)),
                _req('At least one number',
                    RegExp(r'[0-9]').hasMatch(password)),
                _req('At least one symbol (!@#\$...)',
                    RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)),
              ],

              const SizedBox(height: 20),

              // ── Confirm password ─────────────────────────────────────────
              _label('Confirm password'),
              const SizedBox(height: 8),
              _buildField(
                controller: _confirmCtrl,
                hint: '••••••••',
                obscure: _obscureConfirm,
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey, size: 20),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // ── Match indicator ──────────────────────────────────────────
              if (_confirmCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      password == _confirmCtrl.text
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 14,
                      color: password == _confirmCtrl.text
                          ? Colors.green : Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      password == _confirmCtrl.text
                          ? 'Passwords match'
                          : 'Passwords do not match',
                      style: TextStyle(
                        fontSize: 12,
                        color: password == _confirmCtrl.text
                            ? Colors.green : Colors.red)),
                  ],
                ),
              ],

              const SizedBox(height: 36),

              // ── Sign up button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  'By signing up you agree to the terms and conditions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13,
          color: _indigoText, fontWeight: FontWeight.w500));

  Widget _req(String text, bool met) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: met ? Colors.green : Colors.grey[400]),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(fontSize: 12,
                color: met ? Colors.green : Colors.grey[500])),
      ],
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
        prefixIcon: Icon(icon, color: _blue, size: 20),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
      ),
    );
  }
}