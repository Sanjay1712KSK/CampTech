import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/features/gig/screens/connect_gig_screen.dart';
import 'package:guidewire_gig_ins/features/gig/screens/income_intelligence_screen.dart';

class InsightsTab extends StatefulWidget {
  final int userId;

  const InsightsTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  bool _isConnected = false;

  void _connectAccount() async {
    final connected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConnectGigScreen(userId: widget.userId)),
    );
    if (connected == true) {
      setState(() => _isConnected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return IncomeIntelligenceScreen(userId: widget.userId);
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hub_rounded, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              Text(
                l10n.incomeIntelligence,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Connect your gig platform to unlock real-time earnings analytics, baseline comparisons, and risk coverage.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _connectAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    l10n.connectGigAccount,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
