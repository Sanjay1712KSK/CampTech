import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class LiveConditionsGrid extends StatelessWidget {
  const LiveConditionsGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Conditions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ConditionItem(icon: Icons.cloudy_snowing, label: 'Rain', color: Colors.blueAccent),
            _ConditionItem(icon: Icons.air, label: 'AQI: Mod', color: AppTheme.warningColor),
            _ConditionItem(icon: Icons.traffic, label: 'Heavy Traffic', color: AppTheme.errorColor),
          ],
        ),
      ],
    );
  }
}

class _ConditionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ConditionItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 48 - 32) / 3, // 48 margins, 32 spacing
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
