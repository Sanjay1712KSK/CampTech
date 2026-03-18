import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/glass_card.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';

class VerificationStatusCard extends StatelessWidget {
  final bool isVerified;

  const VerificationStatusCard({Key? key, this.isVerified = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    isVerified ? 'Verified' : 'Not Verified',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isVerified ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isVerified ? Icons.check_circle : Icons.cancel,
                    color: isVerified ? AppTheme.successColor : AppTheme.errorColor,
                    size: 20,
                  ),
                ],
              ),
              if (isVerified) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'DigiLocker Verified',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.link, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Blockchain Secured',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (!isVerified)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DigilockerVerificationScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Verify Identity'),
            ),
        ],
      ),
    );
  }
}
