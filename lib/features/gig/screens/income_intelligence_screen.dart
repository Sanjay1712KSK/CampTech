import 'dart:math';

import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class IncomeIntelligenceScreen extends StatefulWidget {
  final int userId;

  const IncomeIntelligenceScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<IncomeIntelligenceScreen> createState() =>
      _IncomeIntelligenceScreenState();
}

class _IncomeIntelligenceScreenState extends State<IncomeIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _partnerIdController = TextEditingController();
  final FocusNode _partnerFocusNode = FocusNode();

  Future<List<dynamic>>? _dataFuture;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  String _selectedPlatform = 'Swiggy';
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.1, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _partnerIdController.dispose();
    _partnerFocusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _fetchData() {
    setState(() {
      _dataFuture = Future.wait([
        ApiService.getBaselineIncome(widget.userId),
        ApiService.getTodayIncome(widget.userId),
        ApiService.getIncomeHistory(widget.userId),
      ]);
    });
  }

  Future<void> _connectAccount() async {
    FocusScope.of(context).unfocus();
    final workerId = _partnerIdController.text.trim();

    if (workerId.isEmpty) {
      setState(() => _connectionError = 'Worker ID cannot be empty');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final result = await ApiService.connectGigAccount(
        userId: widget.userId,
        platform: _selectedPlatform,
        workerId: workerId,
      );
      if (!mounted) return;

      if (result.incomeGenerated) {
        setState(() => _isConnected = true);
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
          ),
        );
      } else {
        setState(() => _connectionError = 'Unable to connect account');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Widget _buildAnimatedSection({
    required Widget child,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: animatedChild),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _fetchData(),
          color: AppTheme.primaryColor,
          child: FutureBuilder<List<dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load insights.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _fetchData,
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final baseline = snapshot.data![0] as BaselineIncomeModel;
              final today = snapshot.data![1] as TodayIncomeModel;
              final history = snapshot.data![2] as IncomeHistoryModel;
              final lossAmount =
                  max(0.0, baseline.baselineDailyIncome - today.earnings);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedSection(
                      index: 0,
                      child: const Text(
                        'Income Intelligence',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAnimatedSection(
                      index: 1,
                      child: const Text(
                        'Connect your gig platform and monitor performance in one place.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      index: 2,
                      child: _ConnectAccountCard(
                        selectedPlatform: _selectedPlatform,
                        onPlatformChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPlatform = value);
                          }
                        },
                        idController: _partnerIdController,
                        focusNode: _partnerFocusNode,
                        onConnect: _connectAccount,
                        isConnecting: _isConnecting,
                        isConnected: _isConnected,
                        errorText: _connectionError,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAnimatedSection(
                      index: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: l10n.todayIncome,
                              value: 'Rs ${today.earnings.toInt()}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: l10n.baselineIncome,
                              value:
                                  'Rs ${baseline.baselineDailyIncome.toInt()}',
                              icon: Icons.insights_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: l10n.orders,
                              value: '${today.ordersCompleted}',
                              icon: Icons.inventory_2_outlined,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (lossAmount > 0)
                      _buildAnimatedSection(
                        index: 4,
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.errorColor.withOpacity(
                                      _glowAnimation.value * 0.25,
                                    ),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.trending_down_rounded,
                                    color: AppTheme.errorColor,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.lossIndicator,
                                          style: const TextStyle(
                                            color: AppTheme.errorColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Disruption: ${today.disruptionType.toUpperCase()} • Loss: Rs ${lossAmount.toInt()}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (lossAmount > 0) const SizedBox(height: 20),
                    _buildAnimatedSection(
                      index: 5,
                      child: _ChartCard(history: history.records),
                    ),
                    const SizedBox(height: 20),
                    if (history.bestDay != null || history.worstDay != null)
                      _buildAnimatedSection(
                        index: 6,
                        child: Row(
                          children: [
                            if (history.bestDay != null)
                              Expanded(
                                child: _ExtremeDayCard(
                                  label: l10n.bestDay,
                                  day: history.bestDay!,
                                  highlightColor: AppTheme.successColor,
                                  icon: Icons.arrow_upward_rounded,
                                ),
                              ),
                            if (history.bestDay != null &&
                                history.worstDay != null)
                              const SizedBox(width: 12),
                            if (history.worstDay != null)
                              Expanded(
                                child: _ExtremeDayCard(
                                  label: l10n.worstDay,
                                  day: history.worstDay!,
                                  highlightColor: AppTheme.errorColor,
                                  icon: Icons.arrow_downward_rounded,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConnectAccountCard extends StatelessWidget {
  final String selectedPlatform;
  final ValueChanged<String?> onPlatformChanged;
  final TextEditingController idController;
  final FocusNode focusNode;
  final VoidCallback onConnect;
  final bool isConnecting;
  final bool isConnected;
  final String? errorText;

  const _ConnectAccountCard({
    required this.selectedPlatform,
    required this.onPlatformChanged,
    required this.idController,
    required this.focusNode,
    required this.onConnect,
    required this.isConnecting,
    required this.isConnected,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect Gig Account',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedPlatform,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Swiggy', child: Text('Swiggy')),
              DropdownMenuItem(value: 'Zomato', child: Text('Zomato')),
            ],
            onChanged: onPlatformChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: idController,
            keyboardType: TextInputType.text,
            focusNode: focusNode,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter Worker ID',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: errorText,
            ),
          ),
          const SizedBox(height: 14),
          if (isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Account connected successfully',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (isConnected) const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isConnecting ? null : onConnect,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isConnecting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Connect Account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<DailyRecord> history;

  const _ChartCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.length > 7
        ? history.sublist(history.length - 7)
        : history;
    final maxEarning =
        recent.isEmpty ? 0.0 : recent.map((e) => e.earnings).reduce(max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Earnings Trend',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          if (recent.isEmpty)
            const Text(
              'No history available yet',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            SizedBox(
              height: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: recent.map((record) {
                  final heightFactor =
                      maxEarning == 0 ? 0.0 : record.earnings / maxEarning;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Rs ${record.earnings.toInt()}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: heightFactor),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Container(
                            width: 26,
                            height: max(14, value * 110),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _shortDate(record.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _shortDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return date;
    }
  }
}

class _ExtremeDayCard extends StatelessWidget {
  final String label;
  final DailyRecord day;
  final Color highlightColor;
  final IconData icon;

  const _ExtremeDayCard({
    required this.label,
    required this.day,
    required this.highlightColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlightColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlightColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: highlightColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: highlightColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            day.date,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs ${day.earnings.toInt()}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${day.orders} orders',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
