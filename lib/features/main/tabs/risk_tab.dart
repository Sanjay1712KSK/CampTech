import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class RiskTab extends ConsumerWidget {
  const RiskTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envAsync = ref.watch(environmentProvider);
    final riskAsync = ref.watch(riskProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(environmentProvider);
            ref.invalidate(riskProvider);
            await Future.wait([
              ref.read(environmentProvider.future),
              ref.read(riskProvider.future),
            ]).catchError((_) => <Object>[]);
          },
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Risk Analysis', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text('Real-time environmental risk breakdown', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 32),

                // ── Section 1: Environment ─────────────────────────
                const Text('Environment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                envAsync.when(
                  data: (data) => _buildEnvironmentRow(data),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
                ),

                const SizedBox(height: 40),

                // ── Section 2: Recommendation ─────────────────────
                const Text('Recommendation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                riskAsync.when(
                  data: (data) => _buildRecommendationCard(data),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
                ),

                const SizedBox(height: 40),

                // ── Section 3: Risk Breakdown ─────────────────────
                const Text('Risk Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                riskAsync.when(
                  data: (data) => _buildRiskProgressBars(data),
                  loading: () => const SizedBox(),
                  error: (e, _) => const SizedBox(),
                ),

                const SizedBox(height: 80), // bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentRow(EnvironmentModel env) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _EnvMiniCard(icon: Icons.thermostat_rounded, val: '${env.weather.temperature}°C', label: 'Temp'),
        _EnvMiniCard(icon: Icons.water_drop_rounded, val: '${env.weather.humidity}%', label: 'Humid'),
        _EnvMiniCard(icon: Icons.air_rounded, val: '${env.weather.windSpeed}', label: 'Wind'),
        _EnvMiniCard(icon: Icons.masks_rounded, val: '${env.aqi.aqi}', label: 'AQI'),
        _EnvMiniCard(icon: Icons.traffic_rounded, val: env.traffic.trafficLevel, label: 'Traffic'),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> riskRaw) {
    final String level = (riskRaw['risk_level'] as String?)?.toUpperCase() ?? 'UNKNOWN';
    final String rec = riskRaw['recommendation'] as String? ?? 'Analysis unavailable';

    Color c;
    String statusTitle;
    IconData statusIcon;

    if (level == 'HIGH') {
      c = AppTheme.errorColor;
      statusTitle = 'Avoid Delivery';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'MEDIUM') {
      c = AppTheme.warningColor;
      statusTitle = 'Caution Advised';
      statusIcon = Icons.error_outline_rounded;
    } else {
      c = AppTheme.successColor;
      statusTitle = 'Safe to Deliver';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: c, size: 36),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusTitle, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(rec, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRiskProgressBars(Map<String, dynamic> riskRaw) {
    // Synthesize breakdown percentages. (If API provides details, map them. Otherwise, synthetic logic for demo based on score).
    final double score = (riskRaw['risk_score'] as num?)?.toDouble() ?? 0.0;
    
    // Fallback logic for visual demo if API doesn't provide fine-grain breakdown
    final double wFactor = (score * 0.4).clamp(0, 100);
    final double aFactor = (score * 0.3).clamp(0, 100);
    final double tFactor = (score * 0.2).clamp(0, 100);
    final double timeFactor = (score * 0.1).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _RiskProgressBar(label: 'Weather Risk', percentage: wFactor / 100),
          const SizedBox(height: 20),
          _RiskProgressBar(label: 'AQI Risk', percentage: aFactor / 100),
          const SizedBox(height: 20),
          _RiskProgressBar(label: 'Traffic Risk', percentage: tFactor / 100),
          const SizedBox(height: 20),
          _RiskProgressBar(label: 'Time Risk', percentage: timeFactor / 100),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _EnvMiniCard extends StatelessWidget {
  final IconData icon;
  final String val;
  final String label;

  const _EnvMiniCard({required this.icon, required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _RiskProgressBar extends StatelessWidget {
  final String label;
  final double percentage; // 0.0 to 1.0
  const _RiskProgressBar({required this.label, required this.percentage});

  @override
  Widget build(BuildContext context) {
    Color pc;
    if (percentage > 0.7) pc = AppTheme.errorColor;
    else if (percentage > 0.4) pc = AppTheme.warningColor;
    else pc = AppTheme.successColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            Text('${(percentage * 100).toInt()}%', style: TextStyle(fontSize: 12, color: pc, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (ctx, val, child) {
              return LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(pc),
              );
            },
          ),
        ),
      ],
    );
  }
}
