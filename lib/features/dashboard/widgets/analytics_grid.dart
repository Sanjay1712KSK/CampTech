import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';

class AnalyticsGrid extends StatelessWidget {
  const AnalyticsGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AnalyticsCard(
                title: 'Orders',
                value: '142',
                icon: Icons.delivery_dining,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnalyticsCard(
                title: 'Active Hrs',
                value: '48.5',
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AnalyticsCard(
                title: 'Risk Days',
                value: '3',
                icon: Icons.warning_amber_rounded,
                isHighlight: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnalyticsCard(
                title: 'Earnings Impact',
                value: '+8%',
                icon: Icons.trending_up,
                valueColor: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isHighlight;
  final Color? valueColor;

  const _AnalyticsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.isHighlight = false,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      highlighted: isHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: isHighlight ? Colors.black : AppTheme.textSecondary),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isHighlight ? Colors.black87 : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isHighlight ? Colors.black : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
