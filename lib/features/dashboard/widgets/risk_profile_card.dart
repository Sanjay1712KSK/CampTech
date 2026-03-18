import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';

class RiskProfileCard extends StatelessWidget {
  final String riskScore;

  const RiskProfileCard({Key? key, required this.riskScore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      highlighted: true, // Neon highlight
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Risk Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.speed, color: Colors.black.withOpacity(0.7)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            riskScore.toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on weather, AQI, and traffic',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
