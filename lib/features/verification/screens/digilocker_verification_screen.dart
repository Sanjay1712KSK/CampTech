import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class DigilockerVerificationScreen extends ConsumerStatefulWidget {
  final int? userId;
  final String? identifier;
  final String? password;
  final bool isOnboardingFlow;

  const DigilockerVerificationScreen({
    super.key,
    this.userId,
    this.identifier,
    this.password,
    this.isOnboardingFlow = false,
  });

  @override
  ConsumerState<DigilockerVerificationScreen> createState() => _DigilockerVerificationScreenState();
}

class _DigilockerVerificationScreenState extends ConsumerState<DigilockerVerificationScreen> {
  String _selectedDocument = 'aadhaar';
  bool _isRequesting = false;
  bool _isVerifying = false;
  DigiLockerRequestResult? _request;
  DigiLockerStatusResult? _status;

  int? get _resolvedUserId => widget.userId ?? ref.read(userProvider)?.userId;

  Future<void> _startRequest() async {
    final userId = _resolvedUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User context is missing. Please log in again.')),
      );
      return;
    }
    setState(() => _isRequesting = true);
    try {
      final request = await ApiService.createDigiLockerRequest(
        userId: userId,
        docType: _selectedDocument,
      );
      if (!mounted) return;
      setState(() => _request = request);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _completeVerification() async {
    if (_request == null) return;
    setState(() => _isVerifying = true);
    try {
      final result = await ApiService.verifyDigiLocker(
        requestId: _request!.requestId,
        consentCode: _request!.oauthState,
      );
      if (!mounted) return;
      if (!result.verified) {
        throw Exception('DigiLocker verification failed');
      }
      final userId = _resolvedUserId!;
      final status = await ApiService.getDigiLockerStatusByUserId(userId);
      if (!mounted) return;
      setState(() => _status = status);
      if (widget.isOnboardingFlow) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConnectGigScreen(
              userId: userId,
              identifier: widget.identifier,
              password: widget.password,
              isOnboardingFlow: true,
            ),
          ),
        );
      } else {
        ref.read(userProvider.notifier).updateVerification(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _status?.isVerified ?? ref.watch(userProvider)?.isVerified ?? false;
    return PopScope(
      canPop: !widget.isOnboardingFlow,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.isOnboardingFlow,
          title: const Text('DigiLocker Verification'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mandatory KYC check',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a government document and simulate the DigiLocker consent redirect.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DocCard(
                        title: 'Aadhaar',
                        icon: Icons.credit_card,
                        selected: _selectedDocument == 'aadhaar',
                        onTap: () => setState(() => _selectedDocument = 'aadhaar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DocCard(
                        title: 'Passport',
                        icon: Icons.language_outlined,
                        selected: _selectedDocument == 'passport',
                        onTap: () => setState(() => _selectedDocument = 'passport'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                        isVerified ? 'Status: VERIFIED' : 'Status: PENDING',
                        style: TextStyle(
                          color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_request != null) ...[
                        const SizedBox(height: 16),
                        Text('Mock OAuth redirect:\n${_request!.redirectUrl}'),
                        const SizedBox(height: 12),
                        Text('Demo consent code: ${_request!.oauthState}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: _isRequesting ? 'Creating request...' : 'Start DigiLocker flow',
                  isLoading: _isRequesting,
                  onPressed: _startRequest,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: _isVerifying ? 'Verifying...' : 'Approve consent and verify',
                  isLoading: _isVerifying,
                  onPressed: _request == null ? () {} : _completeVerification,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DocCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
