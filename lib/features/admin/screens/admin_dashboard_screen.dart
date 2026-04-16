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
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Admin email'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter admin email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Enter password' : null,
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
                      icon: Icon(_loggingIn ? Icons.hourglass_top_rounded : Icons.login_rounded),
                      label: Text(_loggingIn ? 'Signing in...' : 'Open Dashboard'),
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
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
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
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _AdminHero(
              title: 'Decision Dashboard',
              subtitle:
                  'Monitor platform health, detect fraud pressure, and act on predictive insurer insights.',
              insight: data.predictions.insight,
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Overview'),
            _MetricGrid(
              cardsPerRow: cardsPerRow,
              children: [
                _OverviewCard(icon: Icons.people_alt_outlined, label: 'Total Users', value: '${data.overview.totalUsers}'),
                _OverviewCard(icon: Icons.verified_user_outlined, label: 'Active Policies', value: '${data.overview.activePolicies}'),
                _OverviewCard(icon: Icons.assignment_outlined, label: 'Total Claims', value: '${data.overview.totalClaims}'),
                _OverviewCard(icon: Icons.payments_outlined, label: 'Total Payouts', value: _currency(data.overview.totalPayouts)),
                _OverviewCard(icon: Icons.account_balance_wallet_outlined, label: 'Total Premiums', value: _currency(data.overview.totalPremiums)),
                _OverviewCard(
                  icon: Icons.balance_outlined,
                  label: 'Loss Ratio',
                  value: _percentValue(data.overview.lossRatio),
                  accent: data.overview.lossRatio > 1 ? AppTheme.errorColor : AppTheme.warningColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Fraud Analytics'),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _PanelCard(
                          title: 'Fraud Core Signals',
                          subtitle: 'Watch platform fraud pressure and top attack patterns.',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _SignalStat(
                                      icon: Icons.gpp_bad_outlined,
                                      label: 'Fraud Rate',
                                      value: _percentValue(data.fraud.fraudRate),
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
                              ...data.fraud.topFraudTypes.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _LabelBar(
                                      label: _fraudLabel(item.type),
                                      value: item.count.toDouble(),
                                      max: _maxFraudCount(data.fraud),
                                      color: _fraudColor(item.type),
                                      trailing: '${item.count}',
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _PanelCard(
                          title: 'Fraud Hotspots',
                          subtitle: 'City-wise fraud activity from live fraud logs.',
                          child: hotspots.isEmpty
                              ? const _EmptyPanel(
                                  icon: Icons.location_off_outlined,
                                  text: 'No city-level fraud activity is available yet.',
                                )
                              : Column(
                                  children: hotspots
                                      .map((hotspot) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _HotspotRow(
                                              city: hotspot.city,
                                              count: hotspot.count,
                                              max: _maxHotspotCount(hotspots),
                                            ),
                                          ))
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
                        subtitle: 'Watch platform fraud pressure and top attack patterns.',
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
                            ...data.fraud.topFraudTypes.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _LabelBar(
                                    label: _fraudLabel(item.type),
                                    value: item.count.toDouble(),
                                    max: _maxFraudCount(data.fraud),
                                    color: _fraudColor(item.type),
                                    trailing: '${item.count}',
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PanelCard(
                        title: 'Fraud Hotspots',
                        subtitle: 'City-wise fraud activity from live fraud logs.',
                        child: hotspots.isEmpty
                            ? const _EmptyPanel(
                                icon: Icons.location_off_outlined,
                                text: 'No city-level fraud activity is available yet.',
                              )
                            : Column(
                                children: hotspots
                                    .map((hotspot) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _HotspotRow(
                                            city: hotspot.city,
                                            count: hotspot.count,
                                            max: _maxHotspotCount(hotspots),
                                          ),
                                        ))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Claims and Risk'),
            _MetricGrid(
              cardsPerRow: cardsPerRow,
              children: [
                _PanelCard(
                  title: 'Claim Analytics',
                  subtitle: 'Approval, rejection, flagging, and payout profile.',
                  child: Column(
                    children: [
                      _TripleBarChart(
                        values: [
                          _ChartDatum('Approved', data.claims.approved.toDouble(), AppTheme.successColor),
                          _ChartDatum('Rejected', data.claims.rejected.toDouble(), AppTheme.errorColor),
                          _ChartDatum('Flagged', data.claims.flagged.toDouble(), AppTheme.warningColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoLine(label: 'Average payout', value: _currency(data.claims.avgPayout)),
                      _InfoLine(label: 'Average loss', value: _currency(data.claims.avgLoss)),
                    ],
                  ),
                ),
                _PanelCard(
                  title: 'Risk Analytics',
                  subtitle: 'Track systemic risk and the triggers driving platform stress.',
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
                              .map((trigger) => _TriggerChip(label: _titleize(trigger)))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                _PanelCard(
                  title: 'Financial Health',
                  subtitle: 'See how premiums and payouts translate into insurer performance.',
                  child: Column(
                    children: [
                      _InfoLine(label: 'Premiums collected', value: _currency(data.financials.totalPremiums)),
                      _InfoLine(label: 'Total payouts', value: _currency(data.financials.totalPayouts)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (profitPositive ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.12),
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
                                color: profitPositive ? AppTheme.successColor : AppTheme.errorColor,
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
            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
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

  const _MetricGrid({
    required this.cardsPerRow,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 14.0;
        final width = (constraints.maxWidth - ((cardsPerRow - 1) * spacing)) / cardsPerRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width > 0 ? width : constraints.maxWidth, child: child))
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
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
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
              child: Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
            ),
            Text(trailing, style: const TextStyle(color: AppTheme.textSecondary)),
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
