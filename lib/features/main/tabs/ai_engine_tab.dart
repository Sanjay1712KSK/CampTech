import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/bank_service.dart';

class AIEngineTab extends ConsumerStatefulWidget {
  const AIEngineTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AIEngineTab> createState() => _AIEngineTabState();
}

class _AIEngineTabState extends ConsumerState<AIEngineTab>
    with TickerProviderStateMixin {
  late final AnimationController _pageController;
  late final AnimationController _pulseController;
  Future<BankSummary>? _bankFuture;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _bankFuture = BankService.getSummary();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(environmentProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(todayIncomeProvider);
    setState(() => _bankFuture = BankService.getSummary());
    await Future.wait([
      ref.read(environmentProvider.future),
      ref.read(riskProvider.future),
      ref.read(baselineIncomeProvider.future),
      ref.read(todayIncomeProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  Future<void> _linkBank() async {
    await BankService.linkBank();
    setState(() => _bankFuture = BankService.getSummary());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank linked')),
    );
  }

  Future<void> _payPremium(double amount) async {
    await BankService.payPremium(amount);
    setState(() => _bankFuture = BankService.getSummary());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Premium paid: Rs ${amount.toStringAsFixed(2)}')),
    );
  }

  List<_Check> _checks(
    EnvironmentModel env,
    TodayIncomeModel today,
    BaselineIncomeModel baseline,
    LocationState location,
  ) {
    return [
      _Check(
        'Location match',
        (location.lat - 13.0827).abs() < 1.5 &&
            (location.lon - 80.2707).abs() < 1.5,
      ),
      _Check(
        'Weather validation',
        env.weather.rainfall > 0 ? today.disruptionType == 'rain' : true,
      ),
      _Check(
        'Income drop validation',
        baseline.baselineDailyIncome - today.earnings >= 0,
      ),
      _Check(
        'Activity check',
        today.ordersCompleted > 0 && today.hoursWorked > 0,
      ),
    ];
  }

  Future<void> _runClaim(
    EnvironmentModel env,
    TodayIncomeModel today,
    BaselineIncomeModel baseline,
    LocationState location,
  ) async {
    final checks = _checks(env, today, baseline, location);
    final approved = checks.every((e) => e.pass);
    final payout = max(0.0, baseline.baselineDailyIncome - today.earnings) * 0.8;

    await showDialog<void>(
      context: context,
      builder: (context) => _ClaimDialog(
        checks: checks,
        approved: approved,
        payout: payout,
        onFinish: () async {
          if (approved && payout > 0) {
            await BankService.payoutClaim(payout);
            setState(() => _bankFuture = BankService.getSummary());
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final envAsync = ref.watch(environmentProvider);
    final riskAsync = ref.watch(riskProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final todayAsync = ref.watch(todayIncomeProvider);
    final location = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  0,
                  _hero(),
                ),
                const SizedBox(height: 18),
                _section(
                  1,
                  FutureBuilder<BankSummary>(
                    future: _bankFuture,
                    builder: (context, snapshot) => _bankCard(
                      snapshot.data,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  2,
                  envAsync.when(
                    data: (env) => riskAsync.when(
                      data: (riskData) => _riskCard(
                        env,
                        riskData,
                        _checks(
                          env,
                          todayAsync.value ??
                              const TodayIncomeModel(
                                earnings: 0,
                                ordersCompleted: 0,
                                hoursWorked: 0,
                                disruptionType: 'none',
                              ),
                          baselineAsync.value ??
                              BaselineIncomeModel(baselineDailyIncome: 0),
                          location,
                        ),
                      ),
                      loading: () => const _LoadingCard(),
                      error: (_, __) => const _ErrorCard('Risk engine unavailable'),
                    ),
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _ErrorCard('Environment unavailable'),
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  3,
                  baselineAsync.when(
                    data: (baseline) => riskAsync.when(
                      data: (riskData) => _premiumCard(baseline, riskData),
                      loading: () => const _LoadingCard(),
                      error: (_, __) => const _ErrorCard('Premium engine unavailable'),
                    ),
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _ErrorCard('Baseline unavailable'),
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  4,
                  envAsync.when(
                    data: (env) => baselineAsync.when(
                      data: (baseline) => todayAsync.when(
                        data: (today) => _claimCard(
                          env,
                          today,
                          baseline,
                          location,
                        ),
                        loading: () => const _LoadingCard(),
                        error: (_, __) => const _ErrorCard('Claim inputs unavailable'),
                      ),
                      loading: () => const _LoadingCard(),
                      error: (_, __) => const _ErrorCard('Claim inputs unavailable'),
                    ),
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _ErrorCard('Claim inputs unavailable'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F291B), Color(0xFF161A16)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Insurance System',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Real-time risk, dynamic premium, fraud-aware claims, and finance tracking in one flow.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _bankCard(BankSummary? bank) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(
                bank?.bankLinked == true ? 'BANK LINKED' : 'BANK NOT LINKED',
                bank?.bankLinked == true
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
              ),
              const Spacer(),
              if (bank?.bankLinked != true)
                TextButton(
                  onPressed: _linkBank,
                  child: const Text('Link Bank'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metric('Paid', 'Rs ${(bank?.totalPaid ?? 0).toStringAsFixed(0)}')),
              const SizedBox(width: 12),
              Expanded(child: _metric('Claimed', 'Rs ${(bank?.totalClaimed ?? 0).toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskCard(EnvironmentModel env, Map<String, dynamic> riskData, List<_Check> checks) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            index: '01',
            title: 'Risk Engine',
            subtitle: 'Inputs -> fraud checks -> live risk output',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _input(Icons.cloud_outlined, 'Weather', '${env.weather.rainfall.toStringAsFixed(1)} mm'),
              _input(Icons.masks_rounded, 'AQI', '${env.aqi.aqi}'),
              _input(Icons.traffic_outlined, 'Traffic', env.traffic.trafficLevel),
              _input(Icons.schedule_rounded, 'Time', '${env.context.hour}:00'),
            ],
          ),
          const SizedBox(height: 14),
          _checkWrap(checks.take(2).toList()),
          const SizedBox(height: 14),
          _flowLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _coreNode()),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _riskColor(level).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level, style: TextStyle(color: _riskColor(level), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(score.toStringAsFixed(2), style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 28)),
                      const Text('risk_score', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumCard(BaselineIncomeModel baseline, Map<String, dynamic> riskData) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final weeklyPremium = baseline.baselineDailyIncome * 7 * score * 0.05;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            index: '02',
            title: 'Premium Engine',
            subtitle: 'Baseline x 7 x risk x 0.05',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _metric('Baseline', 'Rs ${baseline.baselineDailyIncome.toStringAsFixed(0)}')),
              const SizedBox(width: 12),
              Expanded(child: _metric('Risk', score.toStringAsFixed(2))),
            ],
          ),
          const SizedBox(height: 14),
          _flowLine(),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weekly Premium', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text('Rs ${weeklyPremium.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 30, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _payPremium(weeklyPremium),
              child: const Text('Pay Premium'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimCard(EnvironmentModel env, TodayIncomeModel today, BaselineIncomeModel baseline, LocationState location) {
    final checks = _checks(env, today, baseline, location);
    final incomeDrop = max(0.0, baseline.baselineDailyIncome - today.earnings);
    final payout = incomeDrop * 0.8;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            index: '03',
            title: 'Claim Engine',
            subtitle: 'Trigger -> verification -> approve or reject',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _metric('Disruption', today.disruptionType.toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: _metric('Income Drop', 'Rs ${incomeDrop.toStringAsFixed(0)}')),
            ],
          ),
          const SizedBox(height: 14),
          _checkWrap(checks),
          const SizedBox(height: 14),
          _flowLine(),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Payout', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text('Rs ${payout.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _runClaim(env, today, baseline, location),
              child: const Text('Run Claim Verification'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(int index, Widget child) {
    final animation = CurvedAnimation(
      parent: _pageController,
      curve: Interval(min(0.16 * index, 0.7), 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _input(IconData icon, String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coreNode() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.18 + (_pulseController.value * 0.18);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(glow),
                AppTheme.primaryColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.memory_rounded, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Core\nScores and verifies signals before action',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _flowLine() {
    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 2, width: double.infinity, color: Colors.white.withOpacity(0.08)),
              Align(
                alignment: Alignment(-1 + (_pulseController.value * 2), 0),
                child: Container(
                  width: 34,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _checkWrap(List<_Check> checks) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: checks.map((item) {
        final color = item.pass ? AppTheme.successColor : AppTheme.warningColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.pass ? Icons.check : Icons.warning_amber_rounded, color: color, size: 14),
              const SizedBox(width: 6),
              Text(item.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _Check {
  final String label;
  final bool pass;
  const _Check(this.label, this.pass);
}

class _Title extends StatelessWidget {
  final String index;
  final String title;
  final String subtitle;
  const _Title({required this.index, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(index, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _ClaimDialog extends StatefulWidget {
  final List<_Check> checks;
  final bool approved;
  final double payout;
  final Future<void> Function() onFinish;

  const _ClaimDialog({
    required this.checks,
    required this.approved,
    required this.payout,
    required this.onFinish,
  });

  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  int visibleSteps = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var i = 0; i < widget.checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() => visibleSteps = i + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Claim Validation Flow', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Running verification checks before claim approval', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 18),
            ...List.generate(min(visibleSteps, widget.checks.length), (index) {
              final item = widget.checks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(item.pass ? Icons.check_circle : Icons.warning_amber_rounded, color: item.pass ? AppTheme.successColor : AppTheme.warningColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label, style: const TextStyle(color: AppTheme.textPrimary))),
                    Text(item.pass ? 'PASS' : 'REVIEW', style: TextStyle(color: item.pass ? AppTheme.successColor : AppTheme.warningColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.approved ? AppTheme.successColor.withOpacity(0.1) : AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.approved ? 'Claim Approved' : 'Claim Rejected', style: TextStyle(color: widget.approved ? AppTheme.successColor : AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(
                    widget.approved
                        ? 'Estimated payout: Rs ${widget.payout.toStringAsFixed(2)}'
                        : 'Verification mismatch detected. Manual review required.',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onFinish,
                child: Text(widget.approved ? 'Finish and Payout' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
