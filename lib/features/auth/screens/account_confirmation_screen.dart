import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class AccountConfirmationScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String password;
  final String email;
  final String phone;
  final String confirmationToken;
  final String confirmationLink;

  const AccountConfirmationScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.password,
    required this.email,
    required this.phone,
    required this.confirmationToken,
    required this.confirmationLink,
  });

  @override
  State<AccountConfirmationScreen> createState() => _AccountConfirmationScreenState();
}

class _AccountConfirmationScreenState extends State<AccountConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _confirmAccount() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.confirmAccount(widget.confirmationToken);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DigilockerVerificationScreen(
            userId: widget.userId,
            identifier: widget.username,
            password: widget.password,
            isOnboardingFlow: true,
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activate account',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'A confirmation link was issued to ${widget.email}. For the demo, you can activate it directly below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.confirmationLink,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: _isLoading ? 'Activating...' : 'Open Confirmation Link',
                isLoading: _isLoading,
                onPressed: _confirmAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
