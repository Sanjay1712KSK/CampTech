import 'dart:math';

import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class IncomeIntelligenceScreen extends StatefulWidget {
  final int userId;

  const IncomeIntelligenceScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<IncomeIntelligenceScreen> createState() =>
      _IncomeIntelligenceScreenState();
}

class _IncomeIntelligenceScreenState extends State<IncomeIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _dataFuture;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.1, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      _dataFuture = Future.wait([
        ApiService.getBaselineIncome(widget.userId),
        ApiService.getTodayIncome(widget.userId),
        ApiService.getIncomeHistory(widget.userId),
      ]);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedSection({
    required Widget child,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: animatedChild),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _fetchData(),
          color: AppTheme.primaryColor,
          child: FutureBuilder<List<dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load insights.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      TextButton(
                        onPressed: _fetchData,
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final baseline = snapshot.data![0] as BaselineIncomeModel;
              final today = snapshot.data![1] as TodayIncomeModel;
              final history = snapshot.data![2] as IncomeHistoryModel;
              final lossAmount =
                  max(0.0, baseline.baselineDailyIncome - today.earnings);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedSection(
                      index: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Income Intelligence',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'AI-powered earnings breakdown',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                    _buildAnimatedSection(
                      index: 1,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: l10n.baselineIncome,
                              value:
                                  'Rs ${baseline.baselineDailyIncome.toInt()}',
                              icon: Icons.insights_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: l10n.todayIncome,
                              value: 'Rs ${today.earnings.toInt()}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (lossAmount > 0)
                      _buildAnimatedSection(
                        index: 2,
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.errorColor.withOpacity(
                                      _glowAnimation.value,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.trending_down_rounded,
                                    color: AppTheme.errorColor,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.lossIndicator,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.errorColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs ${lossAmount.toInt()} below baseline today',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (lossAmount > 0) const SizedBox(height: 32),
                    _buildAnimatedSection(
                      index: 3,
                      child: _WeeklyTrendChart(
                        history: history.records,
                        l10n: l10n,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (history.bestDay != null || history.worstDay != null) ...[
                      _buildAnimatedSection(
                        index: 4,
                        child: Text(
                          l10n.extremeDays,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (history.bestDay != null)
                        _buildAnimatedSection(
                          index: 5,
                          child: _ExtremeDayCard(
                            day: history.bestDay!,
                            title: l10n.bestDay,
                            isBest: true,
                            l10n: l10n,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (history.worstDay != null)
                        _buildAnimatedSection(
                          index: 6,
                          child: _ExtremeDayCard(
                            day: history.worstDay!,
                            title: l10n.worstDay,
                            isBest: false,
                            l10n: l10n,
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                    _buildAnimatedSection(
                      index: 7,
                      child: Text(
                        l10n.breakdown,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      index: 8,
                      child: _BreakdownGrid(today: today, l10n: l10n),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  final List<DailyRecord> history;
  final AppLocalizations l10n;

  const _WeeklyTrendChart({
    required this.history,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox();
    final maxEarning = history.map((e) => e.earnings).reduce(max);
    final recent = history.length > 7
        ? history.sublist(history.length - 7)
        : history;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weeklyTrend,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((record) {
                final heightFactor =
                    maxEarning == 0 ? 0.0 : (record.earnings / maxEarning);
                final label = _formatShortDate(record.date);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: heightFactor),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutBack,
                      builder: (ctx, val, child) {
                        return Container(
                          width: 24,
                          height: val * 120,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return rawDate;
    }
  }
}

class _ExtremeDayCard extends StatelessWidget {
  final DailyRecord day;
  final String title;
  final bool isBest;
  final AppLocalizations l10n;

  const _ExtremeDayCard({
    required this.day,
    required this.title,
    required this.isBest,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBest ? AppTheme.successColor : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBest
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                day.date,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(label: l10n.earnings, val: 'Rs ${day.earnings.toInt()}'),
              _MiniStat(label: l10n.orders, val: '${day.orders}'),
              if (day.weather != null)
                _MiniStat(
                  label: l10n.rainfall,
                  val: '${day.weather!.rainfall}mm',
                  icon: Icons.water_drop_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String val;
  final IconData? icon;

  const _MiniStat({
    required this.label,
    required this.val,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) Icon(icon, color: AppTheme.textSecondary, size: 14),
        if (icon == null)
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BreakdownGrid extends StatelessWidget {
  final TodayIncomeModel today;
  final AppLocalizations l10n;

  const _BreakdownGrid({
    required this.today,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final averageEarnings = today.ordersCompleted > 0
        ? (today.earnings / today.ordersCompleted)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: l10n.totalOrders, value: '${today.ordersCompleted}'),
          const Divider(color: Colors.white10, height: 24),
          _BreakdownRow(
            label: l10n.totalHours,
            value: '${today.hoursWorked} hrs',
          ),
          const Divider(color: Colors.white10, height: 24),
          _BreakdownRow(
            label: l10n.avgEarnings,
            value: 'Rs ${averageEarnings.toStringAsFixed(1)}',
          ),
          const Divider(color: Colors.white10, height: 24),
          _BreakdownRow(
            label: 'Disruption',
            value: today.disruptionType.toUpperCase(),
            valueColor: today.disruptionType == 'none'
                ? AppTheme.successColor
                : AppTheme.warningColor,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
