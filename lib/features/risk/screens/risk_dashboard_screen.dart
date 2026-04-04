import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/risk/models/risk_model.dart';
import 'package:guidewire_gig_ins/features/risk/services/risk_service.dart';
import 'package:guidewire_gig_ins/features/risk/widgets/risk_metric_chip.dart';
import 'package:guidewire_gig_ins/features/risk/widgets/risk_section_card.dart';
import 'package:guidewire_gig_ins/services/location_service.dart';

class RiskDashboardScreen extends ConsumerStatefulWidget {
  final int? userId;

  const RiskDashboardScreen({super.key, this.userId});

  @override
  ConsumerState<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends ConsumerState<RiskDashboardScreen> {
  final RiskService _riskService = RiskService();

  RiskModel? _risk;
  bool _isLoading = true;
  String? _error;
  String? _locationMessage;
  String _locationLabel = 'Detecting location';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRisk();
    });
  }

  Future<void> _loadRisk() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = widget.userId ?? ref.read(userProvider)?.userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'User session not found. Please log in again.';
      });
      return;
    }

    final fallbackLocation = ref.read(locationProvider);
    double lat = fallbackLocation.lat;
    double lon = fallbackLocation.lon;
    String city = fallbackLocation.city;
    String? locationMessage;

    final locationResult = await LocationService.requestCurrentLocation();
    if (locationResult.granted &&
        locationResult.lat != null &&
        locationResult.lon != null) {
      lat = locationResult.lat!;
      lon = locationResult.lon!;
      city = locationResult.city ?? 'Current location';
      ref.read(locationProvider.notifier).updateLocation(
            lat: lat,
            lon: lon,
            city: city,
            permissionGranted: true,
            isLive: true,
            error: null,
          );
    } else {
      locationMessage =
          locationResult.error ?? 'Using fallback location for risk analysis.';
      ref.read(locationProvider.notifier).setLimitedFallback(message: locationMessage);
    }

    try {
      final risk = await _riskService.fetchRisk(
        userId: userId,
        lat: lat,
        lon: lon,
      );
      if (!mounted) return;
      setState(() {
        _risk = risk;
        _locationLabel = city;
        _locationMessage = locationMessage;
        _isLoading = false;
      });
    } on RiskServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _locationLabel = city;
        _locationMessage = locationMessage;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load risk insights right now.';
        _locationLabel = city;
        _locationMessage = locationMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadRisk,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _risk == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: const [
          SizedBox(height: 180),
          Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Running the AI risk engine...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    if (_error != null && _risk == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: [
          const SizedBox(height: 100),
          RiskSectionCard(
            title: 'Risk Dashboard',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadRisk,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final risk = _risk;
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Risk Dashboard',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _locationLabel,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        if (_locationMessage != null) ...[
          const SizedBox(height: 16),
          _buildBanner(
            _locationMessage!,
            color: AppTheme.warningColor,
            icon: Icons.location_off_rounded,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildBanner(
            _error!,
            color: AppTheme.errorColor,
            icon: Icons.error_outline_rounded,
          ),
        ],
        if (risk == null || !risk.hasData) ...[
          const SizedBox(height: 20),
          RiskSectionCard(
            title: 'No Risk Data Yet',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pull to refresh after the backend generates a live risk response for this location.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadRisk,
                    child: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          _buildHeroSection(risk),
          if (risk.deliveryEfficiency != null) ...[
            const SizedBox(height: 16),
            _buildDeliveryImpactSection(risk.deliveryEfficiency!),
          ],
          if (risk.reasons.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildReasonsSection(risk.reasons),
          ],
          if (risk.predictiveRisk != null) ...[
            const SizedBox(height: 16),
            _buildPredictiveSection(risk.predictiveRisk!),
          ],
          if (risk.timeSlotRisk.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTimeSlotSection(risk.timeSlotRisk),
          ],
          if (risk.activeTriggers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTriggerSection(risk.activeTriggers, risk.triggerSeverity),
          ],
          if (risk.hyperLocalRisk != null || risk.fraudSignals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSupportSection(risk),
          ],
          const SizedBox(height: 16),
          _buildAiExplanationSection(risk),
        ],
      ],
    );
  }

  Widget _buildHeroSection(RiskModel risk) {
    final level = (risk.riskLevel ?? 'UNKNOWN').toUpperCase();
    final levelColor = _levelColor(level);
    final insight = risk.reasons.isNotEmpty
        ? risk.reasons.first
        : (risk.recommendation ?? 'Live engine output is ready.');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withOpacity(0.22),
            AppTheme.surfaceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: levelColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              level,
              style: TextStyle(
                color: levelColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.expectedIncomeLoss ??
                        (risk.expectedIncomeLossPct != null
                            ? '${risk.expectedIncomeLossPct}%'
                            : '--'),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Expected income loss',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (risk.riskScore != null)
                RiskMetricChip(
                  label: 'Risk Score',
                  value: risk.riskScore!.toStringAsFixed(2),
                  color: levelColor,
                ),
              if (risk.hyperLocalRisk != null)
                RiskMetricChip(
                  label: 'Hyper-local',
                  value: risk.hyperLocalRisk!.toStringAsFixed(2),
                  color: AppTheme.warningColor,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            insight,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryImpactSection(DeliveryEfficiencyModel delivery) {
    final efficiencyPct = delivery.score != null
        ? '${(delivery.score! * 100).round()}%'
        : '--';

    return RiskSectionCard(
      title: 'Delivery Impact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This is the clearest view of how current conditions are affecting earning capacity right now.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (delivery.normalDeliveriesPerHour != null)
                  RiskMetricChip(
                    label: 'Normal deliveries / hour',
                    value: delivery.normalDeliveriesPerHour!.toStringAsFixed(1),
                    color: AppTheme.successColor,
                  ),
                if (delivery.estimatedCurrent != null)
                  RiskMetricChip(
                    label: 'Current deliveries / hour',
                    value: delivery.estimatedCurrent!.toStringAsFixed(1),
                    color: AppTheme.warningColor,
                  ),
                RiskMetricChip(
                  label: 'Efficiency',
                  value: efficiencyPct,
                  color: AppTheme.primaryColor,
                ),
                if (delivery.dropPercentage != null)
                  RiskMetricChip(
                    label: 'Drop',
                    value: delivery.dropPercentage!,
                    color: AppTheme.errorColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonsSection(List<String> reasons) {
    return RiskSectionCard(
      title: 'Why This Is Happening',
      child: Column(
        children: reasons
            .map(
              (reason) => Padding(
                padding: EdgeInsets.only(
                  bottom: reason == reasons.last ? 0 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reasonEmoji(reason),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPredictiveSection(PredictiveRiskModel predictiveRisk) {
    final trend = (predictiveRisk.trend ?? 'stable').toLowerCase();
    final trendArrow = trend == 'increasing'
        ? '↑'
        : trend == 'decreasing'
            ? '↓'
            : '→';
    final trendColor = trend == 'increasing'
        ? AppTheme.errorColor
        : trend == 'decreasing'
            ? AppTheme.successColor
            : AppTheme.warningColor;

    return RiskSectionCard(
      title: 'Predictive Risk',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (predictiveRisk.next6HrRisk != null)
            RiskMetricChip(
              label: 'Next 6 hours',
              value: predictiveRisk.next6HrRisk!.toStringAsFixed(2),
              color: trendColor,
            ),
          if (predictiveRisk.trend != null)
            RiskMetricChip(
              label: 'Trend',
              value: '$trendArrow ${_formatLabel(predictiveRisk.trend!)}',
              color: trendColor,
            ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotSection(Map<String, String> timeSlotRisk) {
    return RiskSectionCard(
      title: 'Time Slot Risk',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: timeSlotRisk.entries
            .map(
              (entry) => RiskMetricChip(
                label: _formatLabel(entry.key),
                value: entry.value.toUpperCase(),
                color: _levelColor(entry.value),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTriggerSection(List<String> triggers, String? severity) {
    return RiskSectionCard(
      title: 'Active Triggers',
      trailing: severity == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _levelColor(severity).withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                severity.toUpperCase(),
                style: TextStyle(
                  color: _levelColor(severity),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: triggers
            .map(
              (trigger) => RiskMetricChip(
                label: 'Trigger',
                value: '${_triggerEmoji(trigger)} ${_formatLabel(trigger)}',
                color: AppTheme.warningColor,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSupportSection(RiskModel risk) {
    return RiskSectionCard(
      title: 'Support Signals',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (risk.hyperLocalRisk != null)
            RiskMetricChip(
              label: 'Hyper-local risk',
              value: risk.hyperLocalRisk!.toStringAsFixed(2),
              color: AppTheme.warningColor,
            ),
          ...risk.fraudSignals.entries.map(
            (entry) => RiskMetricChip(
              label: _formatLabel(entry.key),
              value: entry.value ? 'Yes' : 'No',
              color: entry.value ? AppTheme.successColor : AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiExplanationSection(RiskModel risk) {
    final stages = <MapEntry<String, String>>[
      MapEntry(
        'Environment',
        'Weather, AQI, traffic, and location are collected from live backend sources.',
      ),
      MapEntry(
        'Disruption',
        risk.disruption.isNotEmpty
            ? 'Delivery capacity: ${_formatValue(risk.disruption['delivery_capacity'])}, working hours: ${_formatValue(risk.disruption['working_hours'] ?? risk.disruption['working_hours_factor'])}.'
            : 'The engine estimates how much conditions reduce delivery capacity and working hours.',
      ),
      MapEntry(
        'Efficiency',
        risk.deliveryEfficiency != null
            ? 'Normal ${_formatValue(risk.deliveryEfficiency!.normalDeliveriesPerHour)} vs current ${_formatValue(risk.deliveryEfficiency!.estimatedCurrent)} deliveries per hour.'
            : 'The disruption result is converted into delivery efficiency.',
      ),
      MapEntry(
        'Income Loss',
        risk.expectedIncomeLoss ??
            (risk.expectedIncomeLossPct != null ? '${risk.expectedIncomeLossPct}%' : 'Not available'),
      ),
      MapEntry(
        'Risk',
        risk.riskLevel != null
            ? '${risk.riskLevel} risk with score ${_formatValue(risk.riskScore)}.'
            : 'The final score blends efficiency loss, environmental weights, and local context.',
      ),
    ];

    return RiskSectionCard(
      title: 'AI Explanation',
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: AppTheme.primaryColor,
          collapsedIconColor: AppTheme.textSecondary,
          title: const Text(
            'Environment → Disruption → Efficiency → Income Loss → Risk',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Tap to see how the engine turns live conditions into an explainable risk outcome.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          children: [
            const SizedBox(height: 14),
            ...stages.map(
              (stage) => Padding(
                padding: EdgeInsets.only(
                  bottom: stage == stages.last ? 0 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '•',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage.key,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stage.value,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildBanner(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'HIGH':
        return AppTheme.errorColor;
      case 'MEDIUM':
        return AppTheme.warningColor;
      case 'LOW':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _reasonEmoji(String reason) {
    final normalized = reason.toLowerCase();
    if (normalized.contains('rain')) return '🌧';
    if (normalized.contains('traffic')) return '🚦';
    if (normalized.contains('aqi') || normalized.contains('air')) return '🌫';
    if (normalized.contains('heat')) return '🌡';
    return '•';
  }

  String _triggerEmoji(String trigger) {
    final normalized = trigger.toUpperCase();
    if (normalized.contains('RAIN')) return '🌧';
    if (normalized.contains('TRAFFIC')) return '🚦';
    if (normalized.contains('AQI')) return '🌫';
    if (normalized.contains('HEAT')) return '🌡';
    return '•';
  }

  String _formatValue(Object? value) {
    if (value == null) return '--';
    if (value is double) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    }
    if (value is num) return '$value';
    return '$value';
  }

  String _formatLabel(String raw) {
    final words = raw
        .replaceAll('-', '_')
        .split('_')
        .where((word) => word.trim().isNotEmpty)
        .map(
          (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .toList();
    return words.isEmpty ? raw : words.join(' ');
  }
}
