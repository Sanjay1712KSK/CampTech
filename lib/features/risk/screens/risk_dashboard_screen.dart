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
  bool _usingFallbackLocation = false;

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
    bool usingFallback = true;
    String? locationMessage;

    final locationResult = await LocationService.requestCurrentLocation();
    if (locationResult.granted &&
        locationResult.lat != null &&
        locationResult.lon != null) {
      lat = locationResult.lat!;
      lon = locationResult.lon!;
      city = locationResult.city ?? 'Current location';
      usingFallback = false;
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
        _usingFallbackLocation = usingFallback;
        _isLoading = false;
      });
    } on RiskServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _locationLabel = city;
        _locationMessage = locationMessage;
        _usingFallbackLocation = usingFallback;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load risk insights right now.';
        _locationLabel = city;
        _locationMessage = locationMessage;
        _usingFallbackLocation = usingFallback;
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: const [
          SizedBox(height: 160),
          Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Fetching live risk data...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    if (_error != null && _risk == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
        const Text(
          'Live disruption intelligence based on your current area.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildLocationCard(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildBanner(
            _error!,
            color: AppTheme.errorColor,
            icon: Icons.error_outline_rounded,
          ),
        ],
        if (_locationMessage != null) ...[
          const SizedBox(height: 16),
          _buildBanner(
            _locationMessage!,
            color: AppTheme.warningColor,
            icon: Icons.location_off_rounded,
          ),
        ],
        if (risk == null || !risk.hasData) ...[
          const SizedBox(height: 16),
          RiskSectionCard(
            title: 'Risk Dashboard',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No risk data is available for this location yet.',
                  style: TextStyle(color: AppTheme.textSecondary),
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
          const SizedBox(height: 16),
          _buildOverviewCard(risk),
          if (risk.deliveryEfficiency != null) ...[
            const SizedBox(height: 16),
            _buildDeliveryEfficiencyCard(risk.deliveryEfficiency!),
          ],
          if (risk.hyperLocalRisk != null || risk.hyperLocalAnalysis.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHyperLocalCard(risk),
          ],
          if (risk.timeSlotRisk.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTimeSlotCard(risk.timeSlotRisk),
          ],
          if (risk.predictiveRisk != null) ...[
            const SizedBox(height: 16),
            _buildPredictiveCard(risk.predictiveRisk!),
          ],
          if (risk.activeTriggers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTriggersCard(risk.activeTriggers, risk.triggerSeverity),
          ],
          if (risk.fraudSignals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFraudSignalsCard(risk.fraudSignals),
          ],
          if (risk.reasons.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildReasonsCard(risk.reasons),
          ],
          if (risk.riskFactors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMetricMapCard(
              title: 'Risk Factors',
              values: risk.riskFactors,
              defaultColor: AppTheme.warningColor,
            ),
          ],
          if (risk.adaptiveWeights.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMetricMapCard(
              title: 'Adaptive Weights',
              values: risk.adaptiveWeights,
              defaultColor: AppTheme.primaryColor,
            ),
          ],
          if (risk.environment.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDynamicCard('Environment Snapshot', risk.environment),
          ],
          if (risk.gigContext.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDynamicCard('Gig Context', risk.gigContext),
          ],
          for (final entry in risk.additionalSections.entries) ...[
            const SizedBox(height: 16),
            _buildDynamicCard(_formatLabel(entry.key), entry.value),
          ],
        ],
      ],
    );
  }

  Widget _buildLocationCard() {
    return RiskSectionCard(
      title: 'Location',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (_usingFallbackLocation ? AppTheme.warningColor : AppTheme.successColor)
              .withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _usingFallbackLocation ? 'Fallback' : 'Live',
          style: TextStyle(
            color:
                _usingFallbackLocation ? AppTheme.warningColor : AppTheme.successColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _usingFallbackLocation
                ? Icons.location_searching_rounded
                : Icons.my_location_rounded,
            color: _usingFallbackLocation ? AppTheme.warningColor : AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _locationLabel,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(RiskModel risk) {
    final level = (risk.riskLevel ?? 'UNKNOWN').toUpperCase();
    final levelColor = _levelColor(level);
    return RiskSectionCard(
      title: 'Risk Overview',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: levelColor.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          level,
          style: TextStyle(
            color: levelColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (risk.riskScore != null)
                RiskMetricChip(
                  label: 'Risk Score',
                  value: risk.riskScore!.toStringAsFixed(2),
                  color: levelColor,
                ),
              if (risk.expectedIncomeLoss != null)
                RiskMetricChip(
                  label: 'Expected Income Loss',
                  value: risk.expectedIncomeLoss!,
                  color: levelColor,
                ),
            ],
          ),
          if (risk.recommendation != null) ...[
            const SizedBox(height: 14),
            Text(
              risk.recommendation!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryEfficiencyCard(DeliveryEfficiencyModel delivery) {
    return RiskSectionCard(
      title: 'Delivery Efficiency',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (delivery.score != null)
            RiskMetricChip(
              label: 'Efficiency Score',
              value: delivery.score!.toStringAsFixed(2),
              color: AppTheme.primaryColor,
            ),
          if (delivery.dropPercentage != null)
            RiskMetricChip(
              label: 'Drop',
              value: delivery.dropPercentage!,
              color: AppTheme.warningColor,
            ),
          if (delivery.normalDeliveriesPerHour != null)
            RiskMetricChip(
              label: 'Normal / Hr',
              value: delivery.normalDeliveriesPerHour!.toStringAsFixed(1),
              color: AppTheme.successColor,
            ),
          if (delivery.estimatedCurrent != null)
            RiskMetricChip(
              label: 'Estimated Current',
              value: delivery.estimatedCurrent!.toStringAsFixed(1),
              color: AppTheme.warningColor,
            ),
          if (delivery.deliveryCapacity != null)
            RiskMetricChip(
              label: 'Capacity',
              value: delivery.deliveryCapacity!.toStringAsFixed(2),
              color: AppTheme.primaryColor,
            ),
          if (delivery.workingHoursFactor != null)
            RiskMetricChip(
              label: 'Hours Factor',
              value: delivery.workingHoursFactor!.toStringAsFixed(2),
              color: AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildHyperLocalCard(RiskModel risk) {
    final insight = risk.hyperLocalAnalysis['insight']?.toString();
    final source = risk.hyperLocalAnalysis['source']?.toString();
    final baselineSnapshotRaw = risk.hyperLocalAnalysis['baseline_snapshot'];
    final baselineSnapshot = baselineSnapshotRaw is Map<String, dynamic>
        ? baselineSnapshotRaw
        : baselineSnapshotRaw is Map
            ? baselineSnapshotRaw.map((key, value) => MapEntry('$key', value))
            : null;

    return RiskSectionCard(
      title: 'Hyper Local',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (risk.hyperLocalRisk != null)
                RiskMetricChip(
                  label: 'Hyper-local Risk',
                  value: risk.hyperLocalRisk!.toStringAsFixed(2),
                  color: AppTheme.warningColor,
                ),
              if (source != null && source.isNotEmpty)
                RiskMetricChip(
                  label: 'Source',
                  value: source,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
          if (insight != null && insight.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              insight,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (baselineSnapshot != null && baselineSnapshot.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDynamicValue(baselineSnapshot),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlotCard(Map<String, String> timeSlotRisk) {
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

  Widget _buildPredictiveCard(PredictiveRiskModel predictiveRisk) {
    final trend = (predictiveRisk.trend ?? 'stable').toLowerCase();
    final trendIcon = switch (trend) {
      'increasing' => Icons.north_rounded,
      'decreasing' => Icons.south_rounded,
      _ => Icons.east_rounded,
    };
    final trendColor = switch (trend) {
      'increasing' => AppTheme.errorColor,
      'decreasing' => AppTheme.successColor,
      _ => AppTheme.warningColor,
    };

    return RiskSectionCard(
      title: 'Predictive Risk',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (predictiveRisk.next6HrRisk != null)
            RiskMetricChip(
              label: 'Next 6 Hr',
              value: predictiveRisk.next6HrRisk!.toStringAsFixed(2),
              color: trendColor,
            ),
          if (predictiveRisk.trend != null)
            RiskMetricChip(
              label: 'Trend',
              value: _formatLabel(predictiveRisk.trend!),
              color: trendColor,
              icon: trendIcon,
            ),
        ],
      ),
    );
  }

  Widget _buildTriggersCard(List<String> triggers, String? severity) {
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
        spacing: 10,
        runSpacing: 10,
        children: triggers
            .map(
              (trigger) => RiskMetricChip(
                label: 'Trigger',
                value: _formatLabel(trigger),
                icon: _triggerIcon(trigger),
                color: AppTheme.warningColor,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFraudSignalsCard(Map<String, bool> fraudSignals) {
    return RiskSectionCard(
      title: 'Fraud Signals',
      child: Column(
        children: fraudSignals.entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == fraudSignals.keys.last ? 0 : 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: entry.value ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatLabel(entry.key),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      entry.value ? 'Match' : 'Review',
                      style: TextStyle(
                        color:
                            entry.value ? AppTheme.successColor : AppTheme.warningColor,
                        fontWeight: FontWeight.w700,
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

  Widget _buildReasonsCard(List<String> reasons) {
    return RiskSectionCard(
      title: 'Reasons',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: reasons
            .map(
              (reason) => Padding(
                padding: EdgeInsets.only(
                  bottom: reason == reasons.last ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
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

  Widget _buildMetricMapCard({
    required String title,
    required Map<String, double> values,
    required Color defaultColor,
  }) {
    return RiskSectionCard(
      title: title,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.entries
            .map(
              (entry) => RiskMetricChip(
                label: _formatLabel(entry.key),
                value: entry.value.toStringAsFixed(2),
                color: defaultColor,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDynamicCard(String title, Object? data) {
    return RiskSectionCard(
      title: title,
      child: _buildDynamicValue(data),
    );
  }

  Widget _buildDynamicValue(Object? value) {
    if (value == null) {
      return const Text(
        'No data available',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }

    if (value is Map) {
      final entries = value.entries.where((entry) => entry.value != null).toList();
      if (entries.isEmpty) {
        return const Text(
          'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        );
      }

      final allSimple = entries.every((entry) => _isSimpleValue(entry.value));
      if (allSimple) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries
              .map(
                (entry) => RiskMetricChip(
                  label: _formatLabel('${entry.key}'),
                  value: _formatValue(entry.value),
                  color: entry.value is bool
                      ? ((entry.value as bool)
                          ? AppTheme.successColor
                          : AppTheme.warningColor)
                      : AppTheme.primaryColor,
                  icon: entry.value is bool
                      ? ((entry.value as bool)
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded)
                      : null,
                ),
              )
              .toList(),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == entries.last.key ? 0 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatLabel('${entry.key}'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDynamicValue(entry.value),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    if (value is List) {
      if (value.isEmpty) {
        return const Text(
          'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        );
      }

      final allSimple = value.every(_isSimpleValue);
      if (allSimple) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: value
              .map(
                (item) => RiskMetricChip(
                  label: 'Value',
                  value: _formatValue(item),
                  color: AppTheme.primaryColor,
                ),
              )
              .toList(),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  bottom: item == value.last ? 0 : 12,
                ),
                child: _buildDynamicValue(item),
              ),
            )
            .toList(),
      );
    }

    return Text(
      _formatValue(value),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        height: 1.5,
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

  IconData _triggerIcon(String trigger) {
    final normalized = trigger.toUpperCase();
    if (normalized.contains('RAIN')) return Icons.umbrella_rounded;
    if (normalized.contains('TRAFFIC')) return Icons.traffic_rounded;
    if (normalized.contains('AQI')) return Icons.air_rounded;
    if (normalized.contains('HEAT')) return Icons.wb_sunny_rounded;
    if (normalized.contains('COMBINED')) return Icons.hub_rounded;
    return Icons.bolt_rounded;
  }

  bool _isSimpleValue(Object? value) =>
      value is num || value is String || value is bool;

  String _formatValue(Object? value) {
    if (value is double) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    }
    if (value is num) return '$value';
    if (value is bool) return value ? 'Yes' : 'No';
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
