import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _emailController = TextEditingController(text: 'admin@gigshield.com');
  final _passwordController = TextEditingController(text: 'admin123');
  final _formKey = GlobalKey<FormState>();

  String? _adminToken;
  bool _loggingIn = false;
  String? _errorMessage;
  Future<_AdminDashboardBundle>? _dashboardFuture;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _loggingIn) return;
    setState(() {
      _loggingIn = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiService.adminLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _adminToken = result.token;
        _dashboardFuture = _loadDashboard(result.token);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  Future<_AdminDashboardBundle> _loadDashboard(String token) async {
    final results = await Future.wait<Object>([
      ApiService.getAdminOverview(token),
      ApiService.getAdminFraudStats(token),
      ApiService.getAdminClaimsStats(token),
      ApiService.getAdminRiskStats(token),
      ApiService.getAdminFinancials(token),
      ApiService.getAdminPredictions(token),
    ]);
    return _AdminDashboardBundle(
      overview: results[0] as AdminOverviewModel,
      fraud: results[1] as AdminFraudStatsModel,
      claims: results[2] as AdminClaimsStatsModel,
      risk: results[3] as AdminRiskStatsModel,
      financials: results[4] as AdminFinancialsModel,
      predictions: results[5] as AdminPredictionsModel,
    );
  }

  Future<void> _refresh() async {
    final token = _adminToken;
    if (token == null) return;
    setState(() {
      _dashboardFuture = _loadDashboard(token);
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141717),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Insurer Control Center'),
      ),
      body: _adminToken == null ? _buildLogin() : _buildDashboard(),
    );
  }

  Widget _buildLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 34,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Admin Login',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the insurer credentials to access live fraud, financial, and risk analytics.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Admin email'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter admin email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Enter password'
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loggingIn ? null : _login,
                      icon: Icon(
                        _loggingIn
                            ? Icons.hourglass_top_rounded
                            : Icons.login_rounded,
                      ),
                      label: Text(
                        _loggingIn ? 'Signing in...' : 'Open Dashboard',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_AdminDashboardBundle>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AdminLoadingState();
          }
          if (snapshot.hasError) {
            return _AdminErrorState(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return _AdminErrorState(
              message: 'Admin dashboard data is unavailable.',
              onRetry: _refresh,
            );
          }
          return _AdminDashboardView(data: data);
        },
      ),
    );
  }
}

class _AdminDashboardBundle {
  final AdminOverviewModel overview;
  final AdminFraudStatsModel fraud;
  final AdminClaimsStatsModel claims;
  final AdminRiskStatsModel risk;
  final AdminFinancialsModel financials;
  final AdminPredictionsModel predictions;

  const _AdminDashboardBundle({
    required this.overview,
    required this.fraud,
    required this.claims,
    required this.risk,
    required this.financials,
    required this.predictions,
  });
}

class _AdminDashboardView extends StatelessWidget {
  final _AdminDashboardBundle data;

  const _AdminDashboardView({required this.data});

