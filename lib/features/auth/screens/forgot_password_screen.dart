import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/custom_text_field.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  int? _userId;
  String? _resetToken;
  List<DeliveryPreview> _deliveries = const [];
  int _step = 1;

  @override
  void dispose() {
    _identifierController.dispose();
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email, username, or phone first.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.forgotPassword(identifier);
      if (!mounted) return;
      setState(() {
        _userId = result.userId;
        _deliveries = result.deliveries;
        _step = 2;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.verifyResetOtp(
        userId: _userId!,
        emailOtp: _emailOtpController.text.trim(),
        phoneOtp: _phoneOtpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = result.resetToken;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_resetToken == null) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.resetPassword(
        resetToken: _resetToken!,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset complete. You can log in now.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recover access',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'We use the same dual-channel OTP flow for password recovery.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              if (_step == 1) ...[
                CustomTextField(
                  controller: _identifierController,
                  hintText: 'Email / Username / Phone',
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: _isLoading ? 'Sending OTPs...' : 'Send reset OTPs',
                  isLoading: _isLoading,
                  onPressed: _requestReset,
                ),
              ],
              if (_step == 2) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _deliveries
                        .map(
                          (delivery) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${delivery.channel.toUpperCase()}: ${delivery.destination}\nDemo OTP: ${delivery.mockOtp}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailOtpController,
                  hintText: 'Email OTP',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneOtpController,
                  hintText: 'Phone OTP',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.sms_outlined, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: _isLoading ? 'Verifying...' : 'Verify reset OTPs',
                  isLoading: _isLoading,
                  onPressed: _verifyOtp,
                ),
              ],
              if (_step == 3) ...[
                CustomTextField(
                  controller: _passwordController,
                  hintText: 'New Password',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use at least 8 characters with uppercase, lowercase, number, and special character.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: _isLoading ? 'Updating...' : 'Reset password',
                  isLoading: _isLoading,
                  onPressed: _resetPassword,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
