import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class ClaimsTab extends StatelessWidget {
  const ClaimsTab({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _claims = [
    {'status': 'Triggered', 'reason': 'Rain Disruption', 'amount': '₹400', 'date': '18 Mar', 'isPaid': false},
    {'status': 'Paid', 'reason': 'AQI Spike', 'amount': '₹250', 'date': '12 Mar', 'isPaid': true},
    {'status': 'Paid', 'reason': 'Traffic Disruption', 'amount': '₹350', 'date': '05 Mar', 'isPaid': true},
    {'status': 'Pending', 'reason': 'Heavy Rain', 'amount': '₹180', 'date': '28 Feb', 'isPaid': false},
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Claims', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your claim history', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 28),
            ..._claims.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ClaimCard(
                status: c['status'] as String,
                reason: c['reason'] as String,
                amount: c['amount'] as String,
                date: c['date'] as String,
                isPaid: c['isPaid'] as bool,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final String status;
  final String reason;
  final String amount;
  final String date;
  final bool isPaid;

  const _ClaimCard({
    Key? key,
    required this.status,
    required this.reason,
    required this.amount,
    required this.date,
    required this.isPaid,
  }) : super(key: key);

  Color get _statusColor {
    switch (status) {
      case 'Paid': return AppTheme.successColor;
      case 'Triggered': return AppTheme.warningColor;
      default: return AppTheme.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'Paid': return Icons.check_circle_rounded;
      case 'Triggered': return Icons.warning_amber_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
