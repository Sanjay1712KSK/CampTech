import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:local_auth/local_auth.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isPaying = false;
  bool _isClaiming = false;

  Future<void> _refresh() async {
    ref.invalidate(riskProvider);
    ref.invalidate(environmentProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(premiumProvider);
    ref.read(claimProvider.notifier).reset();
    setState(() {});
  }

  Future<void> _payPremium({
    required int userId,
    required double amount,
  }) async {
    if (_isPaying || amount <= 0) return;
    setState(() => _isPaying = true);
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Confirm premium payment',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!didAuthenticate) {
        throw Exception('Biometric verification was cancelled');
      }
      await ApiService.payPremium(userId, amount);
      ref.invalidate(premiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium paid successfully')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _processClaim({
    required int userId,
    required double lat,
    required double lon,
  }) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      await ref.read(claimProvider.notifier).submitClaim(
            userId: userId,
            lat: lat,
            lon: lon,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim processed successfully')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final riskAsync = ref.watch(riskProvider);
    final environmentAsync = ref.watch(environmentProvider);
    final premiumAsync = ref.watch(premiumProvider);
    final claimState = ref.watch(claimProvider);
    final location = ref.watch(locationProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<InsuranceSummaryModel>(
            future: ApiService.getInsuranceSummary(user.userId),
            builder: (context, summarySnapshot) {
              return FutureBuilder<BankTransactionHistoryModel>(
                future: ApiService.getTransactionHistory(user.userId),
                builder: (context, transactionSnapshot) {
                  return riskAsync.when(
                    data: (riskData) => environmentAsync.when(
                      data: (environment) => premiumAsync.when(
                        data: (premium) {
                          final summary = summarySnapshot.data;
                          final transactions = transactionSnapshot.data;
                          final claim = claimState.asData?.value;
                          return _DashboardContent(
                            user: user,
                            location: location,
                            riskData: riskData,
                            environment: environment,
                            premium: premium,
                            summary: summary,
                            transactions: transactions,
                            claim: claim,
                            isPaying: _isPaying,
                            isClaiming: _isClaiming,
                            onPay: () => _payPremium(
                              userId: user.userId,
                              amount: ((premium['weekly_premium'] as num?)?.toDouble() ?? 0.0),
                            ),
                            onClaim: () => _processClaim(
                              userId: user.userId,
                              lat: location.lat,
                              lon: location.lon,
                            ),
                          );
                        },
                        loading: () => const _LoadingView(),
                        error: (error, _) => _ErrorView(message: error.toString()),
                      ),
                      loading: () => const _LoadingView(),
                      error: (error, _) => _ErrorView(message: error.toString()),
                    ),
                    loading: () => const _LoadingView(),
                    error: (error, _) => _ErrorView(message: error.toString()),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final UserState user;
  final LocationState location;
  final Map<String, dynamic> riskData;
  final EnvironmentModel environment;
  final Map<String, dynamic> premium;
  final InsuranceSummaryModel? summary;
  final BankTransactionHistoryModel? transactions;
  final Map<String, dynamic>? claim;
  final bool isPaying;
  final bool isClaiming;
  final VoidCallback onPay;
  final VoidCallback onClaim;

  const _DashboardContent({
    required this.user,
    required this.location,
    required this.riskData,
    required this.environment,
    required this.premium,
    required this.summary,
    required this.transactions,
    required this.claim,
    required this.isPaying,
    required this.isClaiming,
    required this.onPay,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final triggers = (risk['active_triggers'] as List? ?? const []).map((item) => '$item').toList();
    final delivery = (risk['delivery_efficiency'] as Map<String, dynamic>?) ?? const {};
    final expectedLoss = risk['expected_income_loss']?.toString() ?? '0%';
    final riskScore = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0);
    final drop = delivery['drop']?.toString() ?? delivery['drop_percentage']?.toString() ?? '0%';
    final weeklyPremium = ((premium['weekly_premium'] as num?)?.toDouble() ?? 0.0);
    final coverage = ((premium['coverage'] as num?)?.toDouble() ?? 0.0);
    final weeklyIncome = ((premium['weekly_income'] as num?)?.toDouble() ?? 0.0);
    final policyProtected = (summary?.policyStatus ?? '').toUpperCase() == 'ACTIVE';
    final premiumPaid = (summary?.totalPaid ?? 0.0) > 0;
    final eligibleForInsurance = riskScore >= 0.05 && weeklyPremium > 0;
    final personaKey = _personaKeyForUser(user);
    final persona = _personaFor(personaKey);
    final personaStory = _personaStoryFor(personaKey);
    final claimStatus = (claim?['claim_status'] as String?) ?? (summary?.latestClaimStatus ?? 'NOT STARTED');
    final fraudScore = ((claim?['fraud_score'] as num?)?.toDouble() ?? 0.0);
    final payout = ((claim?['payout'] as num?)?.toDouble() ?? (summary?.lastPayout ?? 0.0));
    final loss = ((claim?['loss'] as num?)?.toDouble() ?? 0.0);
    final blockchainId = (claim?['payout_blockchain_txn_id'] as String?) ??
        (claim?['blockchain_txn_id'] as String?) ??
        'Available after a policy, claim, or payout write';
    final accent = _personaAccent(personaKey);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        _ProfileCard(
          name: user.userName,
          persona: persona.title,
          protectedStatus: policyProtected ? 'Protected' : 'Not Protected',
          premiumStatus: premiumPaid ? 'Paid' : 'Not Paid',
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Persona story',
          subtitle: persona.summary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Scenario', value: personaStory.scenario),
              _InfoRow(label: 'System behavior', value: personaStory.behavior),
              _InfoRow(label: 'Expected outcome', value: personaStory.outcome),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Live environment',
          subtitle: 'What the system is seeing around you right now.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: 'City', value: location.city),
              _MetricChip(label: 'Time', value: '${environment.context.hour}:00'),
              _MetricChip(label: 'Weather 🌧', value: '${environment.weather.rainfall.toStringAsFixed(1)} mm'),
              _MetricChip(label: 'AQI 🌫', value: '${environment.aqi.aqi}'),
              _MetricChip(label: 'Traffic 🚦', value: environment.traffic.trafficLevel),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Risk engine',
          subtitle: 'This risk is calculated using weather, traffic, and air quality.',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(label: 'Risk score', value: riskScore.toStringAsFixed(2)),
                  _MetricChip(label: 'Income loss', value: expectedLoss),
                  _MetricChip(label: 'Efficiency drop', value: drop),
                  _MetricChip(label: 'Last updated', value: 'Now'),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Risk level: $level',
                  style: TextStyle(
                    color: _riskColor(level),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (triggers.isNotEmpty)
          _SectionCard(
            title: 'Parametric triggers',
            subtitle: 'These triggers explain why your risk is changing.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: triggers.map((item) => _TriggerPill(label: _triggerTitle(item))).toList(),
            ),
          ),
        if (triggers.isNotEmpty) const SizedBox(height: 18),
        _PremiumCard(
          weeklyPremium: weeklyPremium,
          coverage: coverage,
          weeklyIncome: weeklyIncome,
          riskScore: riskScore,
          triggers: triggers,
          eligible: eligibleForInsurance,
          isPaying: isPaying,
          onPay: onPay,
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Claim and payout',
          subtitle: 'See what happened with your latest claim lifecycle.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Claim status', value: claimStatus),
              _InfoRow(label: 'Loss', value: '₹ ${loss.toStringAsFixed(0)}'),
              _InfoRow(label: 'Payout', value: '₹ ${payout.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isClaiming ? null : onClaim,
                  child: Text(isClaiming ? 'Processing claim...' : 'Run Claim Check'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Fraud and auto payout',
          subtitle: 'Simple trust signals from the ML layer.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: '🤖 Fraud score', value: fraudScore.toStringAsFixed(2)),
              _InfoRow(
                label: 'Auto payout',
                value: premiumPaid && (summary?.bankLinked ?? false) ? 'Enabled' : 'Not enabled',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Bank transaction history',
          subtitle: 'Premiums and payouts linked to your account.',
          child: (transactions?.transactions.isNotEmpty ?? false)
              ? Column(
                  children: transactions!.transactions
                      .map((txn) => _TransactionTile(txn: txn))
                      .toList(),
                )
              : const Text(
                  'No bank transactions yet.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Blockchain trust',
          subtitle: '🔒 This record is securely stored',
          child: Text(
            blockchainId,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'System flow',
          subtitle: 'See how the full insurance lifecycle connects.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FlowPill('Environment'),
              _FlowPill('Risk'),
              _FlowPill('Premium'),
              _FlowPill('Claim 🤖'),
              _FlowPill('Payout 🔒'),
            ],
          ),
        ),
      ],
    );
  }

  _PersonaMeta _personaFor(String username) {
    switch (username.trim().toLowerCase()) {
      case 'good_actor':
        return const _PersonaMeta(
          title: 'Trusted Professional',
          summary: 'Consistent worker, real disruption, strongest example of the honest payout story.',
        );
      case 'bad_actor':
        return const _PersonaMeta(
          title: 'System Gamer',
          summary: 'Irregular worker profile designed to show anomaly detection and claim rejection.',
        );
      case 'edge_case':
        return const _PersonaMeta(
          title: 'Uncertain Case',
          summary: 'Borderline signals that help explain flagged or review-needed outcomes.',
        );
      case 'low_risk':
        return const _PersonaMeta(
          title: 'Normal Day',
          summary: 'Stable conditions, lower risk, and lower premium story.',
        );
      default:
        return const _PersonaMeta(
          title: 'Delivery Partner',
          summary: 'Live gig-insurance dashboard connected to risk, premium, claim, and payout engines.',
        );
    }
  }

  _PersonaStory _personaStoryFor(String username) {
    switch (username.trim().toLowerCase()) {
      case 'good_actor':
        return const _PersonaStory(
          scenario: 'Heavy rain and traffic are hurting a disciplined worker during a real disruption.',
          behavior: 'Risk should rise, premium logic stays valid, and fraud concern stays low.',
          outcome: 'This is the best persona to demonstrate a fair auto-payout path once policy timing is valid.',
        );
      case 'bad_actor':
        return const _PersonaStory(
          scenario: 'Normal weather and normal traffic, but the user tries to show high loss.',
          behavior: 'Risk should stay low and fraud logic should react to the mismatch.',
          outcome: 'Best persona to explain why suspicious claims are rejected.',
        );
      case 'edge_case':
        return const _PersonaStory(
          scenario: 'Mild rain and moderate traffic create an ambiguous real-world case.',
          behavior: 'Risk should stay medium and the claim may be borderline.',
          outcome: 'Best persona to explain a flagged or review-needed outcome.',
        );
      case 'low_risk':
        return const _PersonaStory(
          scenario: 'Normal day with stable work conditions and little disruption.',
          behavior: 'Risk should stay low and pricing should remain lighter.',
          outcome: 'Best persona to explain fair pricing under calm conditions.',
        );
      default:
        return const _PersonaStory(
          scenario: 'Live conditions are being monitored.',
          behavior: 'The system connects environment, risk, premium, and claims.',
          outcome: 'Use this dashboard to explain the full insurance lifecycle.',
        );
    }
  }

  String _triggerTitle(String raw) {
    switch (raw.toUpperCase()) {
      case 'RAIN_TRIGGER':
        return 'Rain Trigger';
      case 'TRAFFIC_TRIGGER':
        return 'Traffic Trigger';
      case 'AQI_TRIGGER':
        return 'AQI Trigger';
      case 'HEAT_TRIGGER':
        return 'Heat Trigger';
      case 'COMBINED_TRIGGER':
        return 'Combined Trigger';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'HIGH':
        return AppTheme.errorColor;
      case 'MEDIUM':
        return AppTheme.warningColor;
      default:
        return AppTheme.successColor;
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String persona;
  final String protectedStatus;
  final String premiumStatus;

  const _ProfileCard({
    required this.name,
    required this.persona,
    required this.protectedStatus,
    required this.premiumStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF273629), Color(0xFF162018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$persona • Delivery Partner',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusPill(label: protectedStatus),
              _StatusPill(label: 'Premium: $premiumStatus'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
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
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TriggerPill extends StatelessWidget {
  final String label;

  const _TriggerPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final double weeklyPremium;
  final double coverage;
  final double weeklyIncome;
  final double riskScore;
  final List<String> triggers;
  final bool eligible;
  final bool isPaying;
  final VoidCallback onPay;

  const _PremiumCard({
    required this.weeklyPremium,
    required this.coverage,
    required this.weeklyIncome,
    required this.riskScore,
    required this.triggers,
    required this.eligible,
    required this.isPaying,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: const Text(
            'Premium',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Premium and coverage linked to live risk',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          children: [
            if (!eligible)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Insurance not available due to low risk conditions',
                  style: TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricChip(label: 'Weekly premium', value: '₹ ${weeklyPremium.toStringAsFixed(0)}'),
                _MetricChip(label: 'Coverage', value: '₹ ${coverage.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Breakdown',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _InfoRow(label: 'Weekly income used', value: '₹ ${weeklyIncome.toStringAsFixed(0)}'),
            _InfoRow(label: 'Risk score used', value: riskScore.toStringAsFixed(2)),
            _InfoRow(label: 'Trigger adjustments', value: triggers.isEmpty ? 'None' : triggers.join(', ')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: eligible && !isPaying ? onPay : null,
                child: Text(isPaying ? 'Authenticating...' : 'Pay Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
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

class _TransactionTile extends StatelessWidget {
  final BankTransactionItemModel txn;

  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final time = txn.createdAt;
    final timeLabel = time == null
        ? '--'
        : '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txn.remark ?? txn.transactionType,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '₹ ${txn.amount.toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Transaction ID: ${txn.referenceId ?? txn.transactionId}', style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('Timestamp: $timeLabel', style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _FlowPill extends StatelessWidget {
  final String label;

  const _FlowPill(this.label);

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

class _PersonaMeta {
  final String title;
  final String summary;

  const _PersonaMeta({
    required this.title,
    required this.summary,
  });
}

class _PersonaStory {
  final String scenario;
  final String behavior;
  final String outcome;

  const _PersonaStory({
    required this.scenario,
    required this.behavior,
    required this.outcome,
  });
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
