import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';

class HomeTab extends StatefulWidget {
  final int userId;
  final bool isVerified;
  final String userName;

  const HomeTab({
    Key? key,
    required this.userId,
    this.isVerified = false,
    this.userName = 'User',
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _formattedDate {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String get _formattedTime {
    final h = _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final m = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting,',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.userName} 👋',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_formattedDate  •  $_formattedTime',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _WeatherChip(icon: Icons.water_drop_outlined, label: 'Rain', color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        _WeatherChip(icon: Icons.air, label: 'AQI: Mod', color: AppTheme.warningColor),
                      ],
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.surfaceColor,
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── 2x2 Card Grid ────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.35,
              children: [
                _DashCard(
                  icon: Icons.speed_rounded,
                  title: 'Risk Level',
                  value: 'MEDIUM',
                  valueColor: AppTheme.warningColor,
                  highlighted: false,
                ),
                _DashCard(
                  icon: Icons.wallet_rounded,
                  title: 'Weekly Premium',
                  value: '₹120',
                  highlighted: true,
                ),
                _DashCard(
                  icon: Icons.policy_rounded,
                  title: 'Policy Status',
                  value: 'Active',
                  valueColor: AppTheme.successColor,
                  sub: 'POL-391X',
                ),
                _DashCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Verification',
                  value: widget.isVerified ? 'Verified ✔' : 'Not Verified',
                  valueColor: widget.isVerified ? AppTheme.successColor : AppTheme.errorColor,
                  actionLabel: widget.isVerified ? null : 'Verify →',
                  onAction: widget.isVerified ? null : () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DigilockerVerificationScreen(userId: widget.userId),
                    ));
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Live Status Strip ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _StatusChip(icon: Icons.cloudy_snowing, label: 'Rain', color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  _StatusChip(icon: Icons.traffic_rounded, label: 'Heavy', color: AppTheme.errorColor),
                  const SizedBox(width: 12),
                  _StatusChip(icon: Icons.shield_moon_rounded, label: 'Risk: Med', color: AppTheme.warningColor),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Live', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Claim Alert ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Claim Triggered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Heavy Traffic Disruption', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('₹400', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Pending', style: TextStyle(fontSize: 11, color: AppTheme.warningColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ────────────────────────────────────────────────────

class _WeatherChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _WeatherChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? sub;
  final Color? valueColor;
  final bool highlighted;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _DashCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.sub,
    this.valueColor,
    this.highlighted = false,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? AppTheme.primaryColor : AppTheme.surfaceColor;
    final fg = highlighted ? Colors.black : AppTheme.textPrimary;
    final fgSub = highlighted ? Colors.black54 : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (highlighted ? AppTheme.primaryColor : Colors.black).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: highlighted ? Colors.black : AppTheme.primaryColor),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(actionLabel!, style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? fg),
          ),
          const SizedBox(height: 2),
          if (sub != null)
            Text(sub!, style: TextStyle(fontSize: 10, color: fgSub)),
          Text(title, style: TextStyle(fontSize: 11, color: fgSub)),
        ],
      ),
    );
  }
}
