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

  Future<Map<String, dynamic>> _loadAutoClaim(int userId, double lat, double lon) async {
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
                  message: snapshot.error.toString().replaceFirst('Exception: ', ''),
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
    final payoutStatus = _readString(payout['status'], fallback: _readString(payout['payout_status']));
    final claimStatus = _readString(claim['status'], fallback: 'PROCESSING');
    final claimTriggered = claim['claim_triggered'] == true;
    final coverageActive = status['coverage_active'] == true;
    final premiumEligible = premium['eligible'] == true;
    final earningsToday =
        _readDouble(gigContext['earnings_today'], fallback: _readDouble(gigContext['actual_income'])) ?? 0.0;
    final normalDeliveries = _readDouble(delivery['normal_deliveries_per_hour']) ?? 0.0;
    final currentDeliveries = _readDouble(delivery['estimated_current']) ?? 0.0;
    final dropRatio = _readDouble(delivery['drop_ratio']);
    final dropLabel = _readString(
      delivery['drop_percentage'],
      fallback: _readString(delivery['drop'], fallback: _percent(dropRatio)),
    );
    final confidence = _readString(claim['confidence'], fallback: 'LOW');
    final payoutAmount =
        _readDouble(payout['amount_paid'], fallback: _readDouble(payout['amount'])) ?? 0.0;
    final payoutMessage = _readString(
      payout['message'],
      fallback: payoutAmount > 0 ? 'Payout successfully credited' : 'No payout has been credited yet.',
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
        _readDouble(riskDetails['risk_score'], fallback: _readDouble(risk['risk_score'])) ?? 0.0;
    final lastUpdated = _formatDateTime(
      _readString(riskDetails['last_updated'], fallback: _readString(environment['last_updated'])),
    );
    final triggerSummary =
        triggers.isEmpty ? 'No major triggers are active right now.' : triggers.map(_prettifyTrigger).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        _HeroCard(
          name: _displayName(userPayload, user),
          earningsToday: earningsToday,
          coverageActive: coverageActive,
          city: currentCity,
          weatherText: '${_readDouble(weather['rainfall'])?.toStringAsFixed(1) ?? '0.0'} mm rain',
          aqiText: '${_readInt(aqi['aqi']) ?? 0}',
          trafficText: _readString(traffic['traffic_level'], fallback: 'Unknown'),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'What Is Happening',
          subtitle: 'Live disruption signals translated into worker-friendly risk.',
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
          subtitle: 'The system checks disruption and loss automatically. No manual claim filing is needed.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    icon: claimTriggered ? Icons.flash_on_rounded : Icons.pause_circle_outline_rounded,
                    label: 'Claim triggered',
                    value: claimTriggered ? 'Yes' : 'No',
                    tone: claimTriggered ? AppTheme.successColor : AppTheme.textSecondary,
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
                  fallback: 'The claim engine is watching for trigger-driven loss automatically.',
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
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
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
                      style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Payout status', value: payoutStatus),
              _InfoRow(
                label: 'Transaction ID',
                value: _readString(payout['transaction_id'], fallback: 'Pending'),
              ),
              _InfoRow(
                label: 'Processed at',
                value: _formatDateTime(
                  _readString(payout['processed_at'], fallback: _readString(payout['time'])),
                ),
              ),
            ],
          ),
        ),
