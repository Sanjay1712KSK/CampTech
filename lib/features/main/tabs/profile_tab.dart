import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/signup_screen.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidewire_gig_ins/main.dart'; // import appLocale

class ProfileTab extends StatelessWidget {
  final int userId;
  final String userName;
  final bool isVerified;

  const ProfileTab({
    Key? key,
    required this.userId,
    required this.userName,
    this.isVerified = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profile, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 28),

            // ── Avatar + Name ───────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('ID: #$userId', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Verification Status ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isVerified ? AppTheme.successColor.withOpacity(0.3) : AppTheme.errorColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isVerified ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    color: isVerified ? AppTheme.successColor : AppTheme.errorColor,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? l10n.verified.replaceAll(' ✔','') : l10n.notVerified,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isVerified ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified ? 'DigiLocker • Blockchain Secured' : 'Complete DigiLocker verification',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Info rows ───────────────────────────────────────────
            const Text('Account Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _InfoRow(icon: Icons.person_outline, label: 'Name', value: userName),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.tag_rounded, label: 'User ID', value: '#$userId'),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.policy_rounded, label: l10n.activePolicy, value: 'POL-391X'),

            const SizedBox(height: 24),

            // ── Language Switcher ───────────────────────────────────
            const Text('Language', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: Localizations.localeOf(context).languageCode,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceColor,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  icon: const Icon(Icons.language_rounded, color: AppTheme.textSecondary),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English (en)')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                    DropdownMenuItem(value: 'ta', child: Text('Tamil (ta)')),
                    DropdownMenuItem(value: 'te', child: Text('Telugu (te)')),
                    DropdownMenuItem(value: 'kn', child: Text('Kannada (kn)')),
                    DropdownMenuItem(value: 'mr', child: Text('Marathi (mr)')),
                    DropdownMenuItem(value: 'ur', child: Text('Urdu (ur)')),
                  ],
                  onChanged: (String? newLang) async {
                    if (newLang != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('app_language', newLang);
                      appLocale.value = Locale(newLang);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Logout ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.errorColor),
                label: const Text('Log Out', style: TextStyle(color: AppTheme.errorColor)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
