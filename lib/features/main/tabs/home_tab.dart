import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:intl/intl.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  late Future<_WorkerDashboardBundle> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_WorkerDashboardBundle> _loadDashboard() async {
    final user = ref.read(userProvider);
    final location = ref.read(locationProvider);
    if (user == null) {
      throw Exception('User not logged in');
    }

    final results = await Future.wait<Object?>([
      ApiService.getWorkerDashboard(user.userId, location.lat, location.lon),
      ApiService.getRiskDetails(user.userId, location.lat, location.lon),
      ApiService.getPremiumDetails(user.userId, location.lat, location.lon),
      _loadAutoClaim(user.userId, location.lat, location.lon),
      ApiService.getUiTransactionHistory(user.userId),
    ]);

    return _WorkerDashboardBundle(
      dashboard: results[0] as Map<String, dynamic>,
      riskDetails: results[1] as Map<String, dynamic>,
      premiumDetails: results[2] as Map<String, dynamic>,
      claim: results[3] as Map<String, dynamic>,
      transactions: results[4] as List<Map<String, dynamic>>,
    );
  }

  Future<Map<String, dynamic>> _loadAutoClaim(
    int userId,
    double lat,
    double lon,
  ) async {
    try {
      return await ApiService.autoProcessClaim(userId, lat, lon);
    } catch (error) {
      return {
        'claim_triggered': false,
        'status': 'UNAVAILABLE',
        'loss': 0.0,
        'confidence': 'LOW',
        'explanation': error.toString().replaceFirst('Exception: ', ''),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(locationProvider);
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final location = ref.watch(locationProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: AppTheme.primaryColor,
          onRefresh: _refresh,
          child: FutureBuilder<_WorkerDashboardBundle>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingState();
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: _refresh,
                );
              }
              final bundle = snapshot.data;
              if (bundle == null) {
                return _ErrorState(
                  message: 'Dashboard data is unavailable right now.',
                  onRetry: _refresh,
                );
              }
              return _DashboardView(
                user: user,
                location: location,
                bundle: bundle,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkerDashboardBundle {
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> riskDetails;
  final Map<String, dynamic> premiumDetails;
  final Map<String, dynamic> claim;
  final List<Map<String, dynamic>> transactions;

  const _WorkerDashboardBundle({
    required this.dashboard,
    required this.riskDetails,
    required this.premiumDetails,
    required this.claim,
    required this.transactions,
  });
}

class _DashboardView extends StatelessWidget {
  final UserState user;
  final LocationState location;
  final _WorkerDashboardBundle bundle;

  const _DashboardView({
    required this.user,
    required this.location,
    required this.bundle,
  });

  @override
  Widget build(BuildContext context) {
    final dashboard = bundle.dashboard;
    final environment = _asMap(dashboard['environment']);
    final risk = _asMap(dashboard['risk']);
    final riskDetails = bundle.riskDetails;
    final premium = bundle.premiumDetails;
    final claim = bundle.claim;
    final payout = _resolvePayout(dashboard, claim);
    final status = _asMap(dashboard['status']);
    final policy = _asMap(dashboard['policy']);
    final userPayload = _asMap(dashboard['user']);
    final gigContext = _asMap(risk['gig_context']);
    final delivery = _asMap(risk['delivery_efficiency']);
    final currentCity = _displayCity(environment, status, location.city);
    final triggers = _asStringList(riskDetails['triggers']);
    final riskExplanation = _joinExplanation(riskDetails['explanation']);
    final weather = _asMap(environment['weather']);
    final aqi = _asMap(environment['aqi']);
    final traffic = _asMap(environment['traffic']);
    final payoutStatus = _readString(
      payout['status'],
      fallback: _readString(payout['payout_status']),
    );
    final claimStatus = _readString(claim['status'], fallback: 'PROCESSING');
    final claimTriggered = claim['claim_triggered'] == true;
    final coverageActive = status['coverage_active'] == true;
    final premiumEligible = premium['eligible'] == true;
    final earningsToday =
        _readDouble(
          gigContext['earnings_today'],
          fallback: _readDouble(gigContext['actual_income']),
        ) ??
        0.0;
    final normalDeliveries =
        _readDouble(delivery['normal_deliveries_per_hour']) ?? 0.0;
    final currentDeliveries = _readDouble(delivery['estimated_current']) ?? 0.0;
    final dropRatio = _readDouble(delivery['drop_ratio']);
    final dropLabel = _readString(
      delivery['drop_percentage'],
      fallback: _readString(delivery['drop'], fallback: _percent(dropRatio)),
    );
    final confidence = _readString(claim['confidence'], fallback: 'LOW');
    final payoutAmount =
        _readDouble(
          payout['amount_paid'],
          fallback: _readDouble(payout['amount']),
        ) ??
        0.0;
    final payoutMessage = _readString(
      payout['message'],
      fallback: payoutAmount > 0
          ? 'Payout successfully credited'
          : 'No payout has been credited yet.',
    );
    final policyStatus = _readString(
      policy['status'],
      fallback: coverageActive ? 'ACTIVE' : 'INACTIVE',
    );
    final premiumAmount = _readDouble(premium['premium']) ?? 0.0;
    final coverageAmount = _readDouble(premium['coverage']) ?? 0.0;
    final riskLevel = _readString(
      riskDetails['risk_level'],
      fallback: _readString(risk['risk_level'], fallback: 'LOW'),
    );
    final riskScore =
        _readDouble(
          riskDetails['risk_score'],
          fallback: _readDouble(risk['risk_score']),
        ) ??
        0.0;
    final lastUpdated = _formatDateTime(
      _readString(
        riskDetails['last_updated'],
        fallback: _readString(environment['last_updated']),
      ),
    );
    final triggerSummary = triggers.isEmpty
        ? 'No major triggers are active right now.'
        : triggers.map(_prettifyTrigger).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _HeroCard(
          name: _displayName(userPayload, user),
          earningsToday: earningsToday,
          coverageActive: coverageActive,
          city: currentCity,
          weatherText:
              '${_readDouble(weather['rainfall'])?.toStringAsFixed(1) ?? '0.0'} mm rain',
          aqiText: '${_readInt(aqi['aqi']) ?? 0}',
          trafficText: _readString(
            traffic['traffic_level'],
            fallback: 'Unknown',
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'What Is Happening',
          subtitle:
              'Live disruption signals translated into worker-friendly risk.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Risk level',
                    value: riskLevel,
                    tone: _riskTone(riskLevel),
                  ),
                  _MetricTile(
                    icon: Icons.insights_rounded,
                    label: 'Risk score',
                    value: riskScore.toStringAsFixed(2),
                  ),
                  _MetricTile(
                    icon: Icons.schedule_rounded,
                    label: 'Last updated',
                    value: lastUpdated,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ExplainBar(
                icon: Icons.auto_awesome_rounded,
                text: riskExplanation.isEmpty
                    ? 'Risk is being recalculated from weather, air quality, and traffic conditions.'
                    : riskExplanation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Delivery Impact',
          subtitle: 'How current conditions are affecting earning capacity.',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ImpactStat(
                      label: 'Normal deliveries/hr',
                      value: normalDeliveries.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImpactStat(
                      label: 'Current deliveries/hr',
                      value: currentDeliveries.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImpactStat(
                      label: 'Drop',
                      value: dropLabel,
                      highlight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ExplainBar(
                icon: Icons.delivery_dining_rounded,
                text: dropLabel == '0%'
                    ? 'Your delivery pattern is close to normal right now.'
                    : 'Deliveries are down because today\'s live conditions are reducing route efficiency and safe working time.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Auto Claim Status',
          subtitle:
              'The system checks disruption and loss automatically. No manual claim filing is needed.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    icon: claimTriggered
                        ? Icons.flash_on_rounded
                        : Icons.pause_circle_outline_rounded,
                    label: 'Claim triggered',
                    value: claimTriggered ? 'Yes' : 'No',
                    tone: claimTriggered
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  ),
                  _MetricTile(
                    icon: Icons.policy_rounded,
                    label: 'Status',
                    value: claimStatus,
                    tone: _claimTone(claimStatus),
                  ),
                  _MetricTile(
                    icon: Icons.verified_user_rounded,
                    label: 'Confidence',
                    value: confidence,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ExplainBar(
                icon: Icons.lightbulb_outline_rounded,
                text: _readString(
                  claim['explanation'],
                  fallback:
                      'The claim engine is watching for trigger-driven loss automatically.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Instant Payout',
          subtitle: 'This is the money outcome the worker cares about most.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payoutAmount > 0
                          ? 'Rs ${payoutAmount.toStringAsFixed(0)} credited ${_readString(payout['processing_time'], fallback: 'instantly')}'
                          : 'No payout credited yet',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      payoutMessage,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Payout status', value: payoutStatus),
              _InfoRow(
                label: 'Transaction ID',
                value: _readString(
                  payout['transaction_id'],
                  fallback: 'Pending',
                ),
              ),
              _InfoRow(
                label: 'Processed at',
                value: _formatDateTime(
                  _readString(
                    payout['processed_at'],
                    fallback: _readString(payout['time']),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Why This Happened',
          subtitle:
              'A simple explainer that shows the full automated decision flow.',
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title: const Text(
                'Environment -> Risk -> Claim -> Fraud -> Payout',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Open to see how the system reached its decision.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              children: [
                _FlowStep(
                  icon: Icons.cloud_outlined,
                  title: 'Environment',
                  description:
                      'Weather, AQI, and traffic were read live from the backend for $currentCity.',
                ),
                _FlowStep(
                  icon: Icons.query_stats_rounded,
                  title: 'Risk',
                  description: riskExplanation.isEmpty
                      ? 'Risk stayed at $riskLevel based on current disruption factors.'
                      : riskExplanation,
                ),
                _FlowStep(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Claim',
                  description: _readString(
                    claim['explanation'],
                    fallback:
                        'The zero-touch claim engine checked for trigger-based loss automatically.',
                  ),
                ),
                _FlowStep(
                  icon: Icons.shield_outlined,
                  title: 'Fraud',
                  description: _readString(
                    _asMap(claim['fraud'])['explanation'],
                    fallback:
                        'Fraud checks reviewed device, location, behavior, and context before payout.',
                  ),
                ),
                _FlowStep(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Payout',
                  description: payoutAmount > 0
                      ? 'Once the claim passed review, the payout service credited the worker automatically.'
                      : 'No payout was sent because the claim is not yet approved for credit.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Premium Details',
          subtitle: 'Live pricing linked directly to the same risk engine.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ImpactStat(
                      label: 'Weekly premium',
                      value: 'Rs ${premiumAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImpactStat(
                      label: 'Coverage amount',
                      value: 'Rs ${coverageAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImpactStat(
                      label: 'Eligibility',
                      value: premiumEligible ? 'Eligible' : 'Not eligible',
                      highlight: premiumEligible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(
                label: 'Reason',
                value: _readString(
                  premium['reason'],
                  fallback: premiumEligible
                      ? 'Eligible for premium quote'
                      : 'Quote unavailable',
                ),
              ),
              _InfoRow(
                label: 'Pricing explanation',
                value: _readString(
                  premium['explanation'],
                  fallback:
                      'Pricing follows live risk, trigger severity, and weekly income.',
                ),
              ),
              _InfoRow(label: 'Policy status', value: policyStatus),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Transaction History',
          subtitle: 'Recent premium payments and payout activity.',
          child: bundle.transactions.isEmpty
              ? const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  message:
                      'Premium payments and payouts will appear here as soon as the system records them.',
                )
              : Column(
                  children: bundle.transactions
                      .map(
                        (transaction) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionRow(transaction: transaction),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'System Summary',
          subtitle:
              'A quick worker-facing summary of what the platform is doing right now.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Coverage active',
                value: coverageActive ? 'Yes' : 'No',
              ),
              _InfoRow(
                label: 'Auto payout enabled',
                value: status['auto_payout_enabled'] == true ? 'Yes' : 'No',
              ),
              _InfoRow(label: 'Active triggers', value: triggerSummary),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String name;
  final double earningsToday;
  final bool coverageActive;
  final String city;
  final String weatherText;
  final String aqiText;
  final String trafficText;

  const _HeroCard({
    required this.name,
    required this.earningsToday,
    required this.coverageActive,
    required this.city,
    required this.weatherText,
    required this.aqiText,
    required this.trafficText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF252B16), Color(0xFF13180F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Worker Dashboard',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: coverageActive
                            ? AppTheme.successColor.withOpacity(0.18)
                            : AppTheme.errorColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        coverageActive
                            ? 'Coverage Active'
                            : 'Coverage Inactive',
                        style: TextStyle(
                          color: coverageActive
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.assured_workload_rounded,
                color: AppTheme.primaryColor,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Earnings today',
                  value: 'Rs ${earningsToday.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(label: 'Location', value: city),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ContextPill(icon: Icons.umbrella_outlined, label: weatherText),
              _ContextPill(icon: Icons.air_rounded, label: 'AQI $aqiText'),
              _ContextPill(icon: Icons.traffic_rounded, label: trafficText),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

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
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContextPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
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
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone ?? AppTheme.primaryColor, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tone ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ImpactStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryColor.withOpacity(0.22)
              : Colors.white.withOpacity(0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppTheme.primaryColor : AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainBar extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExplainBar({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isLast;

  const _FlowStep({
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = _readString(transaction['type'], fallback: 'transaction');
    final amount = _readDouble(transaction['amount']) ?? 0.0;
    final timestamp = _formatDateTime(_readString(transaction['created_at']));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _readString(
                    transaction['remark'],
                    fallback: _titleCase(type),
                  ),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Rs ${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transaction ID: ${_readString(transaction['transaction_id'], fallback: '--')}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Time: $timestamp',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 180),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_rounded,
          size: 34,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(height: 14),
        const Text(
          'Dashboard unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () {
            onRetry();
          },
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entryValue) => MapEntry('$key', entryValue));
  }
  return const {};
}

String _displayName(Map<String, dynamic> userPayload, UserState user) {
  return _readString(
    userPayload['name'],
    fallback: _readString(userPayload['username'], fallback: user.userName),
  );
}

String _displayCity(
  Map<String, dynamic> environment,
  Map<String, dynamic> status,
  String fallbackCity,
) {
  final location = _asMap(status['location']);
  return _readString(
    environment['city'],
    fallback: _readString(
      environment['resolved_city'],
      fallback: _readString(location['active_city'], fallback: fallbackCity),
    ),
  );
}

Map<String, dynamic> _resolvePayout(
  Map<String, dynamic> dashboard,
  Map<String, dynamic> claim,
) {
  final claimPayout = _asMap(claim['payout']);
  if (claimPayout.isNotEmpty) {
    return claimPayout;
  }
  return _asMap(dashboard['payout']);
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => '$item')
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

String _joinExplanation(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .join(' ');
  }
  return _readString(value);
}

String _prettifyTrigger(String input) {
  return _titleCase(input.replaceAll('_', ' ').toLowerCase());
}

String _titleCase(String input) {
  return input
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _readString(Object? value, {String fallback = '--'}) {
  if (value == null) return fallback;
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

double? _readDouble(Object? value, {double? fallback}) {
  if (value is num) return value.toDouble();
  if (value is String)
    return double.tryParse(value.replaceAll('%', '').trim()) ?? fallback;
  return fallback;
}

int? _readInt(Object? value, {int? fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return fallback;
}

String _percent(double? value) {
  if (value == null) return '0%';
  return '${(value * 100).round()}%';
}

Color _riskTone(String level) {
  switch (level.toUpperCase()) {
    case 'HIGH':
      return AppTheme.errorColor;
    case 'MEDIUM':
      return AppTheme.warningColor;
    default:
      return AppTheme.successColor;
  }
}

Color _claimTone(String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return AppTheme.successColor;
    case 'UNDER_REVIEW':
    case 'PROCESSING':
    case 'FLAGGED':
      return AppTheme.warningColor;
    case 'REJECTED':
      return AppTheme.errorColor;
    default:
      return AppTheme.textPrimary;
  }
}

String _formatDateTime(String value) {
  if (value == '--') return value;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('d MMM, h:mm a').format(parsed.toLocal());
}
