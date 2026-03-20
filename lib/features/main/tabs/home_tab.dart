import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with TickerProviderStateMixin {
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

  Future<void> _onRefresh() async {
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(baselineIncomeProvider);
    ref.invalidate(riskProvider);
    ref.invalidate(environmentProvider);
    // Wait for the main ones to reload
    await Future.wait([
      ref.read(todayIncomeProvider.future),
      ref.read(riskProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  String _getGreeting(AppLocalizations l10n) {
    final h = _now.hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  String get _formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String get _formattedTime {
    final h = _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final m = _now.minute.toString().padLeft(2, '0');
    final p = _now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  Widget _buildAnimatedSection({required Widget child, required int index}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(userProvider);
    
    if (l10n == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final todayAsync = ref.watch(todayIncomeProvider);
    final riskAsync = ref.watch(riskProvider);
    final baselineAsync = ref.watch(baselineIncomeProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              _buildAnimatedSection(
                index: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_getGreeting(l10n)},', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('${user.userName} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        Text('$_formattedDate  •  $_formattedTime', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.surfaceColor,
                      child: Text(
                        user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Verification Card ──────────────────────────────
              _buildAnimatedSection(
                index: 1,
                child: _VerificationStatusCard(isVerified: user.isVerified),
              ),
              const SizedBox(height: 16),

              // ── Risk Card ──────────────────────────────────────
              _buildAnimatedSection(
                index: 2,
                child: riskAsync.when(
                  data: (data) => _RiskCard(data: data),
                  loading: () => _buildSkeletonCard(80),
                  error: (e, _) => _buildErrorCard('Failed to load risk data'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Today Summary & Baseline Row ───────────────────
              _buildAnimatedSection(
                index: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: todayAsync.when(
                        data: (data) => _TodaySummaryCard(today: data),
                        loading: () => _buildSkeletonCard(180),
                        error: (e, _) => _buildErrorCard('Failed to load today data'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: baselineAsync.when(
                        data: (data) => _BaselineCard(baseline: data, today: todayAsync.value),
                        loading: () => _buildSkeletonCard(180),
                        error: (e, _) => _buildErrorCard('Error'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.2, end: 0.6),
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
          builder: (ctx, val, child) => Opacity(opacity: val, child: Container(height: 20, width: 40, color: Colors.white24)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(child: Text(error, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _VerificationStatusCard extends StatelessWidget {
  final bool isVerified;
  const _VerificationStatusCard({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isVerified ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isVerified ? 'DigiLocker Verified' : 'Not Verified \u274c', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                if (isVerified)
                  const Text('Blockchain Secured \uD83D\uDD17', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (!isVerified)
                  const Text('Complete KYC to trigger automated claims', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () {}, // Handled in Profile Tab or modal
              style: TextButton.styleFrom(backgroundColor: color.withOpacity(0.2)),
              child: Text('Verify', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            )
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RiskCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String level = (data['risk_level'] as String?)?.toUpperCase() ?? 'UNKNOWN';
    final double score = (data['risk_score'] as num?)?.toDouble() ?? 0.0;
    final String rec = data['recommendation'] as String? ?? 'Analysis unavailable';

    Color c;
    if (level == 'HIGH') c = AppTheme.errorColor;
    else if (level == 'MEDIUM') c = AppTheme.warningColor;
    else c = AppTheme.successColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.5)),
        boxShadow: level == 'HIGH' ? [BoxShadow(color: c.withOpacity(0.3), blurRadius: 20)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Risk Score', style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(level, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(score.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(rec, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final today; // TodayIncomeModel
  const _TodaySummaryCard({required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          const Text('Today', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('₹${today.actualEarnings.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _RowStat(label: 'Orders', val: '${today.actualOrders}'),
          const SizedBox(height: 8),
          _RowStat(label: 'Hours', val: '${today.activeHours}h'),
        ],
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  final baseline; // BaselineIncomeModel
  final today;    // TodayIncomeModel?
  const _BaselineCard({required this.baseline, this.today});

  @override
  Widget build(BuildContext context) {
    final expected = baseline.expectedEarnings;
    final diff = today != null ? (today.actualEarnings - expected) : 0.0;
    final isLoss = diff < 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_rounded, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('Baseline', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('₹${expected.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isLoss ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isLoss ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, 
                     color: isLoss ? AppTheme.errorColor : AppTheme.successColor, size: 14),
                const SizedBox(width: 4),
                Text('₹${diff.abs().toInt()}', 
                     style: TextStyle(color: isLoss ? AppTheme.errorColor : AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _RowStat extends StatelessWidget {
  final String label;
  final String val;
  const _RowStat({required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
      ],
    );
  }
}
