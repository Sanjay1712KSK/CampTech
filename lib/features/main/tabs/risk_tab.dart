import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/location_service.dart';

class RiskTab extends ConsumerStatefulWidget {
  const RiskTab({super.key});

  @override
  ConsumerState<RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends ConsumerState<RiskTab> {
  bool _started = false;
  bool _isFetching = false;
  int _activeStep = -1;
  String? _locationMessage;
  Timer? _timer;

  final List<String> _steps = const [
    'Detecting location',
    'Fetching weather',
    'Fetching AQI',
    'Analyzing traffic',
    'Running AI engine',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startAnalysis({bool useLiveLocation = true}) async {
    setState(() {
      _started = true;
      _isFetching = true;
      _activeStep = 0;
      _locationMessage = null;
    });

    if (useLiveLocation) {
      final result = await LocationService.requestCurrentLocation();
      if (result.granted && result.lat != null && result.lon != null) {
        ref.read(locationProvider.notifier).updateLocation(
              lat: result.lat!,
              lon: result.lon!,
              city: result.city ?? 'Current City',
              permissionGranted: true,
              isLive: true,
              error: null,
            );
      } else {
        ref.read(locationProvider.notifier).setLimitedFallback(message: result.error);
        if (mounted) {
          setState(() => _locationMessage = result.error ?? 'Using fallback location');
        }
      }
    } else {
      ref.read(locationProvider.notifier).setLimitedFallback(
            message: 'Using fallback location until permission is granted',
          );
      if (mounted) {
        setState(() => _locationMessage = 'Using fallback location until permission is granted');
      }
    }

    int current = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (!mounted) return;
      if (current >= _steps.length - 1) {
        timer.cancel();
        setState(() => _isFetching = false);
      } else {
        current += 1;
        setState(() => _activeStep = current);
      }
    });

    ref.invalidate(environmentProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(incomeHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final riskAsync = ref.watch(riskProvider);
    final environmentAsync = ref.watch(environmentProvider);
    final todayAsync = ref.watch(todayIncomeProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final historyAsync = ref.watch(incomeHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _startAnalysis(useLiveLocation: true),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: !_started
                ? _PermissionStage(
                    onAllow: () => _startAnalysis(useLiveLocation: true),
                    onLimited: () => _startAnalysis(useLiveLocation: false),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Risk Analysis',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FetchStage(
                        steps: _steps,
                        activeStep: _activeStep,
                        isFetching: _isFetching,
                      ),
                      if (_locationMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBlock(_locationMessage!),
                      ],
                      const SizedBox(height: 20),
                      riskAsync.when(
                        data: (riskData) => environmentAsync.when(
                          data: (environment) => todayAsync.when(
                            data: (today) => baselineAsync.when(
                              data: (baseline) => historyAsync.when(
                                data: (history) => Column(
                                  children: [
                                    _TodayCard(riskData: riskData),
                                    const SizedBox(height: 16),
                                    _YesterdayCard(riskData: riskData, history: history),
                                    const SizedBox(height: 16),
                                    _PastWeekCard(
                                      history: history,
                                      baseline: baseline,
                                    ),
                                    const SizedBox(height: 16),
                                    _FutureCard(
                                      riskData: riskData,
                                      environment: environment,
                                      today: today,
                                    ),
                                  ],
                                ),
                                loading: () => const _LoadingBlock(),
                                error: (_, __) => const _ErrorBlock('History unavailable'),
                              ),
                              loading: () => const _LoadingBlock(),
                              error: (_, __) => const _ErrorBlock('Baseline unavailable'),
                            ),
                            loading: () => const _LoadingBlock(),
                            error: (_, __) => const _ErrorBlock('Today income unavailable'),
                          ),
                          loading: () => const _LoadingBlock(),
                          error: (_, __) => const _ErrorBlock('Environment unavailable'),
                        ),
                        loading: () => const _LoadingBlock(),
                        error: (_, __) => const _ErrorBlock('Risk service unavailable'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PermissionStage extends StatelessWidget {
  final Future<void> Function() onAllow;
  final Future<void> Function() onLimited;

  const _PermissionStage({required this.onAllow, required this.onLimited});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.76,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.my_location_rounded, size: 44, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Allow location to analyze your delivery risk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'We combine weather, AQI, traffic, and work patterns to estimate delivery risk and claim reliability.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAllow,
                    child: const Text('Allow'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLimited,
                    child: const Text('Continue limited'),
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

class _FetchStage extends StatelessWidget {
  final List<String> steps;
  final int activeStep;
  final bool isFetching;

  const _FetchStage({
    required this.steps,
    required this.activeStep,
    required this.isFetching,
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
        children: List.generate(steps.length, (index) {
          final active = index <= activeStep;
          return Padding(
            padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primaryColor.withOpacity(0.18)
                        : Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active
                        ? (isFetching && index == activeStep
                            ? Icons.radio_button_checked
                            : Icons.check)
                        : Icons.circle_outlined,
                    size: 14,
                    color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Map<String, dynamic> riskData;

  const _TodayCard({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final recommendation = risk['recommendation'] as String? ?? 'No recommendation';
    final color = level == 'HIGH'
        ? AppTheme.errorColor
        : level == 'MEDIUM'
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return _CardBlock(
      title: 'Today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(
                score.toStringAsFixed(2),
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 30),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(recommendation, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _YesterdayCard extends StatelessWidget {
  final Map<String, dynamic> riskData;
  final IncomeHistoryModel history;

  const _YesterdayCard({required this.riskData, required this.history});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final predicted = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final yesterday = history.records.length >= 2
        ? history.records[history.records.length - 2]
        : history.records.isNotEmpty
            ? history.records.last
            : null;
    final actual = yesterday?.traffic?.trafficLevel ?? 'No data';
    final impact = yesterday == null ? 0.0 : max(0.0, 850 - yesterday.earnings);

    return _CardBlock(
      title: 'Yesterday',
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Predicted risk', value: predicted.toStringAsFixed(2))),
          Expanded(child: _MiniStat(label: 'Actual outcome', value: actual)),
          Expanded(child: _MiniStat(label: 'Income impact', value: 'Rs ${impact.toStringAsFixed(0)}')),
        ],
      ),
    );
  }
}

class _PastWeekCard extends StatelessWidget {
  final IncomeHistoryModel history;
  final BaselineIncomeModel baseline;

  const _PastWeekCard({required this.history, required this.baseline});

  @override
  Widget build(BuildContext context) {
    final recent = history.records.length > 7
        ? history.records.sublist(history.records.length - 7)
        : history.records;
    final avgRisk = recent.isEmpty
        ? 0.0
        : recent
                .map((record) => record.traffic?.trafficScore ?? 1.0)
                .reduce((a, b) => a + b) /
            recent.length;
    final disruptions =
        recent.where((record) => (record.disruptionType ?? 'none') != 'none').length;
    final totalLoss = recent.fold<double>(
      0.0,
      (sum, record) => sum + max(0.0, baseline.baselineDailyIncome - record.earnings),
    );

    return _CardBlock(
      title: 'Past Week',
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Avg risk', value: avgRisk.toStringAsFixed(2))),
          Expanded(child: _MiniStat(label: 'Disruptions', value: '$disruptions')),
          Expanded(child: _MiniStat(label: 'Total loss', value: 'Rs ${totalLoss.toStringAsFixed(0)}')),
        ],
      ),
    );
  }
}

class _FutureCard extends StatelessWidget {
  final Map<String, dynamic> riskData;
  final EnvironmentModel environment;
  final TodayIncomeModel today;

  const _FutureCard({
    required this.riskData,
    required this.environment,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final todayPrediction =
        ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final tomorrowPrediction =
        (todayPrediction + (environment.weather.rainfall > 0 ? 0.08 : 0.03)).clamp(0.0, 1.0);
    final outlook = tomorrowPrediction > 0.7
        ? 'High-risk week ahead'
        : tomorrowPrediction > 0.4
            ? 'Mixed week ahead'
            : 'Stable week ahead';

    return _CardBlock(
      title: 'Future',
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Today prediction', value: todayPrediction.toStringAsFixed(2))),
          Expanded(child: _MiniStat(label: 'Tomorrow', value: tomorrowPrediction.toStringAsFixed(2))),
          Expanded(child: _MiniStat(label: 'Weekly outlook', value: outlook)),
        ],
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardBlock({required this.title, required this.child});

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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
      );
}

class _ErrorBlock extends StatelessWidget {
  final String message;

  const _ErrorBlock(this.message);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      );
}
