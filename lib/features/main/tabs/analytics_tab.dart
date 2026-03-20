import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your performance overview', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 28),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.2,
              children: const [
                _AnalyticsCard(icon: Icons.currency_rupee_rounded, title: 'Earnings Protected', value: '₹3,200', highlighted: true),
                _AnalyticsCard(icon: Icons.calendar_today_rounded, title: 'Risk Days', value: '7 Days', valueColor: AppTheme.warningColor),
                _AnalyticsCard(icon: Icons.trending_up_rounded, title: 'Income Covered', value: '₹1,800', valueColor: AppTheme.successColor),
                _AnalyticsCard(icon: Icons.show_chart_rounded, title: 'Weekly Trend', value: '+12%', valueColor: AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _BreakdownRow(label: 'Orders Completed', value: '142', percent: 0.71),
            const SizedBox(height: 14),
            _BreakdownRow(label: 'Active Hours', value: '48.5 hrs', percent: 0.56),
            const SizedBox(height: 14),
            _BreakdownRow(label: 'Risk Coverage Used', value: '3 / 7 days', percent: 0.43),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool highlighted;
  final Color? valueColor;

  const _AnalyticsCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.highlighted = false,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? AppTheme.primaryColor : AppTheme.surfaceColor;
    final fg = highlighted ? Colors.black : AppTheme.textPrimary;
    final fgSub = highlighted ? Colors.black54 : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: highlighted ? Colors.black : AppTheme.primaryColor),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor ?? fg)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: fgSub)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final double percent;

  const _BreakdownRow({Key? key, required this.label, required this.value, required this.percent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppTheme.backgroundColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
