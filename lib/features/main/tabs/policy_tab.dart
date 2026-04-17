import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/insurance/screens/link_bank_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class PolicyTab extends ConsumerStatefulWidget {
  const PolicyTab({super.key});

  @override
  ConsumerState<PolicyTab> createState() => _PolicyTabState();
}

class _PolicyTabState extends ConsumerState<PolicyTab> {
  EnvironmentModel? _environment;
  Map<String, dynamic>? _risk;
  Map<String, dynamic>? _premium;
  InsuranceSummaryModel? _summary;
  List<Map<String, dynamic>> _transactions = const [];
  Map<String, dynamic>? _autoClaim;
  Map<String, dynamic>? _fraudCheck;
  Map<String, dynamic>? _manualPayout;

  bool _pageLoading = true;
  bool _ranAutoClaimThisSession = false;
  String? _pageError;

  final Map<String, bool> _actionLoading = <String, bool>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDashboard);
  }

  UserState? get _user => ref.read(userProvider);

  LocationState get _location => ref.read(locationProvider);

  void _setActionLoading(String key, bool value) {
    if (!mounted) return;
    setState(() {
      _actionLoading[key] = value;
    });
  }

  bool _isActionLoading(String key) => _actionLoading[key] ?? false;

  Future<void> _loadDashboard({bool rerunAutoClaim = false}) async {
    final user = _user;
    if (user == null) return;

    setState(() {
      _pageLoading = true;
      _pageError = null;
    });

    final lat = _location.lat;
    final lon = _location.lon;

    try {
      final results = await Future.wait<dynamic>([
        ApiService.getEnvironment(lat, lon, userId: user.userId),
        ApiService.getRiskData(user.userId, lat, lon),
        ApiService.getPremium(user.userId, lat, lon),
        ApiService.getInsuranceSummary(user.userId),
        ApiService.getUiTransactionHistory(user.userId),
      ]);

      Map<String, dynamic>? autoClaim = _autoClaim;
      if (!_ranAutoClaimThisSession || rerunAutoClaim) {
        try {
          autoClaim = await ApiService.autoProcessClaim(user.userId, lat, lon);
          _ranAutoClaimThisSession = true;
        } catch (_) {
          autoClaim = _autoClaim;
        }
      }

      if (!mounted) return;
      setState(() {
        _environment = results[0] as EnvironmentModel;
        _risk = results[1] as Map<String, dynamic>;
        _premium = results[2] as Map<String, dynamic>;
        _summary = results[3] as InsuranceSummaryModel;
        _transactions = (results[4] as List<Map<String, dynamic>>);
        _autoClaim = autoClaim;
        _pageLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _pageError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _runRiskEngine() async {
    final user = _user;
    if (user == null) return;
    _setActionLoading('risk', true);
    try {
      final environment = await ApiService.getEnvironment(
        _location.lat,
        _location.lon,
        userId: user.userId,
      );
      final risk = await ApiService.getRiskData(
        user.userId,
        _location.lat,
        _location.lon,
      );
      if (!mounted) return;
      setState(() {
        _environment = environment;
        _risk = risk;
      });
    } catch (error) {
      _showMessage(error);
    } finally {
      _setActionLoading('risk', false);
    }
  }

  Future<void> _runPremiumEngine() async {
    final user = _user;
    if (user == null) return;
    _setActionLoading('premium', true);
    try {
      final premium = await ApiService.getPremium(
        user.userId,
        _location.lat,
        _location.lon,
      );
      if (!mounted) return;
      setState(() {
        _premium = premium;
      });
    } catch (error) {
      _showMessage(error);
    } finally {
      _setActionLoading('premium', false);
    }
  }

  Future<void> _activatePolicy() async {
    final user = _user;
    final premiumAmount =
        ((_premium?['weekly_premium'] as num?)?.toDouble() ?? 0.0);
    if (user == null || premiumAmount <= 0) return;
    if (_summary?.bankLinked != true) {
      final linked =
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const LinkBankScreen()),
          ) ??
          false;
      if (linked) {
        await _loadDashboard();
      }
      if (_summary?.bankLinked != true) return;
    }

    _setActionLoading('policy', true);
    try {
      await ApiService.payPremium(user.userId, premiumAmount);
      await _loadDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Policy activated successfully')),
      );
    } catch (error) {
      _showMessage(error);
    } finally {
      _setActionLoading('policy', false);
    }
  }

  Future<void> _runFraudCheck() async {
    final user = _user;
    if (user == null) return;
    _setActionLoading('fraud', true);
    try {
      final result = await ApiService.processClaim(
        user.userId,
        _location.lat,
        _location.lon,
      );
      if (!mounted) return;
      setState(() {
        _fraudCheck = result;
      });
      await _refreshSummaryAndTransactions();
    } catch (error) {
      _showMessage(error);
    } finally {
      _setActionLoading('fraud', false);
    }
  }

  Future<void> _runPayout() async {
    final user = _user;
    if (user == null) return;
    final claimId =
        _autoClaim?['claim_id']?.toString() ??
        _fraudCheck?['claim_id']?.toString();
    final payoutMap = (_autoClaim?['payout'] as Map?)?.cast<String, dynamic>();
    final amount =
        (payoutMap?['amount_paid'] as num?)?.toDouble() ??
        ((_autoClaim?['loss'] as num?)?.toDouble() ?? 0.0) * 0.8;

    if (claimId == null || amount <= 0) {
      _showMessage('No approved payout is available to process right now.');
      return;
    }

    _setActionLoading('payout', true);
    try {
      final response = await ApiService.processPayout(
        userId: user.userId,
        amount: amount,
        claimId: claimId,
      );
      if (!mounted) return;
      setState(() {
        _manualPayout = response;
      });
      await _refreshSummaryAndTransactions();
    } catch (error) {
      _showMessage(error);
    } finally {
      _setActionLoading('payout', false);
    }
  }

  Future<void> _refreshSummaryAndTransactions() async {
    final user = _user;
    if (user == null) return;
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getInsuranceSummary(user.userId),
        ApiService.getUiTransactionHistory(user.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as InsuranceSummaryModel;
        _transactions = (results[1] as List<Map<String, dynamic>>);
      });
    } catch (_) {}
  }

  void _showMessage(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pageLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pageError != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDashboard,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.textSecondary,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  _pageError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final environment = _environment!;
    final risk = (_risk?['risk'] as Map<String, dynamic>?) ?? _risk ?? const {};
    final premium = _premium ?? const {};
    final premiumExplanation =
        premium['explanation']?.toString() ??
        'Premium pricing is generated from your live risk and income context.';
    final premiumAmount =
        ((premium['weekly_premium'] as num?)?.toDouble() ?? 0.0);
    final coverageAmount = ((premium['coverage'] as num?)?.toDouble() ?? 0.0);
    final locationEnabled = _summary?.locationEnabled ?? true;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboard(rerunAutoClaim: false),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              _HeroBanner(
                userName: user.userName,
                city: _location.city,
                policyStatus: _summary?.policyStatus ?? 'NOT_PURCHASED',
                pipeline: const [
                  'Environment',
                  'Risk',
                  'Premium',
                  'Policy',
                  'Claim',
                  'Fraud',
                  'Payout',
                ],
              ),
              const SizedBox(height: 18),
              _ProtectionSummaryCard(
                weeklyPremium: premiumAmount,
                coverage: coverageAmount,
                locationEnabled: locationEnabled,
                bankLinked: _summary?.bankLinked == true,
                isPaying: _isActionLoading('policy'),
                onPay: _activatePolicy,
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.radar_rounded,
                title: 'Risk Engine',
                accentColor: const Color(0xFF52D6FF),
                actionLabel: 'Calculate Risk',
                isLoading: _isActionLoading('risk'),
                onAction: _runRiskEngine,
                inputs: [
                  'Weather: ${environment.weather.rainfall.toStringAsFixed(1)} mm rain, ${environment.weather.temperature.toStringAsFixed(1)}°C',
                  'AQI: ${environment.aqi.aqi}',
                  'Traffic: ${environment.traffic.trafficLevel}',
                  'Location: ${_location.city}',
                ],
                whatHappens:
                    'The engine combines live environment signals with gig context to estimate disruption intensity and expected income loss.',
                output: _buildRiskOutput(risk),
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.auto_graph_rounded,
                title: 'Premium Engine',
                accentColor: const Color(0xFFB8FF5A),
                actionLabel: 'Generate Premium',
                isLoading: _isActionLoading('premium'),
                onAction: _runPremiumEngine,
                inputs: [
                  'Risk score: ${((premium['risk_score'] as num?)?.toDouble() ?? (risk['risk_score'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  'Weekly income: Rs ${((premium['weekly_income'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  'Triggers: ${_joinList(risk['active_triggers'] as List?)}',
                ],
                whatHappens:
                    'The premium engine reuses the live risk output directly, then computes weekly premium and coverage with an explainable breakdown.',
                output: _buildPremiumOutput(premium, premiumExplanation),
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.verified_user_rounded,
                title: 'Policy Engine',
                accentColor: const Color(0xFFFFD75A),
                actionLabel: (_summary?.bankLinked == true)
                    ? 'Pay & Activate Insurance'
                    : 'Link Bank First',
                isLoading: _isActionLoading('policy'),
                onAction: _activatePolicy,
                inputs: [
                  'Premium amount: Rs ${premiumAmount.toStringAsFixed(0)}',
                  'Bank linked: ${_summary?.bankLinked == true ? 'Yes' : 'No'}',
                  'Coverage amount: Rs ${coverageAmount.toStringAsFixed(0)}',
                ],
                whatHappens:
                    'When premium is paid, the backend creates a policy window, links premium context to it, and makes that week claim-aware.',
                output: _buildPolicyOutput(),
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.flash_auto_rounded,
                title: 'Claim Engine',
                accentColor: const Color(0xFFFF8A65),
                actionLabel: null,
                onAction: null,
                inputs: [
                  'Current earnings vs baseline',
                  'Live triggers from environment and risk',
                  'Policy status: ${_summary?.policyStatus ?? 'UNKNOWN'}',
                  'Eligibility: ${_summary?.claimReady == true ? 'Claim-ready' : 'Guarded until valid'}',
                ],
                whatHappens:
                    'This engine watches disruption and earnings patterns, then auto-generates a claim when trigger and loss conditions line up.',
                output: _buildClaimOutput(),
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.gpp_maybe_rounded,
                title: 'Fraud Engine',
                accentColor: const Color(0xFFFF6E9A),
                actionLabel: 'Run Fraud Check',
                isLoading: _isActionLoading('fraud'),
                onAction: _runFraudCheck,
                inputs: [
                  'Predicted vs actual loss',
                  'Device and location trust signals',
                  'Trigger consistency',
                  'User behavior profile',
                ],
                whatHappens:
                    'The fraud engine compares the claim story with live disruption evidence, location integrity, and historical behavior to decide approve, flag, or reject.',
                output: _buildFraudOutput(),
              ),
              const SizedBox(height: 16),
              _EngineCard(
                icon: Icons.payments_rounded,
                title: 'Payout Engine',
                accentColor: const Color(0xFF70F0AE),
                actionLabel: _payoutActionLabel(),
                isLoading: _isActionLoading('payout'),
                onAction: _canProcessPayout() ? _runPayout : null,
                inputs: [
                  'Approved claim status',
                  'Fraud decision',
                  'Linked bank account',
                  'Claim amount and coverage cap',
                ],
                whatHappens:
                    'The payout engine credits the approved amount, records the transaction, and updates payout history for worker and admin dashboards.',
                output: _buildPayoutOutput(),
              ),
              const SizedBox(height: 16),
              _ExplainerCard(
                environment: environment,
                risk: risk,
                premium: premium,
                autoClaim: _autoClaim,
                fraudCheck: _fraudCheck,
                manualPayout: _manualPayout,
              ),
              const SizedBox(height: 16),
              _TransactionsCard(transactions: _transactions),
            ],
          ),
        ),
      ),
    );
  }

  List<_OutputStat> _buildRiskOutput(Map<String, dynamic> risk) {
    return [
      _OutputStat(
        label: 'Risk level',
        value: (risk['risk_level'] as String? ?? 'LOW').toUpperCase(),
      ),
      _OutputStat(
        label: 'Risk score',
        value: ((risk['risk_score'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(2),
      ),
      _OutputStat(
        label: 'Triggers',
        value: _joinList(risk['active_triggers'] as List?),
      ),
      _OutputStat(
        label: 'Explanation',
        value: _joinList(risk['reasons'] as List?),
        emphasize: false,
      ),
    ];
  }

  List<_OutputStat> _buildPremiumOutput(
    Map<String, dynamic> premium,
    String explanation,
  ) {
    return [
      _OutputStat(
        label: 'Weekly premium',
        value:
            'Rs ${((premium['weekly_premium'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
      ),
      _OutputStat(
        label: 'Coverage',
        value:
            'Rs ${((premium['coverage'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
      ),
      _OutputStat(
        label: 'Eligible',
        value: (premium['eligible'] as bool?) == false ? 'No' : 'Yes',
      ),
      _OutputStat(
        label: 'Pricing explanation',
        value: explanation,
        emphasize: false,
      ),
    ];
  }

  List<_OutputStat> _buildPolicyOutput() {
    return [
      _OutputStat(
        label: 'Policy status',
        value: _summary?.policyStatus ?? 'NOT_PURCHASED',
      ),
      _OutputStat(
        label: 'Bank linked',
        value: _summary?.bankLinked == true ? 'Yes' : 'No',
      ),
      _OutputStat(
        label: 'Claim readiness',
        value: _summary?.claimReady == true ? 'Ready' : 'Waiting',
      ),
      _OutputStat(
        label: 'Claim message',
        value:
            _summary?.claimMessage ??
            'Policy output will appear here once premium is paid.',
        emphasize: false,
      ),
    ];
  }

  List<_OutputStat> _buildClaimOutput() {
    final claim = _autoClaim;
    return [
      _OutputStat(
        label: 'Claim triggered',
        value: (claim?['claim_triggered'] as bool?) == true ? 'Yes' : 'No',
      ),
      _OutputStat(
        label: 'Status',
        value:
            claim?['status']?.toString() ??
            (_summary?.latestClaimStatus ?? 'NO_CLAIM'),
      ),
      _OutputStat(
        label: 'Confidence',
        value: claim?['confidence']?.toString() ?? 'N/A',
      ),
      _OutputStat(
        label: 'Why it happened',
        value:
            claim?['explanation']?.toString() ??
            _summary?.claimMessage ??
            'The auto-claim engine is waiting for valid disruption and policy conditions.',
        emphasize: false,
      ),
    ];
  }

  List<_OutputStat> _buildFraudOutput() {
    final claim = _fraudCheck?['fraud'] as Map<String, dynamic>?;
    return [
      _OutputStat(
        label: 'Decision',
        value: claim?['decision']?.toString() ?? 'Not run yet',
      ),
      _OutputStat(
        label: 'Fraud score',
        value: ((claim?['fraud_score'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(2),
      ),
      _OutputStat(
        label: 'Fraud types',
        value: _joinList(claim?['fraud_types'] as List?),
      ),
      _OutputStat(
        label: 'Explanation',
        value:
            claim?['explanation']?.toString() ??
            'Run the live fraud check to see how the backend explains the current claim context.',
        emphasize: false,
      ),
    ];
  }

  List<_OutputStat> _buildPayoutOutput() {
    final autoPayout = (_autoClaim?['payout'] as Map?)?.cast<String, dynamic>();
    final payout = _manualPayout ?? autoPayout ?? const <String, dynamic>{};
    return [
      _OutputStat(
        label: 'Payout status',
        value:
            payout['status']?.toString() ??
            _summary?.latestClaimStatus ??
            (_summary?.lastPayout != null && (_summary?.lastPayout ?? 0) > 0
                ? 'SUCCESS'
                : 'PENDING'),
      ),
      _OutputStat(
        label: 'Amount',
        value:
            'Rs ${((payout['amount_paid'] as num?)?.toDouble() ?? (payout['amount'] as num?)?.toDouble() ?? _summary?.lastPayout ?? 0).toStringAsFixed(0)}',
      ),
      _OutputStat(
        label: 'Transaction ID',
        value:
            payout['transaction_id']?.toString() ??
            _summary?.payoutTransactionId ??
            'Not available yet',
      ),
      _OutputStat(
        label: 'Processing note',
        value:
            payout['message']?.toString() ??
            'Approved payouts are recorded here and reflected in transaction history.',
        emphasize: false,
      ),
    ];
  }

  bool _canProcessPayout() {
    final autoClaimStatus = (_autoClaim?['status']?.toString() ?? '')
        .toUpperCase();
    final payoutMap = (_autoClaim?['payout'] as Map?)?.cast<String, dynamic>();
    final alreadyProcessed =
        (payoutMap?['status']?.toString() ?? '').toUpperCase() == 'SUCCESS' ||
        ((_summary?.lastPayout ?? 0) > 0 &&
            (_summary?.payoutStatus ?? '').toUpperCase() == 'SUCCESS');
    return autoClaimStatus == 'APPROVED' && !alreadyProcessed;
  }

  String? _payoutActionLabel() {
    if (_isActionLoading('payout')) return 'Processing Payout';
    if ((_autoClaim?['status']?.toString() ?? '').toUpperCase() != 'APPROVED') {
      return 'Await Approved Claim';
    }
    if (!_canProcessPayout()) {
      return 'Payout Already Processed';
    }
    return 'Process Payout';
  }

  String _joinList(List? values) {
    final items = (values ?? const [])
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toList();
    return items.isEmpty ? 'None' : items.join(', ');
  }
}

class _HeroBanner extends StatelessWidget {
  final String userName;
  final String city;
  final String policyStatus;
  final List<String> pipeline;

  const _HeroBanner({
    required this.userName,
    required this.city,
    required this.policyStatus,
    required this.pipeline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF16261C), Color(0xFF111716)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Explainable AI Engine Dashboard',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  policyStatus,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'How your protection works, $userName',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This page turns the full insurance pipeline into a step-by-step system story using live backend data for $city.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pipeline
                .map(
                  (step) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<String> inputs;
  final String whatHappens;
  final List<_OutputStat> output;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  const _EngineCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.inputs,
    required this.whatHappens,
    required this.output,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = onAction != null && actionLabel != null;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoBlock(
              title: 'Inputs Used',
              icon: Icons.input_rounded,
              accentColor: accentColor,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: accentColor,
                  collapsedIconColor: accentColor,
                  title: const Text(
                    'Show live inputs',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    const SizedBox(height: 4),
                    ...inputs.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '- ',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _InfoBlock(
              title: 'What Happens',
              icon: Icons.settings_suggest_rounded,
              accentColor: accentColor,
              child: Text(
                whatHappens,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _InfoBlock(
              title: 'Output',
              icon: Icons.outbox_rounded,
              accentColor: accentColor,
              child: Column(
                children: output
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OutputTile(
                          item: item,
                          accentColor: accentColor,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canTap && !isLoading ? onAction : null,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : Icon(icon),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _InfoBlock({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OutputStat {
  final String label;
  final String value;
  final bool emphasize;

  const _OutputStat({
    required this.label,
    required this.value,
    this.emphasize = true,
  });
}

class _OutputTile extends StatelessWidget {
  final _OutputStat item;
  final Color accentColor;

  const _OutputTile({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.emphasize
            ? accentColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              color: item.emphasize
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontWeight: item.emphasize ? FontWeight.bold : FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  final EnvironmentModel environment;
  final Map<String, dynamic> risk;
  final Map<String, dynamic> premium;
  final Map<String, dynamic>? autoClaim;
  final Map<String, dynamic>? fraudCheck;
  final Map<String, dynamic>? manualPayout;

  const _ExplainerCard({
    required this.environment,
    required this.risk,
    required this.premium,
    required this.autoClaim,
    required this.fraudCheck,
    required this.manualPayout,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        title: 'Environment',
        body:
            'Live weather, AQI, and traffic inputs are read first. Right now that includes ${environment.weather.rainfall.toStringAsFixed(1)} mm rain and ${environment.traffic.trafficLevel.toLowerCase()} traffic.',
      ),
      (
        title: 'Risk',
        body:
            'The risk engine translated those signals into a ${((risk['risk_level'] as String?) ?? 'LOW').toUpperCase()} risk state with score ${((risk['risk_score'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}.',
      ),
      (
        title: 'Claim',
        body:
            autoClaim?['explanation']?.toString() ??
            'The claim engine is waiting for disruption, loss, and policy conditions to align.',
      ),
      (
        title: 'Fraud',
        body:
            ((fraudCheck?['fraud'] as Map?)?['explanation']?.toString()) ??
            'Fraud checks compare the claim story with disruption evidence and behavior patterns.',
      ),
      (
        title: 'Payout',
        body:
            manualPayout?['message']?.toString() ??
            ((autoClaim?['payout'] as Map?)?['message']?.toString()) ??
            'Approved payouts appear here after the backend validates the claim path.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why This System Did What It Did',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A compact story of the whole decision flow from signal collection to payout.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.body,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const _TransactionsCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Transaction Trail',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Premium and payout movements from the live backend ledger.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No transactions yet. Once premium is paid or payout is processed, the live records will appear here.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
              ),
            )
          else
            ...transactions
                .take(6)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  (item['type']?.toString().contains(
                                        'payout',
                                      ) ??
                                      false)
                                  ? AppTheme.successColor.withOpacity(0.12)
                                  : AppTheme.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              (item['type']?.toString().contains('payout') ??
                                      false)
                                  ? Icons.savings_rounded
                                  : Icons.receipt_long_rounded,
                              color:
                                  (item['type']?.toString().contains(
                                        'payout',
                                      ) ??
                                      false)
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (item['type']?.toString() ?? 'transaction')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs ${((item['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['remark']?.toString() ??
                                      item['status']?.toString() ??
                                      '',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: Text(
                              item['transaction_id']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
