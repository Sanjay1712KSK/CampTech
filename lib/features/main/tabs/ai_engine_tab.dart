import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class AIEngineTab extends ConsumerStatefulWidget {
  const AIEngineTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AIEngineTab> createState() => _AIEngineTabState();
}

class _AIEngineTabState extends ConsumerState<AIEngineTab>
    with TickerProviderStateMixin {
  late final AnimationController _pageController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final envAsync = ref.watch(environmentProvider);
    final riskAsync = ref.watch(riskProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final todayAsync = ref.watch(todayIncomeProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(environmentProvider);
            ref.invalidate(riskProvider);
            ref.invalidate(baselineIncomeProvider);
            ref.invalidate(todayIncomeProvider);
            await Future.wait([
              ref.read(environmentProvider.future),
              ref.read(riskProvider.future),
              ref.read(baselineIncomeProvider.future),
              ref.read(todayIncomeProvider.future),
            ]).catchError((_) => <Object>[]);
          },
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  index: 0,
                  child: const _HeroHeader(),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  index: 1,
                  child: envAsync.when(
                    data: (environment) => riskAsync.when(
                      data: (riskData) => _RiskEngineCard(
                        environment: environment,
                        riskData: riskData,
                        pulseController: _pulseController,
                      ),
                      loading: () => const _LoadingGlassCard(height: 280),
                      error: (_, __) => const _ErrorGlassCard(
                        title: 'Risk Engine',
                        message: 'Unable to load live risk output right now.',
                      ),
                    ),
                    loading: () => const _LoadingGlassCard(height: 280),
                    error: (_, __) => const _ErrorGlassCard(
                      title: 'Risk Engine',
                      message: 'Unable to load environment inputs right now.',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  index: 2,
                  child: baselineAsync.when(
                    data: (baseline) => riskAsync.when(
                      data: (riskData) => _PremiumEngineCard(
                        baseline: baseline,
                        riskData: riskData,
                        pulseController: _pulseController,
                      ),
                      loading: () => const _LoadingGlassCard(height: 250),
                      error: (_, __) => const _ErrorGlassCard(
                        title: 'Premium Engine',
                        message: 'Unable to calculate premium right now.',
                      ),
                    ),
                    loading: () => const _LoadingGlassCard(height: 250),
                    error: (_, __) => const _ErrorGlassCard(
                      title: 'Premium Engine',
                      message: 'Baseline data is unavailable.',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  index: 3,
                  child: baselineAsync.when(
                    data: (baseline) => todayAsync.when(
                      data: (today) => _ClaimEngineCard(
                        baseline: baseline,
                        today: today,
                        pulseController: _pulseController,
                      ),
                      loading: () => const _LoadingGlassCard(height: 250),
                      error: (_, __) => const _ErrorGlassCard(
                        title: 'Claim Engine',
                        message: 'Unable to detect claim triggers right now.',
                      ),
                    ),
                    loading: () => const _LoadingGlassCard(height: 250),
                    error: (_, __) => const _ErrorGlassCard(
                      title: 'Claim Engine',
                      message: 'Claim inputs are unavailable.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required int index,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _pageController,
      curve: Interval(
        min(0.15 * index, 0.7),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F291B),
            Color(0xFF161A16),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE INTELLIGENCE',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'AI Engine',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Watch how environment signals, income baseline, and disruption detection turn into pricing and protection in real time.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskEngineCard extends StatelessWidget {
  final EnvironmentModel environment;
  final Map<String, dynamic> riskData;
  final AnimationController pulseController;

  const _RiskEngineCard({
    required this.environment,
    required this.riskData,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 1.0);
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EngineTitle(
            indexLabel: '01',
            title: 'Risk Engine',
            subtitle: 'Inputs -> AI Core -> Risk Output',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InputNode(
                icon: Icons.cloud_outlined,
                label: 'Weather',
                value: '${environment.weather.rainfall.toStringAsFixed(1)} mm',
              ),
              _InputNode(
                icon: Icons.masks_rounded,
                label: 'AQI',
                value: '${environment.aqi.aqi}',
              ),
              _InputNode(
                icon: Icons.traffic_outlined,
                label: 'Traffic',
                value: environment.traffic.trafficLevel,
              ),
              _InputNode(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: '${environment.context.hour}:00',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AnimatedFlowLine(controller: pulseController),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _CoreNode(controller: pulseController),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: _OutputNode(
                  score: score,
                  level: level,
                  accentColor: _riskColor(level),
                ),
              ),
            ],
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

class _PremiumEngineCard extends StatelessWidget {
  final BaselineIncomeModel baseline;
  final Map<String, dynamic> riskData;
  final AnimationController pulseController;

  const _PremiumEngineCard({
    required this.baseline,
    required this.riskData,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 1.0);
    final weeklyPremium = baseline.baselineDailyIncome * 7 * score * 0.05;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EngineTitle(
            indexLabel: '02',
            title: 'Premium Engine',
            subtitle: 'Baseline x 7 x risk x 0.05',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _CalcNode(
                  label: 'Baseline',
                  value: 'Rs ${baseline.baselineDailyIncome.toStringAsFixed(0)}',
                  accent: AppTheme.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'x 7',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _CalcNode(
                  label: 'Risk',
                  value: score.toStringAsFixed(2),
                  accent: AppTheme.warningColor,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'x 0.05',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnimatedFlowLine(controller: pulseController),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: weeklyPremium),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Premium',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClaimEngineCard extends StatelessWidget {
  final BaselineIncomeModel baseline;
  final TodayIncomeModel today;
  final AnimationController pulseController;

  const _ClaimEngineCard({
    required this.baseline,
    required this.today,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final incomeDrop = max(0.0, baseline.baselineDailyIncome - today.earnings);
    final disruption = today.disruptionType.toUpperCase();
    final payout = incomeDrop * 0.8;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EngineTitle(
            indexLabel: '03',
            title: 'Claim Engine',
            subtitle: 'Trigger -> Claim -> Payout',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ClaimNode(
                  title: 'Trigger',
                  value: disruption,
                  icon: Icons.warning_amber_rounded,
                  accent: disruption == 'NONE'
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClaimNode(
                  title: 'Income Drop',
                  value: 'Rs ${incomeDrop.toStringAsFixed(0)}',
                  icon: Icons.trending_down_rounded,
                  accent: incomeDrop > 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnimatedFlowLine(controller: pulseController),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, child) {
                    final glow = 0.2 + (pulseController.value * 0.3);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(glow),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Payout',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rs ${payout.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ],
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

class _EngineTitle extends StatelessWidget {
  final String indexLabel;
  final String title;
  final String subtitle;

  const _EngineTitle({
    required this.indexLabel,
    required this.title,
    required this.subtitle,
  });

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
          child: Text(
            indexLabel,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InputNode({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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

class _CoreNode extends StatelessWidget {
  final AnimationController controller;

  const _CoreNode({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse = 0.2 + (controller.value * 0.25);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(pulse),
                AppTheme.primaryColor.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.memory_rounded,
                color: AppTheme.primaryColor,
                size: 26,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Core\nNormalizes and scores risk factors',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutputNode extends StatelessWidget {
  final double score;
  final String level;
  final Color accentColor;

  const _OutputNode({
    required this.score,
    required this.level,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(2),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'risk_score',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalcNode extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CalcNode({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimNode extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _ClaimNode({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFlowLine extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedFlowLine({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 2,
                width: double.infinity,
                color: Colors.white.withOpacity(0.08),
              ),
              Align(
                alignment: Alignment(-1 + (controller.value * 2), 0),
                child: Container(
                  width: 36,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingGlassCard extends StatelessWidget {
  final double height;

  const _LoadingGlassCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _ErrorGlassCard extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorGlassCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
          const SizedBox(height: 10),
          Text(
            message,
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
