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
