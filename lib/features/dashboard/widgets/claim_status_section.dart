import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';

class ClaimStatusSection extends StatelessWidget {
  final bool hasActiveClaim;
  final String? triggerReason;
  final String? payoutStatus;
  final double? payoutAmount;

  const ClaimStatusSection({
    Key? key,
    this.hasActiveClaim = false,
    this.triggerReason,
    this.payoutStatus,
    this.payoutAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim Status',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (!hasActiveClaim)
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                ),
                const SizedBox(width: 16),
                const Text(
                  'No Active Claim',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Claim Triggered',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${triggerReason ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Payout', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${payoutAmount?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: payoutStatus == 'Paid' 
                            ? AppTheme.successColor.withOpacity(0.1) 
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: payoutStatus == 'Paid' ? AppTheme.successColor : AppTheme.warningColor,
                        ),
                      ),
                      child: Text(
                        payoutStatus ?? 'Pending',
                        style: TextStyle(
                          color: payoutStatus == 'Paid' ? AppTheme.successColor : AppTheme.warningColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
