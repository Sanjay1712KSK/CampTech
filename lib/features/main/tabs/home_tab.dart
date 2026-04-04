import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(riskProvider);
    ref.invalidate(environmentProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(premiumProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final riskAsync = ref.watch(riskProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: riskAsync.when(
            data: (riskData) => _HomeContent(
              userName: user.userName,
              riskData: riskData,
              city: ref.watch(locationProvider).city,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _RiskErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(riskProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final String userName;
  final Map<String, dynamic> riskData;
  final String city;

  const _HomeContent({
    required this.userName,
    required this.riskData,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    final risk = (riskData['risk'] as Map<String, dynamic>?) ?? riskData;
    final level = (risk['risk_level'] as String? ?? 'LOW').toUpperCase();
    final expectedLoss = risk['expected_income_loss']?.toString() ?? '0%';
    final reasons = (risk['reasons'] as List? ?? const []).map((item) => '$item').toList();
    final triggers = (risk['active_triggers'] as List? ?? const []).map((item) => '$item').toList();
    final environment = riskData['environment'] as Map<String, dynamic>? ?? const {};
    final lastUpdated = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        _HeroCard(
          userName: userName,
          city: city,
          riskLevel: level,
          expectedLoss: expectedLoss,
          lastUpdated: lastUpdated,
          insight: reasons.isNotEmpty ? reasons.first : 'Risk is being monitored using live local conditions.',
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Why this matters right now',
          subtitle: 'A simple view of what is affecting your deliveries today.',
          child: Column(
            children: [
              _InfoRow(
                emoji: '🌧',
                title: 'Weather',
                value: '${((environment['snapshot'] as Map?)?['rain_estimate'] ?? 0).toString()} mm rain estimate',
              ),
              const _InfoRow(
                emoji: '🚦',
                title: 'Traffic',
                value: 'Congestion is affecting route time',
              ),
              const _InfoRow(
                emoji: '🌫',
                title: 'Air Quality',
                value: 'AQI is part of your work comfort score',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'AI-powered dynamic risk analysis',
          subtitle: 'The system combines live environment signals and your earning context to explain risk in plain language.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Badge(label: '🤖 Dynamic AI risk'),
              _Badge(label: '⚡ Trigger-aware'),
              _Badge(label: '📍 Hyper-local'),
            ],
          ),
        ),
        if (triggers.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Active triggers',
            subtitle: 'These conditions are currently pushing your income risk higher.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: triggers.map(_triggerLabel).map((label) => _TriggerChip(label: label)).toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionCard(
          title: 'How it works',
          subtitle: 'See how all engines connect behind the scenes.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PipelinePill('Environment'),
              _PipelinePill('Risk'),
              _PipelinePill('Premium'),
              _PipelinePill('Policy'),
              _PipelinePill('Claim'),
              _PipelinePill('Payout'),
            ],
          ),
        ),
      ],
    );
  }

  String _triggerLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'RAIN_TRIGGER':
        return 'Rain';
      case 'TRAFFIC_TRIGGER':
        return 'Traffic';
      case 'AQI_TRIGGER':
        return 'AQI';
      case 'HEAT_TRIGGER':
        return 'Heat';
      case 'COMBINED_TRIGGER':
        return 'Combined';
      default:
        return raw.replaceAll('_', ' ');
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String userName;
  final String city;
  final String riskLevel;
  final String expectedLoss;
  final DateTime lastUpdated;
  final String insight;

  const _HeroCard({
    required this.userName,
    required this.city,
    required this.riskLevel,
    required this.expectedLoss,
    required this.lastUpdated,
    required this.insight,
  });

  Color get _riskColor {
    switch (riskLevel) {
      case 'HIGH':
        return AppTheme.errorColor;
      case 'MEDIUM':
        return AppTheme.warningColor;
      default:
        return AppTheme.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143126), Color(0xFF0F1E1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $userName',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What’s happening right now',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$city risk is being checked using live local conditions.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                label: 'Risk level',
                value: riskLevel,
                color: _riskColor,
              ),
              _HeroMetric(
                label: 'Income loss',
                value: expectedLoss,
                color: AppTheme.primaryColor,
              ),
              _HeroMetric(
                label: 'Last updated',
                value: '${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}',
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              insight,
              style: const TextStyle(color: AppTheme.textPrimary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;

  const _InfoRow({
    required this.emoji,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TriggerChip extends StatelessWidget {
  final String label;

  const _TriggerChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '⚡ $label',
        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PipelinePill extends StatelessWidget {
  final String label;

  const _PipelinePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
        if (label != 'Payout')
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ),
      ],
    );
  }
}

class _RiskErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RiskErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppTheme.warningColor, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'We could not load the risk dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
