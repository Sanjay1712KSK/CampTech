import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final historyAsync = ref.watch(incomeHistoryProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(incomeHistoryProvider);
            ref.invalidate(baselineIncomeProvider);
          },
          child: historyAsync.when(
            data: (history) => baselineAsync.when(
              data: (baseline) => _EarningsContent(
                history: history,
                baseline: baseline,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _InlineState(message: 'Unable to load baseline'),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _EmptyState(
              onConnect: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectGigScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EarningsContent extends StatelessWidget {
  final IncomeHistoryModel history;
  final BaselineIncomeModel baseline;

  const _EarningsContent({
    required this.history,
    required this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final records = history.records.length > 7
        ? history.records.sublist(history.records.length - 7)
        : history.records;
    final highest = history.bestDay;
    final lowest = history.worstDay;
    final maxEarnings = records.isEmpty
        ? 0.0
        : records.map((e) => e.earnings).reduce(max);
    final totalRainLoss = records.fold<double>(
      0.0,
      (sum, item) => sum +
          ((item.disruptionType == 'rain')
              ? max(0.0, baseline.baselineDailyIncome - item.earnings)
              : 0.0),
    );
    final trafficDays =
        records.where((item) => item.traffic?.trafficLevel == 'HIGH').length;
    final trafficDrop = records.isEmpty ? 0.0 : (trafficDays / records.length) * 20;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings Intelligence',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _CardBlock(
            title: 'Weekly Earnings Chart',
            child: records.isEmpty
                ? const Text('No earnings data yet', style: TextStyle(color: AppTheme.textSecondary))
                : SizedBox(
                    height: 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: records.map((record) {
                        final height = maxEarnings == 0 ? 0.0 : record.earnings / maxEarnings;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs ${record.earnings.toInt()}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: max(18, height * 120),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.date.substring(5),
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (highest != null)
                Expanded(
                  child: _ContextCard(
                    title: 'Highest Earning Day',
                    amount: highest.earnings,
                    weather: highest.weather?.rainfall != null
                        ? '${highest.weather!.rainfall.toStringAsFixed(1)} mm rain'
                        : 'Clear weather',
                    traffic: highest.traffic?.trafficLevel ?? 'Unknown traffic',
                    disruption: highest.disruptionType ?? 'none',
                    color: AppTheme.successColor,
                  ),
                ),
              if (highest != null && lowest != null) const SizedBox(width: 12),
              if (lowest != null)
                Expanded(
                  child: _ContextCard(
                    title: 'Lowest Earning Day',
                    amount: lowest.earnings,
                    weather: lowest.weather?.rainfall != null
                        ? '${lowest.weather!.rainfall.toStringAsFixed(1)} mm rain'
                        : 'Clear weather',
                    traffic: lowest.traffic?.trafficLevel ?? 'Unknown traffic',
                    disruption: lowest.disruptionType ?? 'none',
                    color: AppTheme.errorColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _CardBlock(
            title: 'Loss Insight',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You lost Rs ${totalRainLoss.toStringAsFixed(0)} due to rain',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Traffic caused ${trafficDrop.toStringAsFixed(0)}% drop in peak-day efficiency.',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
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

class _ContextCard extends StatelessWidget {
  final String title;
  final double amount;
  final String weather;
  final String traffic;
  final String disruption;
  final Color color;

  const _ContextCard({
    required this.title,
    required this.amount,
    required this.weather,
    required this.traffic,
    required this.disruption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Rs ${amount.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(weather, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(traffic, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('Disruption: ${disruption.toUpperCase()}',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onConnect;

  const _EmptyState({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Connect your gig account to unlock earnings intelligence',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Weekly charts, disruption analysis, and highest/lowest earning days will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onConnect,
              child: const Text('Connect Gig Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  final String message;

  const _InlineState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      );
}
