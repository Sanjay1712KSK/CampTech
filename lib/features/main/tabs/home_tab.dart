import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
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

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late DateTime _now;
  late Timer _timer;
  
  // Environment State
  Future<EnvironmentModel>? _envFuture;

  // Single Animation Controller for Glows
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fetchEnvironment();
  }

  void _fetchEnvironment() {
    setState(() {
      // Chennai coordinates as example
      _envFuture = ApiService.getEnvironment(13.0827, 80.2707);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _glowController.dispose();
    super.dispose();
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
      duration: const Duration(milliseconds: 600),
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
    if (l10n == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _fetchEnvironment(),
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_getGreeting(l10n)},', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('${widget.userName} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Text('$_formattedDate  •  $_formattedTime', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
              const SizedBox(height: 32),

              const Text('Environment Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // ── Environment Grid ───────────────────────────────
              FutureBuilder<EnvironmentModel>(
                future: _envFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerGrid();
                  } else if (snapshot.hasError || !snapshot.hasData) {
                    return _buildErrorState(l10n);
                  }

                  final env = snapshot.data!;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                    children: [
                      _buildAnimatedSection(index: 0, child: _WeatherCard(env.weather, l10n)),
                      _buildAnimatedSection(index: 1, child: _AqiCard(env.aqi, l10n, _glowAnimation)),
                      _buildAnimatedSection(index: 2, child: _TrafficCard(env.traffic, l10n, _glowAnimation)),
                      _buildAnimatedSection(index: 3, child: _ContextCard(env.context, l10n, _formattedTime)),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Claim Alert (Retained) ─────────────────────────
              _buildAnimatedSection(
                index: 4,
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
                            Text(l10n.claims, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(l10n.pending, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹400', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.2, end: 0.6),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (ctx, val, child) {
                return Opacity(
                  opacity: val,
                  child: Container(
                    height: 20,
                    width: 60,
                    color: Colors.white24,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.textSecondary, size: 32),
          const SizedBox(height: 12),
          const Text('Failed to load environment.', style: TextStyle(color: AppTheme.textSecondary)),
          TextButton(onPressed: _fetchEnvironment, child: const Text('Retry', style: TextStyle(color: AppTheme.primaryColor)))
        ],
      ),
    );
  }
}

// ── Environment Components ──────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final WeatherData w;
  final AppLocalizations l10n;
  const _WeatherCard(this.w, this.l10n);

  @override
  Widget build(BuildContext context) {
    final rain = w.rainfall > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(rain ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                  color: rain ? Colors.blueAccent : AppTheme.primaryColor, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: rain ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Text('${w.rainfall}mm', style: TextStyle(fontSize: 10, color: rain ? Colors.blueAccent : AppTheme.textSecondary)),
              )
            ],
          ),
          const Spacer(),
          Text('${w.temperature}°C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${l10n.windSpeed}: ${w.windSpeed}km/h', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AqiCard extends StatelessWidget {
  final AqiData aqi;
  final AppLocalizations l10n;
  final Animation<double> glow;
  const _AqiCard(this.aqi, this.l10n, this.glow);

  @override
  Widget build(BuildContext context) {
    Color c; String label;
    if (aqi.aqi <= 2) { c = AppTheme.successColor; label = l10n.good; }
    else if (aqi.aqi == 3) { c = AppTheme.warningColor; label = l10n.moderate; }
    else { c = AppTheme.errorColor; label = l10n.poor; }

    return AnimatedBuilder(
      animation: glow,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: c.withOpacity(glow.value * 0.4), blurRadius: 16, spreadRadius: 0)],
          border: Border.all(color: c.withOpacity(0.3)),
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.air_rounded, color: c, size: 20),
              Text(l10n.aqiValue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          Text('${aqi.aqi}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  final TrafficData t;
  final AppLocalizations l10n;
  final Animation<double> glow;
  const _TrafficCard(this.t, this.l10n, this.glow);

  @override
  Widget build(BuildContext context) {
    Color c; String msg;
    if (t.trafficLevel == 'HIGH') { c = AppTheme.errorColor; msg = l10n.heavyCongestion; }
    else if (t.trafficLevel == 'MEDIUM') { c = AppTheme.warningColor; msg = l10n.moderateTraffic; }
    else { c = AppTheme.successColor; msg = l10n.smoothTraffic; }

    return AnimatedBuilder(
      animation: glow,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: c.withOpacity(glow.value * 0.4), blurRadius: 16, spreadRadius: 0)],
          border: Border.all(color: c.withOpacity(0.3)),
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.traffic_rounded, color: c, size: 20),
              Text(l10n.trafficLevel, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          Text(t.trafficLevel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 2),
          Text(msg, style: TextStyle(fontSize: 10, color: c)),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final ContextData ctx;
  final AppLocalizations l10n;
  final String formattedTime;
  const _ContextCard(this.ctx, this.l10n, this.formattedTime);

  @override
  Widget build(BuildContext context) {
    final isWeekend = ctx.dayType.toLowerCase() == 'weekend';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWeekend ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: 20),
            ],
          ),
          const Spacer(),
          Text(formattedTime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(isWeekend ? l10n.weekend : l10n.weekday, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
