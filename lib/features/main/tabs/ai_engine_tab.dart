import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';
import 'package:guidewire_gig_ins/features/insurance/screens/premium_purchase_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/bank_service.dart';
import 'package:local_auth/local_auth.dart';

class AIEngineTab extends ConsumerStatefulWidget {
  const AIEngineTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AIEngineTab> createState() => _AIEngineTabState();
}

class _AIEngineTabState extends ConsumerState<AIEngineTab>
    with TickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  late final AnimationController _pulseController;
  Future<BankSummary>? _bankFuture;
  Future<InsuranceSummaryModel?>? _insuranceFuture;
  bool _isLinkingBank = false;
  bool _isPayingPremium = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bankFuture = BankService.getSummary();
    _insuranceFuture = Future<InsuranceSummaryModel?>.value(null);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(environmentProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(premiumProvider);
    ref.read(claimProvider.notifier).reset();
    final user = ref.read(userProvider);
    setState(() {
      _bankFuture = BankService.getSummary();
      _insuranceFuture =
          user == null ? Future.value(null) : ApiService.getInsuranceSummary(user.userId);
    });
  }

  Future<void> _linkBank(int userId) async {
    if (_isLinkingBank) return;
    setState(() => _isLinkingBank = true);
    try {
      await ApiService.linkBankAccount(userId);
      await BankService.linkBank();
      setState(() {
        _bankFuture = BankService.getSummary();
        _insuranceFuture = ApiService.getInsuranceSummary(userId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank linked successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLinkingBank = false);
    }
  }

  Future<void> _payPremium(int userId, double amount) async {
    if (_isPayingPremium) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Confirm Premium Payment',
                style: TextStyle(color: AppTheme.textPrimary)),
            content: Text(
              'Pay Rs ${amount.toStringAsFixed(2)} for this week?',
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

    setState(() => _isPayingPremium = true);
    try {
      await ApiService.payPremium(userId, amount);
      setState(() {
        _bankFuture = BankService.getSummary();
        _insuranceFuture = ApiService.getInsuranceSummary(userId);
      });
      ref.invalidate(premiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium Paid Successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isPayingPremium = false);
    }
  }

  List<_Check> _steps(
    EnvironmentModel env,
    TodayIncomeModel today,
    BaselineIncomeModel baseline,
    LocationState location,
  ) {
    return [
      _Check('Checking weather...', env.weather.rainfall > 0 ? today.disruptionType == 'rain' : true),
      _Check('Checking traffic...', env.traffic.trafficLevel == 'LOW' ? today.disruptionType != 'traffic' : true),
      _Check('Checking income drop...', baseline.baselineDailyIncome > 0 ? today.earnings < baseline.baselineDailyIncome * 0.8 : false),
      _Check('Running fraud detection...', (location.lat - 13.0827).abs() < 5 && (location.lon - 80.2707).abs() < 5),
    ];
  }

  Future<void> _claim({
    required int userId,
    required bool isVerified,
    required bool claimReady,
    required LocationState location,
    required EnvironmentModel environment,
    required TodayIncomeModel today,
    required BaselineIncomeModel baseline,
  }) async {
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify identity before making a claim')),
      );
      return;
    }
    if (location.lat.isNaN || location.lon.isNaN) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is required to process a claim')),
      );
      return;
    }
    if (!claimReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim is available only after the policy period ends')),
      );
      return;
    }
    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Confirm your claim with fingerprint',
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

    final checks = _steps(environment, today, baseline, location);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ClaimDialog(
        checks: checks,
        runClaim: () async {
          final result = await ref.read(claimProvider.notifier).submitClaim(
                userId: userId,
                lat: location.lat,
                lon: location.lon,
              );
          setState(() => _bankFuture = BankService.getSummary());
          return result;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final environmentAsync = ref.watch(environmentProvider);
    final riskAsync = ref.watch(riskProvider);
    final todayAsync = ref.watch(todayIncomeProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final premiumAsync = ref.watch(premiumProvider);
    final location = ref.watch(locationProvider);
    _insuranceFuture ??= ApiService.getInsuranceSummary(user!.userId);

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(),
                const SizedBox(height: 18),
                FutureBuilder<BankSummary>(
                  future: _bankFuture,
                  builder: (context, snapshot) => _bankCard(user.userId, snapshot.data),
                ),
                const SizedBox(height: 18),
                environmentAsync.when(
                  data: (environment) => riskAsync.when(
                    data: (riskData) => _riskCard(environment, riskData),
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _ErrorCard('Risk engine unavailable'),
                  ),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => const _ErrorCard('Environment unavailable'),
                ),
                const SizedBox(height: 18),
                premiumAsync.when(
                  data: (premium) => _premiumCard(user.userId, premium),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => const _ErrorCard('Premium engine unavailable'),
                ),
                const SizedBox(height: 18),
                environmentAsync.when(
                  data: (environment) => todayAsync.when(
                    data: (today) => baselineAsync.when(
                      data: (baseline) => FutureBuilder<InsuranceSummaryModel?>(
                        future: _insuranceFuture,
                        builder: (context, snapshot) => _claimCard(
                          userId: user.userId,
                          isVerified: user.isVerified,
                          claimReady: snapshot.data?.claimReady ?? false,
                          claimMessage: snapshot.data?.claimMessage ?? 'Claim unavailable',
                          location: location,
                          environment: environment,
                          today: today,
                          baseline: baseline,
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1F291B), Color(0xFF161A16)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Builder(
          builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Insurance System', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('See premium, pay weekly cover, and process claims with live backend intelligence.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumPurchaseScreen()),
                );
              },
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Open Premium Engine'),
            ),
          ],
        ),
        ),
      );

  Widget _bankCard(int userId, BankSummary? bank) => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _pill(
                  bank?.bankLinked == true ? 'BANK LINKED' : 'BANK NOT LINKED',
                  bank?.bankLinked == true ? AppTheme.successColor : AppTheme.warningColor,
                ),
                const Spacer(),
                if (bank?.bankLinked != true)
                  TextButton(
                    onPressed: _isLinkingBank ? null : () => _linkBank(userId),
                    child: Text(_isLinkingBank ? 'Linking...' : 'Link Bank'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: cardWidth, child: _metric('Total Paid', 'Rs ${(bank?.totalPaid ?? 0).toStringAsFixed(0)}')),
                    SizedBox(width: cardWidth, child: _metric('Total Claimed', 'Rs ${(bank?.totalClaimed ?? 0).toStringAsFixed(0)}')),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _riskCard(EnvironmentModel env, Map<String, dynamic> riskData) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('01', 'Risk Engine', 'Live environment signals feeding the risk model'),
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
          _flowLine(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: cardWidth, child: _coreNode()),
                  SizedBox(
                    width: cardWidth,
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _premiumCard(int userId, Map<String, dynamic> data) {
    final baseline = (data['baseline'] as num?)?.toDouble() ?? 0.0;
    final weeklyIncome = (data['weekly_income'] as num?)?.toDouble() ?? 0.0;
    final coverage = (data['coverage'] as num?)?.toDouble() ?? 0.0;
    final weeklyPremium = (data['weekly_premium'] as num?)?.toDouble() ?? 0.0;
    final risk = (data['risk'] as Map<String, dynamic>?) ?? const {};
    final riskScore = (risk['risk_score'] as num?)?.toDouble() ?? (data['risk_score'] as num?)?.toDouble() ?? 0.0;
    final expectedIncomeLoss = risk['expected_income_loss']?.toString() ?? '0%';
    final triggerSeverity = risk['trigger_severity']?.toString() ?? 'LOW';
    final activeTriggers = (risk['active_triggers'] as List? ?? const []).map((item) => '$item').toList();
    final explanation = data['explanation']?.toString() ?? 'Pricing is based on live risk conditions.';
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('02', 'Risk Linked Premium', 'Risk engine output directly drives weekly cover pricing'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: cardWidth, child: _metric('Weekly Premium', 'Rs ${weeklyPremium.toStringAsFixed(0)}')),
                  SizedBox(width: cardWidth, child: _metric('Coverage', 'Rs ${coverage.toStringAsFixed(0)}')),
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
                  SizedBox(width: cardWidth, child: _metric('Weekly Income', 'Rs ${weeklyIncome.toStringAsFixed(0)}')),
                  SizedBox(width: cardWidth, child: _metric('Baseline Income', 'Rs ${baseline.toStringAsFixed(0)}')),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: cardWidth, child: _metric('Risk Score', riskScore.toStringAsFixed(2))),
                  SizedBox(width: cardWidth, child: _metric('Income Loss', expectedIncomeLoss)),
                  SizedBox(width: cardWidth, child: _metric('Trigger Severity', triggerSeverity)),
                ],
              );
            },
          ),
          if (activeTriggers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeTriggers
                  .map((trigger) => _pill(trigger, AppTheme.primaryColor))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              explanation,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPayingPremium ? null : () => _payPremium(userId, weeklyPremium),
              child: Text(_isPayingPremium ? 'Paying...' : 'Pay Premium'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimCard({
    required int userId,
    required bool isVerified,
    required bool claimReady,
    required String claimMessage,
    required LocationState location,
    required EnvironmentModel environment,
    required TodayIncomeModel today,
    required BaselineIncomeModel baseline,
  }) {
    final estimatedPayout = max(0.0, baseline.baselineDailyIncome - today.earnings) * 0.8;
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('03', 'Claim Engine', 'Verify claim signals and trigger payout'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final cardWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: cardWidth, child: _metric('Disruption', today.disruptionType.toUpperCase())),
                  SizedBox(width: cardWidth, child: _metric('Estimated Payout', 'Rs ${estimatedPayout.toStringAsFixed(0)}')),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          FutureBuilder<bool>(
            future: Future.value(claimReady),
            builder: (context, snapshot) => _checkWrap([
              _Check('Identity verified', isVerified),
              _Check('Location available', !location.lat.isNaN && !location.lon.isNaN),
              _Check('Claim ready', snapshot.data ?? false),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _claim(
                userId: userId,
                isVerified: isVerified,
                claimReady: claimReady,
                location: location,
                environment: environment,
                today: today,
                baseline: baseline,
              ),
              child: Text(
                claimReady ? 'Claim Insurance' : claimMessage,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    if (level == 'HIGH') return AppTheme.errorColor;
    if (level == 'MEDIUM') return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  Widget _metric(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      );

  Widget _input(IconData icon, String label, String value) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
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
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _coreNode() => AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glow = 0.16 + (_pulseController.value * 0.18);
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryColor.withOpacity(glow), AppTheme.primaryColor.withOpacity(0.08)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.memory_rounded, color: AppTheme.primaryColor, size: 24),
                SizedBox(width: 12),
                Expanded(child: Text('AI Core\nValidates signals before action', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, height: 1.4))),
              ],
            ),
          );
        },
      );

  Widget _flowLine() => SizedBox(
        height: 20,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 2, width: double.infinity, color: Colors.white.withOpacity(0.08)),
              Align(
                alignment: Alignment(-1 + (_pulseController.value * 2), 0),
                child: Container(width: 34, height: 6, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(999))),
              ),
            ],
          ),
        ),
      );

  Widget _checkWrap(List<_Check> checks) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: checks.map((item) {
          final color = item.pass ? AppTheme.successColor : AppTheme.warningColor;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
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

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      );
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
  const _Title(this.index, this.title, this.subtitle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
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
  Widget build(BuildContext context) => GlassCard(
        padding: EdgeInsets.zero,
        child: Container(height: 220, decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24))),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message, {super.key});
  @override
  Widget build(BuildContext context) => GlassCard(child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)));
}

