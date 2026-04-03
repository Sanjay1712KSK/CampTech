import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/custom_text_field.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/auth/screens/login_screen.dart';
import 'package:guidewire_gig_ins/features/auth/screens/otp_verification_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _countryCode = '+91';
  AvailabilityResult? _usernameAvailability;
  AvailabilityResult? _emailAvailability;
  List<String> _suggestedUsernames = const [];
  Timer? _usernameDebounce;
  Timer? _emailDebounce;

  static const _countryCodes = ['+91', '+1', '+44', '+971', '+65'];

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final value = _usernameController.text.trim();
    _usernameDebounce?.cancel();
    if (value.length < 3) {
      setState(() {
        _usernameAvailability = null;
        _suggestedUsernames = const [];
      });
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await ApiService.checkUsernameAvailability(value);
        final suggestions = result.available ? <String>[] : await ApiService.suggestUsernames(value);
        if (!mounted) return;
        setState(() {
          _usernameAvailability = result;
          _suggestedUsernames = suggestions;
        });
      } catch (_) {}
    });
  }

  void _onEmailChanged() {
    final value = _emailController.text.trim();
    _emailDebounce?.cancel();
    if (!value.contains('@')) {
      setState(() => _emailAvailability = null);
      return;
    }
    _emailDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await ApiService.checkEmailAvailability(value);
        if (!mounted) return;
        setState(() => _emailAvailability = result);
      } catch (_) {}
    });
  }

  double get _passwordScore {
    final password = _passwordController.text;
    double score = 0;
    if (password.length >= 8) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 0.2;
    if (RegExp(r'\d').hasMatch(password)) score += 0.15;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 0.15;
    return score.clamp(0, 1);
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || phone.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all registration fields first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final registration = await ApiService.signup(
        email: email,
        countryCode: _countryCode,
        phoneNumber: phone,
        username: username,
        password: password,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            userId: registration.userId,
            username: registration.username,
            password: password,
            email: registration.email,
            phone: registration.phone,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usernameColor = _usernameAvailability == null
        ? AppTheme.textSecondary
        : (_usernameAvailability!.available ? AppTheme.successColor : AppTheme.warningColor);
    final emailColor = _emailAvailability == null
        ? AppTheme.textSecondary
        : (_emailAvailability!.available ? AppTheme.successColor : AppTheme.warningColor);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              const Text(
                'GigShield',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create your insured gig identity',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Step 1 of onboarding: secure credentials before OTP, KYC, and platform linking.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _emailController,
                hintText: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
              ),
              if (_emailAvailability != null) ...[
                const SizedBox(height: 8),
                Text(
                  _emailAvailability!.message,
                  style: TextStyle(color: emailColor, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _countryCode,
                      dropdownColor: AppTheme.surfaceColor,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                      ),
                      items: _countryCodes
                          .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _countryCode = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _phoneController,
                      hintText: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _usernameController,
                hintText: 'Username',
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.textSecondary),
              ),
              if (_usernameAvailability != null) ...[
                const SizedBox(height: 8),
                Text(
                  _usernameAvailability!.message,
                  style: TextStyle(color: usernameColor, fontSize: 12),
                ),
              ],
              if (_suggestedUsernames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedUsernames
                      .map(
                        (suggestion) => ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _usernameController.text = suggestion,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                hintText: 'Password',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _passwordScore,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _passwordScore < 0.4
                        ? AppTheme.errorColor
                        : _passwordScore < 0.75
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use at least 8 characters with uppercase, lowercase, number, and special character.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: _isLoading ? 'Creating account...' : 'Continue to OTP',
                isLoading: _isLoading,
                onPressed: _continue,
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Already onboarded? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Log in',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
