import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
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
  final String? appConfirmationLink;

  const AccountConfirmationScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.password,
    required this.email,
    required this.phone,
    required this.confirmationToken,
    required this.confirmationLink,
    this.appConfirmationLink,
  });

  @override
  State<AccountConfirmationScreen> createState() => _AccountConfirmationScreenState();
}

class _AccountConfirmationScreenState extends State<AccountConfirmationScreen> {
  bool _isLoading = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus(silent: true));
  }

  void _continueOnboarding(OnboardingStatusResult status) {
    if (!mounted) return;
    if (status.isDigilockerVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConnectGigScreen(
            userId: widget.userId,
            identifier: widget.username,
            password: widget.password,
            isOnboardingFlow: true,
          ),
        ),
      );
      return;
    }

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
  }

  Future<void> _confirmAccount() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.confirmAccount(widget.confirmationToken);
      final status = await ApiService.getOnboardingStatus(widget.userId);
      _continueOnboarding(status);
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

  Future<void> _checkStatus({bool silent = false}) async {
    setState(() => _isCheckingStatus = true);
    try {
      final status = await ApiService.getOnboardingStatus(widget.userId);
      if (!mounted) return;
      if (status.isAccountConfirmed) {
        _continueOnboarding(status);
        return;
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email, open the confirmation link, then come back here.')),
        );
      }
    } catch (error) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                  'Confirm your email',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent the account confirmation link to ${widget.email}. Open that email on your phone, tap the link, and this app will confirm the same email before you continue onboarding.',
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
                  child: const Text(
                    'DigiLocker verification is mandatory and will open immediately after your email confirmation is completed.',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ),
                if (widget.appConfirmationLink != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'App confirmation link:\n${widget.appConfirmationLink}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
                const Spacer(),
                PrimaryButton(
                  text: _isLoading ? 'Confirming...' : 'Use demo confirm here',
                  isLoading: _isLoading,
                  onPressed: _confirmAccount,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: _isCheckingStatus ? 'Checking email status...' : 'I already confirmed from my email',
                  isLoading: _isCheckingStatus,
                  onPressed: () => _checkStatus(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
