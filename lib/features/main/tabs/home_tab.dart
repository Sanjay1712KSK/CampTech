import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/features/insurance/screens/claim_flow_screen.dart';
import 'package:guidewire_gig_ins/features/insurance/screens/premium_purchase_screen.dart';
import 'package:guidewire_gig_ins/features/main/tabs/risk_tab.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/bank_service.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

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
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(environmentProvider);
    ref.invalidate(premiumProvider);
  }

  String _greeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDateTime() {
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
    return '${_now.day} ${months[_now.month - 1]}  $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final todayAsync = ref.watch(todayIncomeProvider);
    final riskAsync = ref.watch(riskProvider);
    final environmentAsync = ref.watch(environmentProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(
                  greeting: _greeting(),
                  userName: user.userName,
                  dateTime: _formatDateTime(),
                  city: ref.watch(locationProvider).city,
                  environmentAsync: environmentAsync,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Policy Status'),
                const SizedBox(height: 12),
                FutureBuilder<BankSummary>(
                  future: BankService.getSummary(),
                  builder: (context, snapshot) {
                    final bank = snapshot.data;
                    return _PolicyStatusCard(bank: bank);
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Today Snapshot'),
                const SizedBox(height: 12),
                todayAsync.when(
                  data: (today) => _TodaySnapshotCard(today: today),
                  loading: () => const _SkeletonCard(height: 150),
                  error: (_, __) =>
                      const _InlineErrorCard('Unable to load today snapshot'),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Risk Summary'),
                const SizedBox(height: 12),
                riskAsync.when(
                  data: (riskData) => _RiskSummaryCard(riskData: riskData),
                  loading: () => const _SkeletonCard(height: 150),
                  error: (_, __) =>
                      const _InlineErrorCard('Unable to load risk summary'),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Quick Actions'),
                const SizedBox(height: 12),
                _QuickActions(
                  onBuyPolicy: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PremiumPurchaseScreen(),
                    ),
                  ),
                  onClaim: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClaimFlowScreen(),
                    ),
                  ),
                  onConnectGig: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConnectGigScreen(),
                    ),
                  ),
                  onVerify: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DigilockerVerificationScreen(),
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
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String dateTime;
  final String city;
  final AsyncValue<EnvironmentModel> environmentAsync;

  const _HomeHeader({
    required this.greeting,
    required this.userName,
    required this.dateTime,
    required this.city,
    required this.environmentAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF262F1C), Color(0xFF191F17)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
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
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            city,
            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          environmentAsync.when(
            data: (env) => LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                if (compact) {
                  return Column(
                    children: [
                      _HeaderChip(
                        label: 'Weather',
                        value: '${env.weather.temperature.toStringAsFixed(1)} C',
                        icon: Icons.wb_sunny_outlined,
                      ),
                      const SizedBox(height: 12),
                      _HeaderChip(
                        label: 'AQI',
                        value: '${env.aqi.aqi}',
                        icon: Icons.air_rounded,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _HeaderChip(
                        label: 'Weather',
                        value: '${env.weather.temperature.toStringAsFixed(1)} C',
                        icon: Icons.wb_sunny_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeaderChip(
                        label: 'AQI',
                        value: '${env.aqi.aqi}',
                        icon: Icons.air_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
            loading: () => const _SkeletonCard(height: 64),
            error: (_, __) => const Text(
              'Weather and AQI unavailable right now',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeaderChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyStatusCard extends StatelessWidget {
  final BankSummary? bank;

  const _PolicyStatusCard({required this.bank});

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return '${value.day}/${value.month}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = bank?.policyStatus ?? 'NOT PURCHASED';
    final color = status == 'ACTIVE'
        ? AppTheme.successColor
        : status == 'EXPIRED'
            ? AppTheme.warningColor
            : AppTheme.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                bank?.claimReady == true ? 'Ready to claim' : (bank?.claimMessage ?? 'Not purchased'),
                softWrap: true,
                style: TextStyle(
                  color: bank?.claimReady == true
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Policy Period',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(bank?.policyStart)} -> ${_formatDate(bank?.policyEnd)}',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            bank?.claimMessage ?? 'Buy weekly insurance to activate claims',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final tileWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: tileWidth,
                child: _MetricTile('Earnings today', 'Rs ${today.earnings.toInt()}', Icons.currency_rupee_rounded),
              ),
              SizedBox(
                width: tileWidth,
                child: _MetricTile('Orders completed', '${today.ordersCompleted}', Icons.inventory_2_outlined),
              ),
              SizedBox(
                width: tileWidth,
                child: _MetricTile('Hours worked', today.hoursWorked.toStringAsFixed(1), Icons.schedule_rounded),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RiskSummaryCard extends StatelessWidget {
  final Map<String, dynamic> riskData;

  const _RiskSummaryCard({required this.riskData});

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final score = ((risk['risk_score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final recommendation = risk['recommendation'] as String? ?? 'No recommendation';
    final color = level == 'HIGH'
        ? AppTheme.errorColor
        : level == 'MEDIUM'
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  level,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
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
          const SizedBox(height: 10),
          Text(recommendation, style: const TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onBuyPolicy;
  final VoidCallback onClaim;
  final VoidCallback onConnectGig;
  final VoidCallback onVerify;

  const _QuickActions({
    required this.onBuyPolicy,
    required this.onClaim,
    required this.onConnectGig,
    required this.onVerify,
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
          icon: Icons.shield_outlined,
          title: 'Buy Weekly Insurance',
          subtitle: 'Activate 7-day policy cover',
          onTap: onBuyPolicy,
        ),
        _ActionCard(
          icon: Icons.payments_outlined,
          title: 'Claim Insurance',
          subtitle: 'Run claim precheck and payout flow',
          onTap: onClaim,
        ),
        _ActionCard(
          icon: Icons.link_rounded,
          title: 'Connect Gig Account',
          subtitle: 'Sync earnings and disruptions',
          onTap: onConnectGig,
        ),
        _ActionCard(
          icon: Icons.verified_user_outlined,
          title: 'Verify Identity',
          subtitle: 'Complete DigiLocker verification',
          onTap: onVerify,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile(this.label, this.value, this.icon);

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
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
}

class _InlineErrorCard extends StatelessWidget {
  final String message;
  const _InlineErrorCard(this.message);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      );
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
      );
}
