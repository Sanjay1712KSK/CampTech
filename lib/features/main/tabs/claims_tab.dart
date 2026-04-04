import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/demo/persona_story.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class ClaimsTab extends ConsumerStatefulWidget {
  const ClaimsTab({super.key});

  @override
  ConsumerState<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends ConsumerState<ClaimsTab> {
  bool _isSubmitting = false;

  Future<void> _submitClaim(int userId, double lat, double lon) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(claimProvider.notifier).submitClaim(
            userId: userId,
            lat: lat,
            lon: lon,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim processed successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final claimState = ref.watch(claimProvider);
    final location = ref.watch(locationProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayIncomeProvider);
            ref.invalidate(baselineIncomeProvider);
            ref.invalidate(riskProvider);
            ref.read(claimProvider.notifier).reset();
            setState(() {});
          },
          child: FutureBuilder<InsuranceSummaryModel>(
            future: ApiService.getInsuranceSummary(user.userId),
            builder: (context, snapshot) {
              final persona = resolvePersonaStory(user);
              final summary = snapshot.data;
              final claim = claimState.asData?.value;
              final canClaim = summary?.claimReady ?? false;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  const _Header(
                    title: 'Claims',
                    subtitle: 'Track your claim result, fraud checks, payout, and trust signals in one place.',
                  ),
                  const SizedBox(height: 18),
                  _PersonaBanner(
                    story: persona.claims,
                    accentColor: persona.accentColor,
                  ),
                  const SizedBox(height: 18),
                  _StatusCard(
                    status: (claim?['claim_status'] as String?) ?? (summary?.latestClaimStatus ?? 'No claim yet'),
                    reason: (claim?['reason'] as String?) ?? (summary?.claimMessage ?? 'Your latest claim result will appear here.'),
                  ),
                  const SizedBox(height: 18),
                  _ValueCard(
                    loss: ((claim?['loss'] as num?)?.toDouble() ?? 0.0),
                    payout: ((claim?['payout'] as num?)?.toDouble() ?? (summary?.lastPayout ?? 0.0)),
                  ),
                  const SizedBox(height: 18),
                  _FraudCard(
                    fraudScore: ((claim?['fraud_score'] as num?)?.toDouble() ?? 0.0),
                    status: (claim?['claim_status'] as String?) ?? 'PENDING',
                  ),
                  const SizedBox(height: 18),
                  _FlowCard(
                    claim: claim,
                    hasPolicy: (summary?.policyStatus ?? '') == 'ACTIVE' || (summary?.claimReady ?? false),
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    title: 'Blockchain record',
                    subtitle: 'Recorded securely on blockchain',
                    child: Text(
                      (claim?['payout_blockchain_txn_id'] as String?) ??
                          (claim?['blockchain_txn_id'] as String?) ??
                          'A blockchain record will appear here after a claim or payout is processed.',
                      style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    title: 'Claim action',
                    subtitle: 'Use the live backend engine to process your latest disruption claim.',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || !canClaim
                            ? null
                            : () => _submitClaim(user.userId, location.lat, location.lon),
                        child: Text(
                          _isSubmitting
                              ? 'Processing claim...'
                              : canClaim
                                  ? 'Check Claim & Payout'
                                  : (summary?.claimMessage ?? 'Claim unavailable'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
      ],
    );
  }
}

class _PersonaBanner extends StatelessWidget {
  final PersonaTabStory story;
  final Color accentColor;

  const _PersonaBanner({
    required this.story,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.title,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            story.summary,
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            story.focus,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final String reason;

  const _StatusCard({
    required this.status,
    required this.reason,
  });

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppTheme.successColor;
      case 'REJECTED':
        return AppTheme.errorColor;
      case 'FLAGGED':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              reason,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final double loss;
  final double payout;

  const _ValueCard({
    required this.loss,
    required this.payout,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(child: _Metric(label: 'Loss', value: 'Rs ${loss.toStringAsFixed(0)}')),
            const SizedBox(width: 12),
            Expanded(child: _Metric(label: 'Payout', value: 'Rs ${payout.toStringAsFixed(0)}')),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _FraudCard extends StatelessWidget {
  final double fraudScore;
  final String status;

  const _FraudCard({
    required this.fraudScore,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final label = status.toUpperCase() == 'APPROVED'
        ? 'Low fraud concern'
        : status.toUpperCase() == 'FLAGGED'
            ? 'Needs review'
            : status.toUpperCase() == 'REJECTED'
                ? 'High fraud concern'
                : 'Waiting for claim review';
    return _Section(
      title: 'Fraud check',
      subtitle: 'Fraud score and ML review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fraudScore.toStringAsFixed(2),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final Map<String, dynamic>? claim;
  final bool hasPolicy;

  const _FlowCard({
    required this.claim,
    required this.hasPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final approved = (claim?['claim_status'] as String? ?? '').toUpperCase() == 'APPROVED';
    return _Section(
      title: 'Process flow',
      subtitle: 'Follow how the system reached its decision.',
      child: Column(
        children: [
          _StepTile(label: 'Disruption detected', done: hasPolicy),
          _StepTile(label: 'Income verified', done: claim != null),
          _StepTile(label: 'Fraud check', done: claim?['fraud_score'] != null),
          _StepTile(label: 'Payout processed', done: approved),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String label;
  final bool done;

  const _StepTile({
    required this.label,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? AppTheme.successColor : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, height: 1.45)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
