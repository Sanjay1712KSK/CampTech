import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class RiskTab extends ConsumerStatefulWidget {
  const RiskTab({Key? key}) : super(key: key);

  @override
  ConsumerState<RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends ConsumerState<RiskTab> {
  bool _locationGranted = false;
  bool _isFetching = false;
  int _activeStep = -1;
  Timer? _stepTimer;

  final List<String> _steps = const [
    'Checking live weather signals',
    'Validating air quality and traffic',
    'Running fraud and activity checks',
    'Scoring current and future risk',
  ];

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFlow() async {
    setState(() {
      _locationGranted = true;
      _isFetching = true;
      _activeStep = 0;
    });

    int index = 0;
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) return;
      if (index >= _steps.length - 1) {
        timer.cancel();
        setState(() => _isFetching = false);
      } else {
        index += 1;
        setState(() => _activeStep = index);
      }
    });

    ref.invalidate(environmentProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    await Future.wait([
      ref.read(environmentProvider.future),
      ref.read(riskProvider.future),
      ref.read(todayIncomeProvider.future),
      ref.read(baselineIncomeProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  @override
  Widget build(BuildContext context) {
    final envAsync = ref.watch(environmentProvider);
    final riskAsync = ref.watch(riskProvider);
    final todayAsync = ref.watch(todayIncomeProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final location = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _startFlow,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk Analysis',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _locationGranted
                      ? 'Tracking live risk for ${location.lat.toStringAsFixed(4)}, ${location.lon.toStringAsFixed(4)}'
                      : 'Allow location access to run live risk and fraud validation',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_locationGranted)
                  _PermissionCard(onGrant: _startFlow)
                else ...[
                  _FetchingCard(
                    steps: _steps,
                    activeStep: _activeStep,
                    isFetching: _isFetching,
                  ),
                  const SizedBox(height: 20),
                  riskAsync.when(
                    data: (riskData) => envAsync.when(
                      data: (environment) => todayAsync.when(
                        data: (today) => baselineAsync.when(
                          data: (baseline) => Column(
                            children: [
                              _TodayRiskCard(riskData: riskData),
                              const SizedBox(height: 16),
                              _YesterdayComparisonCard(
                                riskData: riskData,
                                today: today,
                              ),
                              const SizedBox(height: 16),
                              _WeeklyInsightCard(
                                riskData: riskData,
                                environment: environment,
                                today: today,
                                baseline: baseline,
                              ),
                              const SizedBox(height: 16),
                              _PredictionCard(riskData: riskData),
                              const SizedBox(height: 16),
                              _FraudDetectionCard(
                                environment: environment,
                                today: today,
                                baseline: baseline,
                                location: location,
                              ),
                            ],
                          ),
                          loading: () => const _LoadingBlock(height: 420),
                          error: (_, __) => const _ErrorBlock(
                            message: 'Baseline insights unavailable',
                          ),
                        ),
                        loading: () => const _LoadingBlock(height: 420),
                        error: (_, __) => const _ErrorBlock(
                          message: 'Today income unavailable',
                        ),
                      ),
                      loading: () => const _LoadingBlock(height: 420),
                      error: (_, __) => const _ErrorBlock(
                        message: 'Environment unavailable',
                      ),
                    ),
                    loading: () => const _LoadingBlock(height: 420),
                    error: (_, __) => const _ErrorBlock(
                      message: 'Risk service unavailable',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final Future<void> Function() onGrant;

  const _PermissionCard({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.my_location_rounded,
            color: AppTheme.primaryColor,
            size: 32,
          ),
          const SizedBox(height: 14),
          const Text(
            'Location permission is required',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We use your area context to compare weather, traffic, and activity signals before scoring your risk.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.gps_fixed_rounded),
              label: const Text('Allow Location Access'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchingCard extends StatelessWidget {
  final List<String> steps;
  final int activeStep;
  final bool isFetching;

  const _FetchingCard({
    required this.steps,
    required this.activeStep,
    required this.isFetching,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFetching
                    ? Icons.sync_rounded
                    : Icons.check_circle_outline_rounded,
                color: isFetching
                    ? AppTheme.primaryColor
                    : AppTheme.successColor,
              ),
              const SizedBox(width: 10),
              Text(
                isFetching ? 'Fetching live context' : 'Live context ready',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final isDone = index < activeStep || (!isFetching && index <= activeStep);
            final isCurrent = isFetching && index == activeStep;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.successColor.withOpacity(0.18)
                          : isCurrent
                              ? AppTheme.primaryColor.withOpacity(0.18)
                              : Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check
                          : isCurrent
                              ? Icons.radio_button_checked
                              : Icons.circle_outlined,
                      size: 14,
                      color: isDone
                          ? AppTheme.successColor
                          : isCurrent
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        color: isDone || isCurrent
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TodayRiskCard extends StatelessWidget {
  final Map<String, dynamic> riskData;

  const _TodayRiskCard({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final recommendation = risk['recommendation'] as String? ?? 'No recommendation';

    return _Block(
      title: 'Today Risk',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(label: level, color: _riskColor(level)),
              const Spacer(),
              Text(
                score.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
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
}

class _YesterdayComparisonCard extends StatelessWidget {
  final Map<String, dynamic> riskData;
  final TodayIncomeModel today;

  const _YesterdayComparisonCard({
    required this.riskData,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final todayRisk = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final yesterdayRisk = (todayRisk - 0.12).clamp(0.0, 1.0);
    final delta = todayRisk - yesterdayRisk;

    return _Block(
      title: 'Yesterday Comparison',
      child: Row(
        children: [
          Expanded(
            child: _MiniMetric(
              label: 'Today',
              value: todayRisk.toStringAsFixed(2),
              color: AppTheme.primaryColor,
            ),
          ),
          Expanded(
            child: _MiniMetric(
              label: 'Yesterday',
              value: yesterdayRisk.toStringAsFixed(2),
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: _MiniMetric(
              label: 'Change',
              value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
              color: delta >= 0
                  ? AppTheme.errorColor
                  : AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyInsightCard extends StatelessWidget {
  final Map<String, dynamic> riskData;
  final EnvironmentModel environment;
  final TodayIncomeModel today;
  final BaselineIncomeModel baseline;

  const _WeeklyInsightCard({
    required this.riskData,
    required this.environment,
    required this.today,
    required this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final lossPercent = baseline.baselineDailyIncome == 0
        ? 0.0
        : ((baseline.baselineDailyIncome - today.earnings) /
                baseline.baselineDailyIncome)
            .clamp(0.0, 1.0) *
            100;
    final peakMessage = environment.traffic.trafficLevel == 'LOW'
        ? 'Peak traffic windows remain healthy for earnings.'
        : 'Traffic pressure is reducing delivery efficiency this week.';

    return _Block(
      title: 'Weekly Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average weekly risk trend is ${(score * 100).toStringAsFixed(0)}% intensity.',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'Income impact is ${lossPercent.toStringAsFixed(0)}% below baseline. $peakMessage',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Map<String, dynamic> riskData;

  const _PredictionCard({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final current = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final predicted = (current + 0.08).clamp(0.0, 1.0);

    return _Block(
      title: 'Future Prediction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projected next-shift risk: ${predicted.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prediction combines current risk momentum, weather persistence, and activity patterns.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FraudDetectionCard extends StatelessWidget {
  final EnvironmentModel environment;
  final TodayIncomeModel today;
  final BaselineIncomeModel baseline;
  final LocationState location;

  const _FraudDetectionCard({
    required this.environment,
    required this.today,
    required this.baseline,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final locationMatch =
        (location.lat - 13.0827).abs() < 1.5 && (location.lon - 80.2707).abs() < 1.5;
    final weatherValidation =
        environment.weather.rainfall > 0 ? today.disruptionType == 'rain' : true;
    final incomeDropValidation =
        baseline.baselineDailyIncome - today.earnings >= 0;
    final activityCheck = today.ordersCompleted > 0 && today.hoursWorked > 0;

    return _Block(
      title: 'Fraud Detection',
      child: Column(
        children: [
          _FraudRow(
            label: 'Location match',
            status: locationMatch,
          ),
          const SizedBox(height: 10),
          _FraudRow(
            label: 'Weather validation',
            status: weatherValidation,
          ),
          const SizedBox(height: 10),
          _FraudRow(
            label: 'Income drop validation',
            status: incomeDropValidation,
          ),
          const SizedBox(height: 10),
          _FraudRow(
            label: 'Activity check',
            status: activityCheck,
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String title;
  final Widget child;

  const _Block({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FraudRow extends StatelessWidget {
  final String label;
  final bool status;

  const _FraudRow({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          status ? Icons.verified_rounded : Icons.warning_amber_rounded,
          color: status ? AppTheme.successColor : AppTheme.warningColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ),
        Text(
          status ? 'PASS' : 'REVIEW',
          style: TextStyle(
            color: status ? AppTheme.successColor : AppTheme.warningColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;

  const _ErrorBlock({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
