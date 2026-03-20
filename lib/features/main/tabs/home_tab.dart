import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/features/gig/screens/income_intelligence_screen.dart';
import 'package:guidewire_gig_ins/features/main/tabs/risk_tab.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(environmentProvider);
    await Future.wait([
      ref.read(todayIncomeProvider.future),
      ref.read(baselineIncomeProvider.future),
      ref.read(riskProvider.future),
      ref.read(environmentProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  String _greeting(AppLocalizations l10n) {
    final hour = _now.hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  String get _formattedDateTime {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour =
        _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '${_now.day} ${months[_now.month - 1]} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(userProvider);
    final location = ref.watch(locationProvider);

    if (l10n == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final todayAsync = ref.watch(todayIncomeProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);
    final riskAsync = ref.watch(riskProvider);
    final environmentAsync = ref.watch(environmentProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(
                  greeting: _greeting(l10n),
                  userName: user.userName,
                  dateTime: _formattedDateTime,
                  lat: location.lat,
                  lon: location.lon,
                  environmentAsync: environmentAsync,
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Today Snapshot'),
                const SizedBox(height: 12),
                todayAsync.when(
                  data: (today) => _TodaySnapshotCard(today: today),
                  loading: () => const _SkeletonCard(height: 150),
                  error: (_, __) =>
                      const _InlineErrorCard(message: 'Unable to load today data'),
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Risk Status'),
                const SizedBox(height: 12),
                riskAsync.when(
                  data: (riskData) => _RiskStatusCard(riskData: riskData),
                  loading: () => const _SkeletonCard(height: 160),
                  error: (_, __) =>
                      const _InlineErrorCard(message: 'Unable to load risk status'),
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Baseline vs Today'),
                const SizedBox(height: 12),
                _BaselineSection(
                  baselineAsync: baselineAsync,
                  todayAsync: todayAsync,
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Quick Actions'),
                const SizedBox(height: 12),
                _QuickActionsGrid(
                  onVerify: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DigilockerVerificationScreen(),
                      ),
                    );
                  },
                  onConnectGig: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectGigScreen(),
                      ),
                    );
                  },
                  onViewEarnings: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            IncomeIntelligenceScreen(userId: user.userId),
                      ),
                    );
                  },
                  onViewRisk: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RiskTab()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Mini Insights'),
                const SizedBox(height: 12),
                _MiniInsightsSection(
                  todayAsync: todayAsync,
                  baselineAsync: baselineAsync,
                  environmentAsync: environmentAsync,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String greeting;
  final String userName;
  final String dateTime;
  final double lat;
  final double lon;
  final AsyncValue<EnvironmentModel> environmentAsync;

  const _HeaderSection({
    required this.greeting,
    required this.userName,
    required this.dateTime,
    required this.lat,
    required this.lon,
    required this.environmentAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF262F1C),
            Color(0xFF191F17),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateTime,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Chennai • ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          environmentAsync.when(
            data: (env) {
              return Row(
                children: [
                  Expanded(
                    child: _HeaderMetric(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Weather',
                      value: '${env.weather.temperature.toStringAsFixed(1)}°C',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeaderMetric(
                      icon: Icons.air,
                      label: 'AQI',
                      value: '${env.aqi.aqi}',
                    ),
                  ),
                ],
              );
            },
            loading: () => Row(
              children: const [
                Expanded(child: _SkeletonChip()),
                SizedBox(width: 12),
                Expanded(child: _SkeletonChip()),
              ],
            ),
            error: (_, __) => const Text(
              'Weather and AQI unavailable right now',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodaySnapshotCard extends StatelessWidget {
  final TodayIncomeModel today;

  const _TodaySnapshotCard({required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'Performance at a glance',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Earnings',
                  value: 'Rs ${today.earnings.toInt()}',
                  icon: Icons.currency_rupee_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Orders',
                  value: '${today.ordersCompleted}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Hours',
                  value: '${today.hoursWorked}',
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskStatusCard extends StatelessWidget {
  final Map<String, dynamic> riskData;

  const _RiskStatusCard({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final recommendation =
        risk['recommendation'] as String? ?? 'No recommendation available';

    Color color;
    if (level == 'HIGH') {
      color = AppTheme.errorColor;
    } else if (level == 'MEDIUM') {
      color = AppTheme.warningColor;
    } else {
      color = AppTheme.successColor;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                score.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommendation',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineSection extends StatelessWidget {
  final AsyncValue<BaselineIncomeModel> baselineAsync;
  final AsyncValue<TodayIncomeModel> todayAsync;

  const _BaselineSection({
    required this.baselineAsync,
    required this.todayAsync,
  });

  @override
  Widget build(BuildContext context) {
    return baselineAsync.when(
      data: (baseline) {
        return todayAsync.when(
          data: (today) {
            final difference = today.earnings - baseline.baselineDailyIncome;
            final isProfit = difference >= 0;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Baseline',
                          value: 'Rs ${baseline.baselineDailyIncome.toInt()}',
                          icon: Icons.insights_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Today',
                          value: 'Rs ${today.earnings.toInt()}',
                          icon: Icons.today_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isProfit
                              ? AppTheme.successColor
                              : AppTheme.errorColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isProfit
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: isProfit
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${isProfit ? 'Profit' : 'Loss'}: Rs ${difference.abs().toInt()}',
                          style: TextStyle(
                            color: isProfit
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const _SkeletonCard(height: 160),
          error: (_, __) =>
              const _InlineErrorCard(message: 'Unable to compare earnings'),
        );
      },
      loading: () => const _SkeletonCard(height: 160),
      error: (_, __) =>
          const _InlineErrorCard(message: 'Unable to load baseline income'),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onVerify;
  final VoidCallback onConnectGig;
  final VoidCallback onViewEarnings;
  final VoidCallback onViewRisk;

  const _QuickActionsGrid({
    required this.onVerify,
    required this.onConnectGig,
    required this.onViewEarnings,
    required this.onViewRisk,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _ActionCard(
          icon: Icons.verified_user_outlined,
          title: 'Verify Identity',
          subtitle: 'Complete DigiLocker verification',
          onTap: onVerify,
        ),
        _ActionCard(
          icon: Icons.link_rounded,
          title: 'Connect Gig Account',
          subtitle: 'Add your delivery partner account',
          onTap: onConnectGig,
        ),
        _ActionCard(
          icon: Icons.bar_chart_rounded,
          title: 'View Earnings',
          subtitle: 'Open income intelligence',
          onTap: onViewEarnings,
        ),
        _ActionCard(
          icon: Icons.security_rounded,
          title: 'View Risk',
          subtitle: 'Check live safety signals',
          onTap: onViewRisk,
        ),
      ],
    );
  }
}

class _MiniInsightsSection extends StatelessWidget {
  final AsyncValue<TodayIncomeModel> todayAsync;
  final AsyncValue<BaselineIncomeModel> baselineAsync;
  final AsyncValue<EnvironmentModel> environmentAsync;

  const _MiniInsightsSection({
    required this.todayAsync,
    required this.baselineAsync,
    required this.environmentAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        todayAsync.when(
          data: (today) {
            return baselineAsync.when(
              data: (baseline) {
                final gap = baseline.baselineDailyIncome == 0
                    ? 0.0
                    : ((baseline.baselineDailyIncome - today.earnings) /
                            baseline.baselineDailyIncome) *
                        100;
                final isLower = gap > 0;
                final insight = isLower
                    ? 'You earned ${gap.abs().toStringAsFixed(0)}% less than baseline today.'
                    : 'You are outperforming baseline by ${gap.abs().toStringAsFixed(0)}% today.';
                return _InsightCard(
                  icon: isLower
                      ? Icons.cloudy_snowing
                      : Icons.trending_up_rounded,
                  title: 'Earnings Insight',
                  description: insight,
                );
              },
              loading: () => const _SkeletonCard(height: 88),
              error: (_, __) =>
                  const _InlineErrorCard(message: 'Insights unavailable'),
            );
          },
          loading: () => const _SkeletonCard(height: 88),
          error: (_, __) =>
              const _InlineErrorCard(message: 'Insights unavailable'),
        ),
        const SizedBox(height: 12),
        environmentAsync.when(
          data: (env) {
            final peakBoost = env.traffic.trafficLevel == 'LOW' ? 20 : 12;
            final weatherHint = env.weather.rainfall > 0
                ? 'Rain conditions may be suppressing earnings.'
                : 'Stable weather supports stronger peak-hour earnings.';
            return _InsightCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Operations Insight',
              description:
                  'Peak hours improved earnings by $peakBoost%. $weatherHint',
            );
          },
          loading: () => const _SkeletonCard(height: 88),
          error: (_, __) =>
              const _InlineErrorCard(message: 'Operational insight unavailable'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
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
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.4,
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  final String message;

  const _InlineErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
