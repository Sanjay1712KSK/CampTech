import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';

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

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late DateTime _now;
  late Timer _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _getGreeting(AppLocalizations l10n) {
    final h = _now.hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
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

  Widget _buildAnimatedSection({required Widget child, required int index}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wait until localizations map is available
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                      '${_getGreeting(l10n)},',
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
                        _WeatherChip(icon: Icons.water_drop_outlined, label: l10n.rain, color: Colors.blueAccent),
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
                _buildAnimatedSection(
                  index: 0,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    ),
                    child: _DashCard(
                      icon: Icons.speed_rounded,
                      title: l10n.riskLevel,
                      value: 'HIGH',
                      valueColor: AppTheme.errorColor,
                      highlighted: false,
                    ),
                  ),
                ),
                _buildAnimatedSection(
                  index: 1,
                  child: _DashCard(
                    icon: Icons.wallet_rounded,
                    title: l10n.weeklyPremium,
                    value: '₹120',
                    highlighted: true,
                  ),
                ),
                _buildAnimatedSection(
                  index: 2,
                  child: _DashCard(
                    icon: Icons.policy_rounded,
                    title: l10n.policyStatus,
                    value: l10n.activePolicy,
                    valueColor: AppTheme.successColor,
                    sub: 'POL-391X',
                  ),
                ),
                _buildAnimatedSection(
                  index: 3,
                  child: _DashCard(
                    icon: Icons.verified_user_rounded,
                    title: l10n.verification,
                    value: widget.isVerified ? l10n.verified : l10n.notVerified,
                    valueColor: widget.isVerified ? AppTheme.successColor : AppTheme.errorColor,
                    actionLabel: widget.isVerified ? null : '${l10n.verifyNow} →',
                    onAction: widget.isVerified ? null : () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DigilockerVerificationScreen(userId: widget.userId),
                      ));
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Live Status Strip ────────────────────────────────────
            _buildAnimatedSection(
              index: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _StatusChip(icon: Icons.cloudy_snowing, label: l10n.rain, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    _StatusChip(icon: Icons.traffic_rounded, label: l10n.trafficHeavy, color: AppTheme.errorColor),
                    const SizedBox(width: 12),
                    _StatusChip(icon: Icons.shield_moon_rounded, label: l10n.riskMed, color: AppTheme.warningColor),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(l10n.liveStatus, style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Claim Alert ──────────────────────────────────────────
            _buildAnimatedSection(
              index: 5,
              child: Container(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.claimTriggered, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(l10n.trafficHeavy, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('₹400', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(l10n.pending, style: const TextStyle(fontSize: 11, color: AppTheme.warningColor)),
                      ],
                    ),
                  ],
                ),
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

class _DashCard extends StatefulWidget {
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
  State<_DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<_DashCard> {
  bool _isPressed = false;

  void _handleTapDown(_) => setState(() => _isPressed = true);
  void _handleTapUp(_) => setState(() => _isPressed = false);
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final bg = widget.highlighted ? AppTheme.primaryColor : AppTheme.surfaceColor;
    final fg = widget.highlighted ? Colors.black : AppTheme.textPrimary;
    final fgSub = widget.highlighted ? Colors.black54 : AppTheme.textSecondary;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onAction,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (widget.highlighted ? AppTheme.primaryColor : Colors.black).withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (widget.value == 'HIGH')
                BoxShadow(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(widget.icon, size: 18, color: widget.highlighted ? Colors.black : AppTheme.primaryColor),
                  if (widget.actionLabel != null)
                    Text(widget.actionLabel!, style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              Text(
                widget.value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.valueColor ?? fg),
              ),
              const SizedBox(height: 2),
              if (widget.sub != null)
                Text(widget.sub!, style: TextStyle(fontSize: 10, color: fgSub)),
              Text(widget.title, style: TextStyle(fontSize: 11, color: fgSub)),
            ],
          ),
        ),
      ),
    );
  }
}