class _ClaimDialog extends StatefulWidget {
  final List<_Check> checks;
  final Future<Map<String, dynamic>> Function() runClaim;
  const _ClaimDialog({required this.checks, required this.runClaim});

  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  int visibleSteps = 0;
  bool loading = true;
  Map<String, dynamic>? result;
  String? error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      for (var i = 0; i < widget.checks.length; i++) {
        await Future.delayed(const Duration(milliseconds: 420));
        if (!mounted) return;
        setState(() => visibleSteps = i + 1);
      }
      final response = await widget.runClaim();
      if (!mounted) return;
      setState(() {
        result = response;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = (result?['status'] as String? ?? '').toUpperCase() == 'APPROVED';
    final payout = (result?['payout'] as num?)?.toDouble() ?? 0.0;
    final reasons = (result?['reasons'] as List?)?.map((e) => '$e').join('\n');
    return Dialog(
      backgroundColor: AppTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verifying your claim...', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...List.generate(min(visibleSteps, widget.checks.length), (i) {
              final item = widget.checks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(item.pass ? Icons.check_circle : Icons.warning_amber_rounded, color: item.pass ? AppTheme.successColor : AppTheme.warningColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label, style: const TextStyle(color: AppTheme.textPrimary))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else
              _Result(
                color: error != null ? AppTheme.errorColor : approved ? AppTheme.successColor : AppTheme.warningColor,
                title: error != null
                    ? 'Claim failed'
                    : approved
                        ? 'Claim Approved'
                        : 'Claim Rejected',
                body: error ?? (approved ? 'Rs ${payout.toStringAsFixed(0)} credited to your account' : (reasons ?? 'Claim could not be approved')),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: Text(loading ? 'Processing...' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final Color color;
  final String title;
  final String body;
  const _Result({required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
      );
}
