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
    final historyAsync = ref.watch(incomeHistoryProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(incomeHistoryProvider);
            ref.invalidate(baselineIncomeProvider);
            ref.invalidate(todayIncomeProvider);
          },
          child: historyAsync.when(
            data: (history) => baselineAsync.when(
              data: (baseline) => _EarningsContent(history: history, baseline: baseline),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InlineState(message: error.toString()),
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
    final records = history.records;
    final lastSeven = records.length > 7 ? records.sublist(records.length - 7) : records;
    final weeklyBuckets = _weeklyBuckets(records);
    final avgIncome = records.isEmpty
        ? 0.0
        : records.fold<double>(0.0, (sum, item) => sum + item.earnings) / records.length;
    final bestDay = history.bestDay;
    final disruptionDays = records.where((item) => (item.disruptionType ?? 'none') != 'none').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const _HeaderBlock(
          title: 'Earnings',
          subtitle: 'Understand how your work pattern and disruptions affect what you take home.',
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Daily earnings trend',
          subtitle: 'Line view of your latest earnings pattern.',
          child: records.isEmpty
              ? const _SmallEmpty('No earnings data available yet')
              : Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: _LineChart(records: lastSeven),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Daily earnings',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Weekly earnings',
          subtitle: 'Bar view of weekly totals to make patterns easier to spot.',
          child: weeklyBuckets.isEmpty
              ? const _SmallEmpty('Weekly totals will appear after more income history is available')
              : SizedBox(
                  height: 180,
                  child: _BarChart(values: weeklyBuckets),
                ),
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Orders vs income',
          subtitle: 'Compare how order volume relates to what you earned.',
          child: records.isEmpty
              ? const _SmallEmpty('Orders and income comparison is not available yet')
              : SizedBox(
                  height: 200,
                  child: _OrdersIncomeChart(records: lastSeven),
                ),
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Insights',
          subtitle: 'Simple takeaways from your work patterns.',
          child: Column(
            children: [
              _StatRow(label: 'Average daily income', value: '₹ ${avgIncome.toStringAsFixed(0)}'),
              _StatRow(
                label: 'Best earning day',
                value: bestDay == null ? '--' : '${bestDay.date}  •  ₹ ${bestDay.earnings.toStringAsFixed(0)}',
              ),
              _StatRow(label: 'Days with drop patterns', value: '$disruptionDays days'),
              _StatRow(label: 'Baseline daily income', value: '₹ ${baseline.baselineDailyIncome.toStringAsFixed(0)}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'ML-powered help',
          subtitle: '🤖 Personalized insights based on your work patterns',
          child: const Text(
            'These income patterns help the system understand your usual earning rhythm, so risk, premium, and claim decisions stay connected to your real work.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }

  List<double> _weeklyBuckets(List<DailyRecord> records) {
    if (records.isEmpty) return [];
    final sorted = [...records];
    sorted.sort((a, b) => a.date.compareTo(b.date));
    final buckets = <double>[];
    for (var index = 0; index < sorted.length; index += 7) {
      final chunk = sorted.skip(index).take(7);
      buckets.add(chunk.fold<double>(0.0, (sum, item) => sum + item.earnings));
    }
    return buckets;
  }
}

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderBlock({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallEmpty extends StatelessWidget {
  final String message;

  const _SmallEmpty(this.message);

  @override
  Widget build(BuildContext context) {
    return Text(message, style: const TextStyle(color: AppTheme.textSecondary));
  }
}

class _LineChart extends StatelessWidget {
  final List<DailyRecord> records;

  const _LineChart({required this.records});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(records),
      child: Container(),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> values;

  const _BarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce(max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.asMap().entries.map((entry) {
        final value = entry.value;
        final heightFactor = maxValue == 0 ? 0.0 : value / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Container(
                  height: max(22, heightFactor * 120),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'W${entry.key + 1}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OrdersIncomeChart extends StatelessWidget {
  final List<DailyRecord> records;

  const _OrdersIncomeChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final maxOrders = records.fold<int>(1, (maxValue, item) => max(maxValue, item.orders));
    final maxIncome = records.fold<double>(1.0, (maxValue, item) => max(maxValue, item.earnings));
    return Column(
      children: records.map((record) {
        final ordersFactor = record.orders / maxOrders;
        final incomeFactor = record.earnings / maxIncome;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.date,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 58, child: Text('Orders', style: TextStyle(color: AppTheme.textSecondary))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: ordersFactor,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      color: AppTheme.warningColor,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${record.orders}', style: const TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 58, child: Text('Income', style: TextStyle(color: AppTheme.textSecondary))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: incomeFactor,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      color: AppTheme.primaryColor,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('₹${record.earnings.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DailyRecord> records;

  _LineChartPainter(this.records);

  @override
  void paint(Canvas canvas, Size size) {
    if (records.length < 2) return;

    final maxIncome = records.map((item) => item.earnings).reduce(max);
    final minIncome = records.map((item) => item.earnings).reduce(min);
    final range = max(maxIncome - minIncome, 1.0);

    final linePaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = AppTheme.primaryColor;
    final path = Path();

    for (var i = 0; i < records.length; i++) {
      final x = (size.width / (records.length - 1)) * i;
      final y = size.height - (((records[i].earnings - minIncome) / range) * (size.height - 20)) - 10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.records != records;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onConnect;

  const _EmptyState({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor, size: 72),
                  const SizedBox(height: 18),
                  const Text(
                    'Connect your gig account to view earnings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Daily trends, weekly summaries, and work pattern insights will appear here after you connect your delivery account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onConnect,
                    child: const Text('Connect Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineState extends StatelessWidget {
  final String message;

  const _InlineState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
