import 'package:shared_preferences/shared_preferences.dart';

class BankSummary {
  final bool bankLinked;
  final String? maskedAccountNumber;
  final String? ifsc;
  final double totalPaid;
  final double totalClaimed;
  final double netGain;
  final double lastPayout;
  final DateTime? policyStart;
  final DateTime? policyEnd;
  final String policyStatus;
  final bool claimReady;
  final String claimMessage;
  final String lastWeekSummary;

  const BankSummary({
    required this.bankLinked,
    required this.maskedAccountNumber,
    required this.ifsc,
    required this.totalPaid,
    required this.totalClaimed,
    required this.netGain,
    required this.lastPayout,
    required this.policyStart,
    required this.policyEnd,
    required this.policyStatus,
    required this.claimReady,
    required this.claimMessage,
    required this.lastWeekSummary,
  });
}

class BankService {
  static const _bankLinkedKey = 'mock_bank_linked';
  static const _accountNumberKey = 'mock_bank_account_number';
  static const _ifscKey = 'mock_bank_ifsc';
  static const _totalPaidKey = 'mock_total_paid';
  static const _totalClaimedKey = 'mock_total_claimed';
  static const _lastWeekPremiumKey = 'mock_last_week_premium';
  static const _lastWeekClaimKey = 'mock_last_week_claim';
  static const _premiumPaidKey = 'mock_has_paid_premium';
  static const _policyStartKey = 'mock_policy_start';
  static const _policyEndKey = 'mock_policy_end';
  static const _lastPayoutKey = 'mock_last_payout';

  static String _maskAccount(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  static Future<bool> linkBank({
    String accountNumber = '123456789012',
    String ifsc = 'HDFC0001234',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bankLinkedKey, true);
    await prefs.setString(_accountNumberKey, accountNumber);
    await prefs.setString(_ifscKey, ifsc.toUpperCase());
    return true;
  }

  static Future<bool> payPremium(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final totalPaid = prefs.getDouble(_totalPaidKey) ?? 0.0;
    final lastWeekPremium = prefs.getDouble(_lastWeekPremiumKey) ?? 0.0;
    final start = DateTime.now();
    final end = start.add(const Duration(days: 7));

    await prefs.setDouble(_totalPaidKey, totalPaid + amount);
    await prefs.setDouble(_lastWeekPremiumKey, lastWeekPremium + amount);
    await prefs.setBool(_premiumPaidKey, true);
    await prefs.setString(_policyStartKey, start.toIso8601String());
    await prefs.setString(_policyEndKey, end.toIso8601String());
    return true;
  }

  static Future<bool> payoutClaim(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final totalClaimed = prefs.getDouble(_totalClaimedKey) ?? 0.0;
    final lastWeekClaim = prefs.getDouble(_lastWeekClaimKey) ?? 0.0;
    await prefs.setDouble(_totalClaimedKey, totalClaimed + amount);
    await prefs.setDouble(_lastWeekClaimKey, lastWeekClaim + amount);
    await prefs.setDouble(_lastPayoutKey, amount);
    return true;
  }

  static Future<BankSummary> getSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final bankLinked = prefs.getBool(_bankLinkedKey) ?? false;
    final accountNumber = prefs.getString(_accountNumberKey);
    final ifsc = prefs.getString(_ifscKey);
    final totalPaid = prefs.getDouble(_totalPaidKey) ?? 0.0;
    final totalClaimed = prefs.getDouble(_totalClaimedKey) ?? 0.0;
    final lastWeekPremium = prefs.getDouble(_lastWeekPremiumKey) ?? 0.0;
    final lastWeekClaim = prefs.getDouble(_lastWeekClaimKey) ?? 0.0;
    final lastPayout = prefs.getDouble(_lastPayoutKey) ?? 0.0;
    final policyStartRaw = prefs.getString(_policyStartKey);
    final policyEndRaw = prefs.getString(_policyEndKey);
    final policyStart =
        policyStartRaw != null ? DateTime.tryParse(policyStartRaw) : null;
    final policyEnd =
        policyEndRaw != null ? DateTime.tryParse(policyEndRaw) : null;

    String policyStatus = 'NOT PURCHASED';
    bool claimReady = false;
    String claimMessage = 'Buy weekly insurance to activate claims';
    if (policyStart != null && policyEnd != null) {
      if (DateTime.now().isAfter(policyEnd)) {
        policyStatus = 'EXPIRED';
        claimReady = true;
        claimMessage = 'Ready to claim';
      } else {
        policyStatus = 'ACTIVE';
        claimReady = false;
        claimMessage = 'Claim available after policy ends';
      }
    }

    return BankSummary(
      bankLinked: bankLinked,
      maskedAccountNumber:
          accountNumber != null ? _maskAccount(accountNumber) : null,
      ifsc: ifsc,
      totalPaid: totalPaid,
      totalClaimed: totalClaimed,
      netGain: totalClaimed - totalPaid,
      lastPayout: lastPayout,
      policyStart: policyStart,
      policyEnd: policyEnd,
      policyStatus: policyStatus,
      claimReady: claimReady,
      claimMessage: claimMessage,
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
