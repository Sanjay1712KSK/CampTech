import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/login_screen.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/features/risk/screens/risk_dashboard_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class DashboardLoader extends ConsumerStatefulWidget {
  const DashboardLoader({super.key});

  @override
  ConsumerState<DashboardLoader> createState() => _DashboardLoaderState();
}

class _DashboardLoaderState extends ConsumerState<DashboardLoader> {
  bool _isLoading = true;
  bool _isGigConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGigStatus();
    });
  }

  Future<void> _checkGigStatus() async {
    final user = ref.read(userProvider);
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Your session is unavailable. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await ApiService.getGigStatus(user.userId);
      if (!mounted) return;
      setState(() {
        _isGigConnected = status.connected;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const LoginScreen();
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _checkGigStatus,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unable to load your dashboard',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checkGigStatus,
                          child: const Text('Retry'),
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

    if (!_isGigConnected) {
      return ConnectGigScreen(
        userId: user.userId,
        redirectToRiskOnSuccess: true,
      );
    }

    return RiskDashboardScreen(userId: user.userId);
  }
}