  @override
  Widget build(BuildContext context) {
    final recommendations = _buildRecommendations(data);
    final smartInsights = _buildSmartInsights(data);
    final hotspots = data.fraud.hotspots;
    final profitPositive = data.financials.profit >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final cardsPerRow = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 800
            ? 2
            : 1;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _AdminHero(
              title: 'Intelligent Insurer Control Panel',
              subtitle:
                  'Understand platform health instantly, detect fraud patterns, predict risk, and act on live insurer recommendations.',
              insight: data.predictions.insight,
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'System Health'),
            _MetricGrid(
              cardsPerRow: cardsPerRow,
              children: [
                _OverviewCard(
                  icon: Icons.people_alt_outlined,
                  label: 'Total Users',
                  value: '${data.overview.totalUsers}',
                ),
                _OverviewCard(
                  icon: Icons.verified_user_outlined,
                  label: 'Active Policies',
                  value: '${data.overview.activePolicies}',
                ),
                _OverviewCard(
                  icon: Icons.assignment_outlined,
                  label: 'Total Claims',
                  value: '${data.overview.totalClaims}',
                ),
                _OverviewCard(
                  icon: Icons.payments_outlined,
                  label: 'Total Payouts',
                  value: _currency(data.overview.totalPayouts),
                ),
                _OverviewCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Premiums',
                  value: _currency(data.overview.totalPremiums),
                ),
                _OverviewCard(
                  icon: Icons.balance_outlined,
                  label: 'Loss Ratio',
                  value: _percentValue(data.overview.lossRatio),
                  accent: data.overview.lossRatio > 1
                      ? AppTheme.errorColor
                      : AppTheme.warningColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Fraud Intelligence'),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _PanelCard(
                          title: 'Fraud Core Signals',
                          subtitle:
                              'Watch platform fraud pressure and top attack patterns.',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _SignalStat(
                                      icon: Icons.gpp_bad_outlined,
                                      label: 'Fraud Rate',
                                      value: _percentValue(
                                        data.fraud.fraudRate,
                                      ),
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SignalStat(
                                      icon: Icons.flag_outlined,
                                      label: 'Flagged Claims',
                                      value: '${data.fraud.flaggedClaims}',
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SignalStat(
                                      icon: Icons.block_outlined,
                                      label: 'Rejected Claims',
                                      value: '${data.fraud.rejectedClaims}',
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ...data.fraud.topFraudTypes.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _LabelBar(
                                    label: _fraudLabel(item.type),
                                    value: item.count.toDouble(),
                                    max: _maxFraudCount(data.fraud),
                                    color: _fraudColor(item.type),
                                    trailing: '${item.count}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _PanelCard(
                          title: 'Fraud Hotspots',
                          subtitle:
                              'City-wise fraud activity from live fraud logs.',
                          child: hotspots.isEmpty
                              ? const _EmptyPanel(
                                  icon: Icons.location_off_outlined,
                                  text:
                                      'No city-level fraud activity is available yet.',
                                )
                              : Column(
                                  children: hotspots
                                      .map(
                                        (hotspot) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _HotspotRow(
                                            city: hotspot.city,
                                            count: hotspot.count,
                                            max: _maxHotspotCount(hotspots),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _PanelCard(
                        title: 'Fraud Core Signals',
                        subtitle:
                            'Watch platform fraud pressure and top attack patterns.',
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _SignalStat(
                                  icon: Icons.gpp_bad_outlined,
                                  label: 'Fraud Rate',
                                  value: _percentValue(data.fraud.fraudRate),
                                  color: AppTheme.errorColor,
                                ),
                                _SignalStat(
                                  icon: Icons.flag_outlined,
                                  label: 'Flagged Claims',
                                  value: '${data.fraud.flaggedClaims}',
                                  color: AppTheme.warningColor,
                                ),
                                _SignalStat(
                                  icon: Icons.block_outlined,
                                  label: 'Rejected Claims',
                                  value: '${data.fraud.rejectedClaims}',
                                  color: AppTheme.errorColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ...data.fraud.topFraudTypes.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _LabelBar(
                                  label: _fraudLabel(item.type),
                                  value: item.count.toDouble(),
                                  max: _maxFraudCount(data.fraud),
                                  color: _fraudColor(item.type),
                                  trailing: '${item.count}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PanelCard(
                        title: 'Fraud Hotspots',
                        subtitle:
                            'City-wise fraud activity from live fraud logs.',
                        child: hotspots.isEmpty
                            ? const _EmptyPanel(
                                icon: Icons.location_off_outlined,
                                text:
                                    'No city-level fraud activity is available yet.',
                              )
                            : Column(
                                children: hotspots
                                    .map(
                                      (hotspot) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _HotspotRow(
                                          city: hotspot.city,
                                          count: hotspot.count,
                                          max: _maxHotspotCount(hotspots),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Risk + Claim Trends'),
            _MetricGrid(
              cardsPerRow: cardsPerRow,
              children: [
                _PanelCard(
                  title: 'Claim Analytics',
                  subtitle:
                      'Approval, rejection, flagging, and payout profile.',
                  child: Column(
                    children: [
                      _TripleBarChart(
                        values: [
                          _ChartDatum(
                            'Approved',
                            data.claims.approved.toDouble(),
                            AppTheme.successColor,
                          ),
                          _ChartDatum(
                            'Rejected',
                            data.claims.rejected.toDouble(),
                            AppTheme.errorColor,
                          ),
                          _ChartDatum(
                            'Flagged',
                            data.claims.flagged.toDouble(),
                            AppTheme.warningColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoLine(
                        label: 'Average payout',
                        value: _currency(data.claims.avgPayout),
                      ),
                      _InfoLine(
                        label: 'Average loss',
                        value: _currency(data.claims.avgLoss),
                      ),
                    ],
                  ),
                ),
                _PanelCard(
                  title: 'Risk Analytics',
                  subtitle:
                      'Track systemic risk and the triggers driving platform stress.',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SignalStat(
                              icon: Icons.warning_amber_outlined,
                              label: 'High-risk users',
                              value: '${data.risk.highRiskUsers}',
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SignalStat(
                              icon: Icons.track_changes_outlined,
                              label: 'Avg risk score',
                              value: data.risk.avgRiskScore.toStringAsFixed(2),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: data.risk.topTriggers
                              .map(
                                (trigger) =>
                                    _TriggerChip(label: _titleize(trigger)),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                _PanelCard(
                  title: 'Financial Health',
                  subtitle:
                      'See how premiums and payouts translate into insurer performance.',
                  child: Column(
                    children: [
                      _InfoLine(
                        label: 'Premiums collected',
                        value: _currency(data.financials.totalPremiums),
                      ),
                      _InfoLine(
                        label: 'Total payouts',
                        value: _currency(data.financials.totalPayouts),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              (profitPositive
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor)
                                  .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profit / Loss',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currency(data.financials.profit),
                              style: TextStyle(
                                color: profitPositive
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Predictions'),
            _PanelCard(
              title: 'Next 7-Day Outlook',
              subtitle:
                  'Use these predictions to prepare underwriting and fraud operations.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SignalStat(
                        icon: Icons.calendar_month_outlined,
                        label: 'Expected claims',
                        value: '${data.predictions.nextWeekClaims}',
                        color: AppTheme.primaryColor,
                      ),
                      _SignalStat(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Expected payout',
                        value: _currency(data.predictions.expectedPayout),
                        color: AppTheme.warningColor,
                      ),
                      _SignalStat(
                        icon: _trendIcon(data.predictions.riskTrend),
                        label: 'Risk trend',
                        value: _titleize(data.predictions.riskTrend),
                        color: _trendColor(data.predictions.riskTrend),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InsightBanner(text: data.predictions.insight),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Smart Insights'),
            _PanelCard(
              title: 'System-Generated Insights',
              subtitle:
                  'Short insurer-facing observations distilled from live fraud, risk, and prediction data.',
              child: Column(
                children: smartInsights
                    .map(
                      (insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InsightTile(text: insight),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Recommendations'),
            _PanelCard(
              title: 'System-Generated Recommendations',
              subtitle:
                  'Business actions inferred from the live insurer dataset.',
              child: Column(
                children: recommendations
                    .map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecommendationTile(
                          icon: rec.icon,
                          title: rec.title,
                          body: rec.body,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String insight;

  const _AdminHero({
    required this.title,
    required this.subtitle,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2724), Color(0xFF101514)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GigShield Insurer',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          _InsightBanner(text: insight),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final int cardsPerRow;
  final List<Widget> children;

  const _MetricGrid({required this.cardsPerRow, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 14.0;
        final width =
            (constraints.maxWidth - ((cardsPerRow - 1) * spacing)) /
            cardsPerRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: width > 0 ? width : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent ?? AppTheme.primaryColor),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              color: accent ?? AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
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
    );
  }
}

class _SignalStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SignalStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _LabelBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String trailing;

  const _LabelBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: const Color(0xFF101414),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TripleBarChart extends StatelessWidget {
  final List<_ChartDatum> values;

  const _TripleBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(
      0,
      (current, item) => item.value > current ? item.value : current,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.value.toStringAsFixed(0),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        height: max <= 0 ? 0 : (item.value / max) * 140,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HotspotRow extends StatelessWidget {
  final String city;
  final int count;
  final double max;

  const _HotspotRow({
    required this.city,
    required this.count,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppTheme.warningColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  city,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count alerts',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LabelBar(
            label: 'Fraud activity',
            value: count.toDouble(),
            max: max,
            color: AppTheme.warningColor,
            trailing: '$count',
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _RecommendationTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String text;

  const _InsightTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, height: 1.45),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final String text;

  const _InsightBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.textSecondary),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLoadingState extends StatelessWidget {
  const _AdminLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 140),
        const Icon(
          Icons.analytics_outlined,
          size: 36,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(height: 14),
        const Text(
          'Admin dashboard unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () {
            onRetry();
          },
          child: const Text('Reload dashboard'),
        ),
      ],
    );
  }
}

class _ChartDatum {
  final String label;
  final double value;
  final Color color;

  const _ChartDatum(this.label, this.value, this.color);
}

class _RecommendationData {
  final IconData icon;
  final String title;
  final String body;

  const _RecommendationData({
    required this.icon,
    required this.title,
    required this.body,
  });
}

List<_RecommendationData> _buildRecommendations(_AdminDashboardBundle data) {
  final recommendations = <_RecommendationData>[];
  if (data.overview.lossRatio >= 0.8) {
    recommendations.add(
      _RecommendationData(
        icon: Icons.currency_exchange_rounded,
        title: 'Review pricing pressure',
        body:
            'Loss ratio is at ${_percentValue(data.overview.lossRatio)}, so premium adequacy in higher-risk segments should be reviewed.',
      ),
    );
  }
  if (data.fraud.fraudRate >= 0.2) {
    recommendations.add(
      _RecommendationData(
        icon: Icons.shield_moon_outlined,
        title: 'Tighten fraud monitoring',
        body:
            'Fraud pressure is elevated at ${_percentValue(data.fraud.fraudRate)}. Review flagged and rejected claims for repeat patterns.',
      ),
    );
  }
  if (data.risk.topTriggers.isNotEmpty) {
    recommendations.add(
      _RecommendationData(
        icon: Icons.thunderstorm_outlined,
        title: 'Adjust risk strategy in active trigger zones',
        body:
            'Recent risk is being driven by ${data.risk.topTriggers.map(_titleize).join(', ')}, which may justify targeted underwriting attention.',
      ),
    );
  }
  if (data.fraud.hotspots.isNotEmpty) {
    recommendations.add(
      _RecommendationData(
        icon: Icons.location_searching_outlined,
        title: 'Investigate fraud hotspots',
        body:
            'Fraud activity is concentrated in ${data.fraud.hotspots.first.city}. Consider enhanced monitoring for repeated suspicious claims there.',
      ),
    );
  }
  recommendations.add(
    _RecommendationData(
      icon: Icons.timeline_outlined,
      title: 'Plan for next-week claims',
      body: data.predictions.insight,
    ),
  );
  return recommendations;
}

List<String> _buildSmartInsights(_AdminDashboardBundle data) {
  final insights = <String>[];

  if (data.risk.topTriggers.isNotEmpty) {
    insights.add(
      '${_titleize(data.risk.topTriggers.first)} activity is currently the strongest live trigger, which may raise short-term claims pressure.',
    );
  }

  if (data.predictions.riskTrend.toLowerCase() == 'increasing') {
    insights.add(
      'Risk trend is increasing, so payout exposure may rise if current disruption patterns continue.',
    );
  } else if (data.predictions.riskTrend.toLowerCase() == 'decreasing') {
    insights.add(
      'Risk trend is easing, which may reduce claim pressure if conditions remain stable.',
    );
  }

  if (data.fraud.hotspots.isNotEmpty) {
    insights.add(
      'Fraud activity is rising most visibly in ${data.fraud.hotspots.first.city}, making it the top candidate for enhanced review.',
    );
  }

  if (data.fraud.topFraudTypes.isNotEmpty) {
    insights.add(
      '${_fraudLabel(data.fraud.topFraudTypes.first.type)} is the leading fraud signal right now and should remain part of frontline review guidance.',
    );
  }

  if (data.overview.lossRatio >= 0.8) {
    insights.add(
      'Loss ratio is approaching a stressed zone at ${_percentValue(data.overview.lossRatio)}, which suggests underwriting pressure is building.',
    );
  }

  insights.add(data.predictions.insight);
  return insights.take(5).toList();
}

double _maxFraudCount(AdminFraudStatsModel fraud) {
  return fraud.topFraudTypes.fold<double>(
    1,
    (current, item) => item.count > current ? item.count.toDouble() : current,
  );
}

double _maxHotspotCount(List<AdminFraudHotspotModel> hotspots) {
  return hotspots.fold<double>(
    1,
    (current, item) => item.count > current ? item.count.toDouble() : current,
  );
}

String _currency(double value) {
  final formatter = NumberFormat.compactCurrency(symbol: 'Rs ');
  return formatter.format(value);
}

String _percentValue(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}

String _fraudLabel(String type) {
  switch (type.toLowerCase()) {
    case 'gps_spoof':
      return 'GPS Spoofing';
    case 'weather_mismatch':
      return 'Weather Mismatch';
    case 'session_hijack':
      return 'Session Anomaly';
    default:
      return _titleize(type.replaceAll('_', ' '));
  }
}

Color _fraudColor(String type) {
  switch (type.toLowerCase()) {
    case 'gps_spoof':
      return AppTheme.errorColor;
    case 'weather_mismatch':
      return AppTheme.warningColor;
    case 'session_hijack':
      return const Color(0xFFFF8A65);
    default:
      return AppTheme.primaryColor;
  }
}

IconData _trendIcon(String trend) {
  switch (trend.toLowerCase()) {
    case 'increasing':
      return Icons.north_east_rounded;
    case 'decreasing':
      return Icons.south_east_rounded;
    default:
      return Icons.trending_flat_rounded;
  }
}

Color _trendColor(String trend) {
  switch (trend.toLowerCase()) {
    case 'increasing':
      return AppTheme.errorColor;
    case 'decreasing':
      return AppTheme.successColor;
    default:
      return AppTheme.warningColor;
  }
}

String _titleize(String text) {
  return text
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
