import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/signup_screen.dart';
import 'package:guidewire_gig_ins/features/verification/screens/digilocker_verification_screen.dart';
import 'package:guidewire_gig_ins/main.dart';
import 'package:guidewire_gig_ins/services/bank_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  static const _biometricPrefKey = 'biometric_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricEnabled = false;
  bool _isLoadingBiometric = true;
  Future<BankSummary>? _bankFuture;

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
    _bankFuture = BankService.getSummary();
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
      _isLoadingBiometric = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (!value) {
      await prefs.remove(_biometricPrefKey);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      return;
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        throw Exception('Biometric authentication is not available');
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Enable fingerprint login for your account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric setup was cancelled');
      }

      await prefs.setBool(_biometricPrefKey, true);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final policyStatus = user.isVerified ? 'ACTIVE' : 'INACTIVE';
    final verificationStatus = user.isVerified ? 'VERIFIED' : 'NOT VERIFIED';

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _PolicyCard(
              userName: user.userName,
              userId: user.userId,
              policyStatus: policyStatus,
              verificationStatus: verificationStatus,
            ),
            const SizedBox(height: 20),
            if (!user.isVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DigilockerVerificationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Verify Identity'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Financial Tracking'),
            FutureBuilder<BankSummary>(
              future: _bankFuture,
              builder: (context, snapshot) {
                final bank = snapshot.data;
                return _SettingsCard(
                  children: [
                    _InfoTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Paid',
                      value:
                          'Rs ${(bank?.totalPaid ?? 0).toStringAsFixed(0)}',
                    ),
                    _DividerLine(),
                    _InfoTile(
                      icon: Icons.payments_outlined,
                      label: 'Total Claimed',
                      value:
                          'Rs ${(bank?.totalClaimed ?? 0).toStringAsFixed(0)}',
                    ),
                    _DividerLine(),
                    _InfoTile(
                      icon: Icons.show_chart_rounded,
                      label: 'Net Gain',
                      value: 'Rs ${(bank?.netGain ?? 0).toStringAsFixed(0)}',
                    ),
                    _DividerLine(),
                    _InfoTile(
                      icon: Icons.calendar_view_week_rounded,
                      label: 'Last Week',
                      value: bank?.lastWeekSummary ?? 'No activity yet',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Security'),
            _SettingsCard(
              children: [
                SwitchListTile.adaptive(
                  value: _biometricEnabled,
                  onChanged: _isLoadingBiometric ? null : _toggleBiometric,
                  activeColor: AppTheme.primaryColor,
                  title: const Text(
                    'Enable Fingerprint Login',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _biometricEnabled
                        ? 'Biometric login is active on this device'
                        : 'Use fingerprint to unlock the app faster',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Account'),
            _SettingsCard(
              children: [
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Name',
                  value: user.userName,
                ),
                _DividerLine(),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email.isNotEmpty ? user.email : 'Not available',
                ),
                _DividerLine(),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user.phone.isNotEmpty ? user.phone : 'Not available',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Language'),
            _LanguageCard(currentLanguage: Localizations.localeOf(context).languageCode),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Actions'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.errorColor,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Sign out from this device',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_biometricPrefKey);
                    if (!mounted) return;
                    ref.read(userProvider.notifier).logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final String userName;
  final int userId;
  final String policyStatus;
  final String verificationStatus;

  const _PolicyCard({
    required this.userName,
    required this.userId,
    required this.policyStatus,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = policyStatus == 'ACTIVE';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2F3B2F),
            Color(0xFF1F2921),
            Color(0xFF121612),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.successColor.withOpacity(0.18)
                      : AppTheme.warningColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  policyStatus,
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Policy Type: Gig Income Protection',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CardFact(label: 'User ID', value: '#$userId'),
              ),
              Expanded(
                child: _CardFact(
                  label: 'Verification',
                  value: verificationStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardFact extends StatelessWidget {
  final String label;
  final String value;

  const _CardFact({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String currentLanguage;

  const _LanguageCard({required this.currentLanguage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentLanguage,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceColor,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
          icon: const Icon(
            Icons.language_rounded,
            color: AppTheme.textSecondary,
          ),
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
            if (newLang == null) return;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('app_language', newLang);
            appLocale.value = Locale(newLang);
          },
        ),
      ),
    );
  }
}
