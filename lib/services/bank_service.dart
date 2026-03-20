import 'package:shared_preferences/shared_preferences.dart';

class BankSummary {
  final bool bankLinked;
  final double totalPaid;
  final double totalClaimed;
  final double netGain;
  final String lastWeekSummary;

  const BankSummary({
    required this.bankLinked,
    required this.totalPaid,
    required this.totalClaimed,
    required this.netGain,
    required this.lastWeekSummary,
  });
}

class BankService {
  static const _bankLinkedKey = 'mock_bank_linked';
  static const _totalPaidKey = 'mock_total_paid';
  static const _totalClaimedKey = 'mock_total_claimed';
  static const _lastWeekPremiumKey = 'mock_last_week_premium';
  static const _lastWeekClaimKey = 'mock_last_week_claim';
  static const _premiumPaidKey = 'mock_has_paid_premium';

  static Future<bool> linkBank() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bankLinkedKey, true);
    return true;
  }

  static Future<bool> payPremium(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final totalPaid = prefs.getDouble(_totalPaidKey) ?? 0.0;
    final lastWeekPremium = prefs.getDouble(_lastWeekPremiumKey) ?? 0.0;
    await prefs.setDouble(_totalPaidKey, totalPaid + amount);
    await prefs.setDouble(_lastWeekPremiumKey, lastWeekPremium + amount);
    await prefs.setBool(_premiumPaidKey, true);
    return true;
  }

  static Future<bool> payoutClaim(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final totalClaimed = prefs.getDouble(_totalClaimedKey) ?? 0.0;
    final lastWeekClaim = prefs.getDouble(_lastWeekClaimKey) ?? 0.0;
    await prefs.setDouble(_totalClaimedKey, totalClaimed + amount);
    await prefs.setDouble(_lastWeekClaimKey, lastWeekClaim + amount);
    return true;
  }

  static Future<BankSummary> getSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final bankLinked = prefs.getBool(_bankLinkedKey) ?? false;
    final totalPaid = prefs.getDouble(_totalPaidKey) ?? 0.0;
    final totalClaimed = prefs.getDouble(_totalClaimedKey) ?? 0.0;
    final lastWeekPremium = prefs.getDouble(_lastWeekPremiumKey) ?? 0.0;
    final lastWeekClaim = prefs.getDouble(_lastWeekClaimKey) ?? 0.0;

    return BankSummary(
      bankLinked: bankLinked,
      totalPaid: totalPaid,
      totalClaimed: totalClaimed,
      netGain: totalClaimed - totalPaid,
      lastWeekSummary:
          'Last 7 days: paid Rs ${lastWeekPremium.toStringAsFixed(0)}, claimed Rs ${lastWeekClaim.toStringAsFixed(0)}',
    );
  }

  static Future<bool> hasPaidPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_premiumPaidKey) ?? false) ||
        ((prefs.getDouble(_totalPaidKey) ?? 0.0) > 0);
  }
}
