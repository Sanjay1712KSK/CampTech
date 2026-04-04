import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/demo/persona_story.dart';
import 'package:guidewire_gig_ins/features/insurance/screens/link_bank_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class PolicyTab extends ConsumerStatefulWidget {
  const PolicyTab({super.key});

  @override
  ConsumerState<PolicyTab> createState() => _PolicyTabState();
}

class _PolicyTabState extends ConsumerState<PolicyTab> {
  bool _isPaying = false;

  Future<void> _payPremium(int userId, double amount) async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    try {
      await ApiService.payPremium(userId, amount);
      ref.invalidate(premiumProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly premium paid successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final premiumAsync = ref.watch(premiumProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(premiumProvider);
          },
          child: premiumAsync.when(
            data: (premium) => FutureBuilder<InsuranceSummaryModel>(
              future: ApiService.getInsuranceSummary(user.userId),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                return _InsuranceContent(
                  user: user,
                  premium: premium,
                  summary: summary,
                  onPay: () => _payPremium(
                    user.userId,
                    ((premium['weekly_premium'] as num?)?.toDouble() ?? 0.0),
                  ),
                  onLinkBank: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LinkBankScreen()),
                    );
                    if (mounted) setState(() {});
                  },
                  isPaying: _isPaying,
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _InsuranceError(message: error.toString()),
          ),
        ),
      ),
    );
  }
}

class _InsuranceContent extends StatelessWidget {
  final UserState user;
  final Map<String, dynamic> premium;
  final InsuranceSummaryModel? summary;
  final VoidCallback onPay;
  final VoidCallback onLinkBank;
  final bool isPaying;

  const _InsuranceContent({
    required this.user,
    required this.premium,
    required this.summary,
    required this.onPay,
    required this.onLinkBank,
    required this.isPaying,
  });

  @override
  Widget build(BuildContext context) {
    final persona = resolvePersonaStory(user);
    final risk = (premium['risk'] as Map<String, dynamic>?) ?? const {};
    final triggers = (risk['active_triggers'] as List? ?? const []).map((item) => '$item').toList();
    final weeklyPremium = (premium['weekly_premium'] as num?)?.toDouble() ?? 0.0;
    final coverage = (premium['coverage'] as num?)?.toDouble() ?? 0.0;
    final weeklyIncome = (premium['weekly_income'] as num?)?.toDouble() ?? 0.0;
    final riskScore = (risk['risk_score'] as num?)?.toDouble() ?? 0.0;
    final explanation = premium['explanation']?.toString() ?? 'Pricing is linked to your current risk and income.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const _Header(
          title: 'Insurance',
          subtitle: 'See what protection you get and how your price is calculated.',
        ),
        const SizedBox(height: 18),
        _PersonaBanner(
          title: persona.insurance.title,
          summary: persona.insurance.summary,
          focus: persona.insurance.focus,
          accentColor: persona.accentColor,
        ),
        const SizedBox(height: 18),
        _TopPremiumCard(
          weeklyPremium: weeklyPremium,
          coverage: coverage,
          policyStatus: summary?.policyStatus ?? 'NOT PURCHASED',
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'How premium is calculated',
          subtitle: 'We calculate your insurance price based on your average earnings, current risk level, and environmental disruptions.',
          child: Column(
            children: [
              _DataPoint(label: 'Risk score', value: riskScore.toStringAsFixed(2)),
              _DataPoint(label: 'Weekly income', value: 'Rs ${weeklyIncome.toStringAsFixed(0)}'),
              _DataPoint(label: 'Active triggers', value: triggers.isEmpty ? 'None right now' : triggers.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Adaptive pricing',
          subtitle: 'Adaptive pricing that learns from real conditions',
          child: Text(
            explanation,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Important to know',
          subtitle: 'Please read before paying for cover.',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet('Premium may change based on real-time conditions'),
              _Bullet('Coverage applies only during active policy period'),
              _Bullet('Claims are subject to verification'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Payment',
          subtitle: 'Use your linked bank account to activate the next 7-day policy.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DataPoint(
                label: 'Linked bank account',
                value: summary?.accountNumberMasked ?? 'Not linked yet',
              ),
              const SizedBox(height: 8),
              if (summary?.bankLinked != true)
                OutlinedButton(
                  onPressed: onLinkBank,
                  child: const Text('Link Bank Account'),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (summary?.bankLinked == true && !isPaying) ? onPay : null,
                  child: Text(isPaying ? 'Paying...' : 'Pay Weekly Premium'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'How it works',
          subtitle: 'This is how your coverage connects with the rest of the system.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FlowNode('Environment'),
              _FlowNode('Risk'),
              _FlowNode('Premium'),
              _FlowNode('Policy + Chain'),
              _FlowNode('Claim + ML'),
              _FlowNode('Payout + Chain'),
            ],
          ),
        ),
      ],
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
  final String title;
  final String summary;
  final String focus;
  final Color accentColor;

  const _PersonaBanner({
    required this.title,
    required this.summary,
    required this.focus,
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
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            focus,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _TopPremiumCard extends StatelessWidget {
  final double weeklyPremium;
  final double coverage;
  final String policyStatus;

  const _TopPremiumCard({
    required this.weeklyPremium,
    required this.coverage,
    required this.policyStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3C311A), Color(0xFF241E12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your cover',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  policyStatus,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _PremiumMetric(label: 'Weekly premium', value: 'Rs ${weeklyPremium.toStringAsFixed(0)}')),
              const SizedBox(width: 12),
              Expanded(child: _PremiumMetric(label: 'Coverage amount', value: 'Rs ${coverage.toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PremiumMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
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

class _DataPoint extends StatelessWidget {
  final String label;
  final String value;

  const _DataPoint({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '• $text',
        style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  final String label;

  const _FlowNode(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InsuranceError extends StatelessWidget {
  final String message;

  const _InsuranceError({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
