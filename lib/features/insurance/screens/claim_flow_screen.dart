import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/device_auth_service.dart';

class ClaimFlowScreen extends ConsumerStatefulWidget {
  const ClaimFlowScreen({super.key});

  @override
  ConsumerState<ClaimFlowScreen> createState() => _ClaimFlowScreenState();
}

class _ClaimFlowScreenState extends ConsumerState<ClaimFlowScreen> {
  static const DeviceAuthService _deviceAuth = DeviceAuthService();
  bool _isRunning = false;
  int _activeStep = -1;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _runClaim() async {
    final user = ref.read(userProvider);
    final location = ref.read(locationProvider);
    if (user == null) return;

    if (!user.isVerified) {
      setState(() => _error = 'Eligibility failed: identity verification is required');
      return;
    }
    final authenticated = await _deviceAuth.authenticate(
      reason: 'Confirm your claim with fingerprint',
    );
    if (!authenticated) {
      setState(() => _error = 'Biometric confirmation failed. Claim was not submitted.');
      return;
    }

    setState(() {
      _isRunning = true;
      _activeStep = 0;
      _result = null;
      _error = null;
    });

    const delays = [
      'Checking weekly income',
      'Checking disruptions',
      'Running fraud detection',
    ];
    for (var i = 0; i < delays.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _activeStep = i);
    }

    try {
      final result = await ref.read(claimProvider.notifier).submitClaim(
            userId: user.userId,
            lat: location.lat,
            lon: location.lon,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isRunning = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final claimState = ref.watch(claimProvider);

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Claim Flow'),
      ),
      body: SafeArea(
        child: FutureBuilder<InsuranceSummaryModel>(
          future: ApiService.getInsuranceSummary(user.userId),
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final canClaim = user.isVerified && (summary?.claimReady ?? false);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClaimSectionCard(
                    title: 'Precheck',
                    child: Column(
                      children: [
                        _ClaimLine(label: 'Eligibility verified', value: user.isVerified ? 'YES' : 'NO'),
                        const SizedBox(height: 10),
                        _ClaimLine(label: 'Policy status', value: summary?.policyStatus ?? 'NOT PURCHASED'),
                        const SizedBox(height: 10),
                        _ClaimLine(label: 'Claim window', value: summary?.claimMessage ?? 'Unavailable'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ClaimSectionCard(
                    title: 'Analysis',
                    child: Column(
                      children: [
                        _AnimatedClaimStep(label: 'Checking weekly income', active: _activeStep >= 0),
                        const SizedBox(height: 10),
                        _AnimatedClaimStep(label: 'Checking disruptions', active: _activeStep >= 1),
                        const SizedBox(height: 10),
                        _AnimatedClaimStep(label: 'Running fraud detection', active: _activeStep >= 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_result != null || _error != null || claimState.hasError)
                    _ClaimSectionCard(
                      title: 'Result',
                      child: _ClaimResult(
                        result: _result,
                        error: _error ?? (claimState.hasError ? claimState.error.toString() : null),
                      ),
                    ),
                  if (_result != null || _error != null || claimState.hasError)
                    const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRunning || !canClaim ? null : _runClaim,
                      child: Text(
                        _isRunning
                            ? 'Verifying...'
                            : canClaim
                                ? 'Claim Insurance'
                                : (summary?.claimMessage ?? 'Claim Unavailable'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ClaimSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ClaimSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ClaimLine extends StatelessWidget {
  final String label;
  final String value;

  const _ClaimLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AnimatedClaimStep extends StatelessWidget {
  final String label;
  final bool active;

  const _AnimatedClaimStep({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primaryColor.withOpacity(0.14)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimResult extends StatelessWidget {
  final Map<String, dynamic>? result;
  final String? error;

  const _ClaimResult({required this.result, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(error!, style: const TextStyle(color: AppTheme.errorColor));
    }
    if (result == null) return const SizedBox.shrink();

    final approved = (result!['status'] as String? ?? '').toUpperCase() == 'APPROVED';
    final weeklyLoss = (result!['weekly_loss'] as num?)?.toDouble() ?? 0.0;
    final payout = (result!['payout'] as num?)?.toDouble() ?? 0.0;
    final reasons = (result!['reasons'] as List?)?.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          approved ? 'APPROVED' : 'REJECTED',
          style: TextStyle(
            color: approved ? AppTheme.successColor : AppTheme.errorColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        if (approved) ...[
          Text('Weekly Loss: Rs ${weeklyLoss.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Payout Amount: Rs ${payout.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('Credited to bank', style: TextStyle(color: AppTheme.successColor)),
        ] else ...[
          Text(
            reasons ?? 'Claim could not be approved',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}
