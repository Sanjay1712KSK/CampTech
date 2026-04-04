import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/auth/screens/login_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class EmailConfirmationResultScreen extends StatefulWidget {
  final Uri link;

  const EmailConfirmationResultScreen({
    super.key,
    required this.link,
  });

  @override
  State<EmailConfirmationResultScreen> createState() => _EmailConfirmationResultScreenState();
}

class _EmailConfirmationResultScreenState extends State<EmailConfirmationResultScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String _message = 'Confirming your email...';
  String? _confirmedEmail;

  @override
  void initState() {
    super.initState();
    _confirmFromLink();
  }

  Future<void> _confirmFromLink() async {
    final token = widget.link.queryParameters['token'];
    final expectedEmail = widget.link.queryParameters['email']?.trim().toLowerCase();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'This confirmation link is missing its token.';
      });
      return;
    }

    try {
      final result = await ApiService.confirmAccount(token);
      final actualEmail = result.email.trim().toLowerCase();
      final matchesEmail = expectedEmail == null || expectedEmail.isEmpty || expectedEmail == actualEmail;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = result.accountConfirmed && matchesEmail;
        _confirmedEmail = result.email;
        _message = matchesEmail
            ? 'Email confirmation done. You can continue DigiLocker verification in the app.'
            : 'This confirmation link does not match the signed-up email.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSuccess ? 'Email confirmed' : 'Email confirmation',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _message,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      if (_confirmedEmail != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Confirmed email: $_confirmedEmail',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              const Spacer(),
              PrimaryButton(
                text: _isSuccess ? 'Continue in app' : 'Back to login',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
