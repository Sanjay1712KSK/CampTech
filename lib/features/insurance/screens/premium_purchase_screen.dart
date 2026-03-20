import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:local_auth/local_auth.dart';

class PremiumPurchaseScreen extends ConsumerStatefulWidget {
  const PremiumPurchaseScreen({super.key});

  @override
  ConsumerState<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends ConsumerState<PremiumPurchaseScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isPaying = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pay(Map<String, dynamic> premiumData) async {
    final user = ref.read(userProvider);
    if (user == null) return;
    final amount = (premiumData['weekly_premium'] as num?)?.toDouble() ?? 0.0;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text(
              'Buy Weekly Insurance',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: Text(
              'Confirm payment of Rs ${amount.toStringAsFixed(2)} for next week\'s income protection.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Pay Premium'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Confirm premium payment with fingerprint',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!didAuthenticate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric confirmation failed')),
      );
      return;
    }

    setState(() => _isPaying = true);
    try {
      await ApiService.payPremium(user.userId, amount);
      ref.invalidate(premiumProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Coverage Scheduled',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'Weekly policy purchased successfully. This payment covers your upcoming insured week.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumAsync = ref.watch(premiumProvider);
    final user = ref.watch(userProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Weekly Insurance'),
      ),
      body: SafeArea(
        child: premiumAsync.when(
          data: (premiumData) {
            final baseline = (premiumData['baseline'] as num?)?.toDouble() ?? 0.0;
            final weeklyIncome = (premiumData['weekly_income'] as num?)?.toDouble() ?? 0.0;
            final riskScore = (premiumData['risk_score'] as num?)?.toDouble() ?? 0.0;
            final weeklyPremium = (premiumData['weekly_premium'] as num?)?.toDouble() ?? 0.0;
            return FutureBuilder<InsuranceSummaryModel>(
              future: ApiService.getInsuranceSummary(user.userId),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                final helperText = summary == null
                    ? 'This policy protects weekly income drops caused by real delivery disruptions.'
                    : summary.claimReady
                        ? 'You can claim the last completed week, and this payment will still cover the upcoming week.'
                        : summary.policyStatus == 'ACTIVE'
                            ? 'Your current policy remains active, and this payment secures the next upcoming week.'
                            : 'This policy protects weekly income drops caused by real delivery disruptions.';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1F291B), Color(0xFF161A16)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Premium Purchase Flow',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Income -> Risk -> Premium',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;
                                final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _MetricCard(
                                        label: 'Baseline Income',
                                        value: 'Rs ${baseline.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _MetricCard(
                                        label: 'Weekly Income',
                                        value: 'Rs ${weeklyIncome.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;
                                final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _MetricCard(
                                        label: 'Risk Score',
                                        value: riskScore.toStringAsFixed(2),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _MetricCard(
                                        label: 'Premium',
                                        value: 'Rs ${weeklyPremium.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (summary != null) ...[
                              const SizedBox(height: 14),
                              _MetricCard(
                                label: 'Policy Status',
                                value: '${summary.policyStatus} | ${summary.claimMessage}',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(
                              0.08 + (_controller.value * 0.08),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            helperText,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPaying ? null : () => _pay(premiumData),
                          child: Text(
                            _isPaying
                                ? 'Processing...'
                                : 'Pay Premium For Upcoming Week',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.toString(),
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
