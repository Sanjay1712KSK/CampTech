class RiskModel {
  final double? riskScore;
  final String? riskLevel;
  final String? expectedIncomeLoss;
  final int? expectedIncomeLossPct;
  final Map<String, dynamic> disruption;
  final DeliveryEfficiencyModel? deliveryEfficiency;
  final double? hyperLocalRisk;
  final Map<String, dynamic> hyperLocalAnalysis;
  final Map<String, String> timeSlotRisk;
  final PredictiveRiskModel? predictiveRisk;
  final List<String> activeTriggers;
  final String? triggerSeverity;
  final Map<String, bool> fraudSignals;
  final List<String> reasons;
  final Map<String, double> riskFactors;
  final Map<String, double> adaptiveWeights;
  final String? recommendation;
  final Map<String, dynamic> environment;
  final Map<String, dynamic> gigContext;
  final Map<String, dynamic> additionalSections;

  const RiskModel({
    this.riskScore,
    this.riskLevel,
    this.expectedIncomeLoss,
    this.expectedIncomeLossPct,
    this.disruption = const {},
    this.deliveryEfficiency,
    this.hyperLocalRisk,
    this.hyperLocalAnalysis = const {},
    this.timeSlotRisk = const {},
    this.predictiveRisk,
    this.activeTriggers = const [],
    this.triggerSeverity,
    this.fraudSignals = const {},
    this.reasons = const [],
    this.riskFactors = const {},
    this.adaptiveWeights = const {},
    this.recommendation,
    this.environment = const {},
    this.gigContext = const {},
    this.additionalSections = const {},
  });

  factory RiskModel.fromJson(Map<String, dynamic> json) {
    final payload = _asMap(json['risk']) ?? json;
    const knownKeys = <String>{
      'risk_score',
      'risk_level',
      'expected_income_loss',
      'expected_income_loss_pct',
      'disruption',
      'delivery_efficiency',
      'hyper_local_risk',
      'hyper_local_analysis',
      'time_slot_risk',
      'predictive_risk',
      'active_triggers',
      'trigger_severity',
      'fraud_signals',
      'reasons',
      'risk_factors',
      'adaptive_weights',
      'recommendation',
      'environment',
      'gig_context',
    };

    final additional = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (!knownKeys.contains(entry.key) && entry.value != null) {
        additional[entry.key] = entry.value;
      }
    }

    return RiskModel(
      riskScore: _asDouble(payload['risk_score']),
      riskLevel: _asString(payload['risk_level']),
      expectedIncomeLoss: _asString(payload['expected_income_loss']),
      expectedIncomeLossPct: _asInt(payload['expected_income_loss_pct']),
      disruption: _asMap(payload['disruption']) ?? const {},
      deliveryEfficiency: _asMap(payload['delivery_efficiency']) != null
          ? DeliveryEfficiencyModel.fromJson(
              _asMap(payload['delivery_efficiency'])!,
            )
          : null,
      hyperLocalRisk: _asDouble(payload['hyper_local_risk']),
      hyperLocalAnalysis: _asMap(payload['hyper_local_analysis']) ?? const {},
      timeSlotRisk: _asStringMap(payload['time_slot_risk']),
      predictiveRisk: _asMap(payload['predictive_risk']) != null
          ? PredictiveRiskModel.fromJson(_asMap(payload['predictive_risk'])!)
          : null,
      activeTriggers: _asStringList(payload['active_triggers']),
      triggerSeverity: _asString(payload['trigger_severity']),
      fraudSignals: _asBoolMap(payload['fraud_signals']),
      reasons: _asStringList(payload['reasons']),
      riskFactors: _asDoubleMap(payload['risk_factors']),
      adaptiveWeights: _asDoubleMap(payload['adaptive_weights']),
      recommendation: _asString(payload['recommendation']),
      environment: _asMap(payload['environment']) ?? const {},
      gigContext: _asMap(payload['gig_context']) ?? const {},
      additionalSections: additional,
    );
  }

  bool get hasData =>
      riskScore != null ||
      riskLevel != null ||
      expectedIncomeLossPct != null ||
      deliveryEfficiency != null ||
      timeSlotRisk.isNotEmpty ||
      activeTriggers.isNotEmpty ||
      fraudSignals.isNotEmpty ||
      reasons.isNotEmpty ||
      additionalSections.isNotEmpty;

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry('$key', entryValue));
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList();
  }

  static Map<String, String> _asStringMap(Object? value) {
    final map = _asMap(value);
    if (map == null) return const {};
    return map.map((key, entryValue) => MapEntry(key, '$entryValue'));
  }

  static Map<String, bool> _asBoolMap(Object? value) {
    final map = _asMap(value);
    if (map == null) return const {};
    final parsed = <String, bool>{};
    for (final entry in map.entries) {
      if (entry.value is bool) {
        parsed[entry.key] = entry.value as bool;
      } else if (entry.value is String) {
        final normalized = (entry.value as String).toLowerCase();
        parsed[entry.key] = normalized == 'true' || normalized == 'yes';
      }
    }
    return parsed;
  }

  static Map<String, double> _asDoubleMap(Object? value) {
    final map = _asMap(value);
    if (map == null) return const {};
    final parsed = <String, double>{};
    for (final entry in map.entries) {
      final doubleValue = _asDouble(entry.value);
      if (doubleValue != null) {
        parsed[entry.key] = doubleValue;
      }
    }
    return parsed;
  }
}

class DeliveryEfficiencyModel {
  final double? score;
  final String? drop;
  final String? dropPercentage;
  final double? normalDeliveriesPerHour;
  final double? estimatedCurrent;
  final double? deliveryCapacity;
  final double? workingHoursFactor;

  const DeliveryEfficiencyModel({
    this.score,
    this.drop,
    this.dropPercentage,
    this.normalDeliveriesPerHour,
    this.estimatedCurrent,
    this.deliveryCapacity,
    this.workingHoursFactor,
  });

  factory DeliveryEfficiencyModel.fromJson(Map<String, dynamic> json) {
    return DeliveryEfficiencyModel(
      score: RiskModel._asDouble(json['score']),
      drop: RiskModel._asString(json['drop']),
      dropPercentage: RiskModel._asString(json['drop_percentage']) ??
          RiskModel._asString(json['drop']),
      normalDeliveriesPerHour:
          RiskModel._asDouble(json['normal_deliveries_per_hour']),
      estimatedCurrent: RiskModel._asDouble(json['estimated_current']),
      deliveryCapacity: RiskModel._asDouble(json['delivery_capacity']),
      workingHoursFactor: RiskModel._asDouble(json['working_hours_factor']),
    );
  }
}

class PredictiveRiskModel {
  final double? next6HrRisk;
  final String? trend;

  const PredictiveRiskModel({
    this.next6HrRisk,
    this.trend,
  });

  factory PredictiveRiskModel.fromJson(Map<String, dynamic> json) {
    return PredictiveRiskModel(
      next6HrRisk: RiskModel._asDouble(
        json['next_6hr_risk'] ?? json['next_6hr'],
      ),
      trend: RiskModel._asString(json['trend']),
    );
  }
}
