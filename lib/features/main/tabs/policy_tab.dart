import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class PolicyTab extends StatelessWidget {
  const PolicyTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Policy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your active insurance coverage', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 28),

            // ── Big Policy Card ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C2C2C), Color(0xFF1E1E1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ACTIVE POLICY', style: TextStyle(letterSpacing: 1.5, fontSize: 11, color: AppTheme.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('● Active', style: TextStyle(fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('POL-391X', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Income Protection Plan', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const Divider(height: 32, color: Color(0xFF333333)),
                  _PolicyField(label: 'Weekly Premium', value: '₹120'),
                  const SizedBox(height: 16),
                  _PolicyField(label: 'Coverage Type', value: 'Income Protection'),
                  const SizedBox(height: 16),
                  _PolicyField(label: 'Risk Basis', value: 'Weather + AQI + Traffic'),
                  const SizedBox(height: 16),
                  _PolicyField(label: 'Auto-Adjusted', value: 'Yes — Real-time AI'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Coverage Breakdown ──────────────────────────────────
            const Text('Coverage Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _CoverageRow(label: 'Rain Disruption', covered: true),
            const SizedBox(height: 10),
            _CoverageRow(label: 'AQI Spike', covered: true),
            const SizedBox(height: 10),
            _CoverageRow(label: 'Traffic Disruption', covered: true),
            const SizedBox(height: 10),
            _CoverageRow(label: 'Accident Coverage', covered: false),
          ],
        ),
      ),
    );
  }
}

class _PolicyField extends StatelessWidget {
  final String label;
  final String value;
  const _PolicyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  final String label;
  final bool covered;
  const _CoverageRow({required this.label, required this.covered});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(covered ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: covered ? AppTheme.successColor : AppTheme.errorColor, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(covered ? 'Covered' : 'Not Covered',
              style: TextStyle(fontSize: 11, color: covered ? AppTheme.successColor : AppTheme.errorColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
