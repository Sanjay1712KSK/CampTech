import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/analytics_grid.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/claim_status_section.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/live_conditions_grid.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/premium_policy_row.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/risk_profile_card.dart';
import 'package:guidewire_gig_ins/features/dashboard/widgets/verification_status_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good Morning,',
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sanju 👋',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surfaceColor,
                    child: Icon(Icons.person, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Verification Status
              const VerificationStatusCard(isVerified: false), // Demo with true/false
              const SizedBox(height: 24),
              
              // Risk Profile
              const RiskProfileCard(riskScore: 'MEDIUM'),
              const SizedBox(height: 24),

              // Premium & Policy
              const PremiumPolicyRow(),
              const SizedBox(height: 32),

              // Live Conditions Grid
              const LiveConditionsGrid(),
              const SizedBox(height: 32),

              // Claim Trigger & Payout
              const ClaimStatusSection(
                hasActiveClaim: true,
                triggerReason: 'Heavy Traffic Disruption',
                payoutStatus: 'Pending',
                payoutAmount: 400.0,
              ),
              const SizedBox(height: 32),

              // Analytics Grid
              const AnalyticsGrid(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
