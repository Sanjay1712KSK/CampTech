import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/custom_text_field.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/auth/screens/account_confirmation_screen.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String password;
  final String email;
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.password,
    required this.email,
    required this.phone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _emailOtpController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  bool _isSending = true;
  bool _isVerifying = false;
  SendOtpResult? _otpResult;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _isSending = true);
    try {
      final result = await ApiService.sendOtp(userId: widget.userId);
      if (!mounted) return;
      setState(() => _otpResult = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final emailOtp = _emailOtpController.text.trim();
    final phoneOtp = _phoneOtpController.text.trim();
    if (emailOtp.length != 6 || phoneOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both 6-digit OTP codes.')),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final result = await ApiService.verifyOtp(
        userId: widget.userId,
        emailOtp: emailOtp,
        phoneOtp: phoneOtp,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AccountConfirmationScreen(
            userId: widget.userId,
            username: widget.username,
            password: widget.password,
            email: widget.email,
            phone: widget.phone,
            confirmationToken: result.confirmationToken,
            confirmationLink: result.confirmationLink,
            appConfirmationLink: result.appConfirmationLink,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = _otpResult?.deliveries ?? const <DeliveryPreview>[];
    DeliveryPreview? emailDelivery;
    DeliveryPreview? phoneDelivery;
    for (final delivery in deliveries) {
      if (delivery.channel == 'email') {
        emailDelivery = delivery;
      } else if (delivery.channel == 'phone') {
        phoneDelivery = delivery;
      }
    }
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
                'Verify contact channels',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent separate OTPs to your email and phone so we can activate your onboarding securely.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (emailDelivery != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                emailDelivery.status == 'sent'
                                    ? 'Email OTP sent to ${emailDelivery.destination}'
                                    : 'Email OTP could not be sent to ${emailDelivery.destination}. ${emailDelivery.errorMessage ?? 'Please retry.'}',
                                style: const TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                          if (phoneDelivery != null)
                            Text(
                              'Phone OTP sent to ${phoneDelivery.destination}\nDemo OTP: ${phoneDelivery.mockOtp ?? ""}',
                              style: const TextStyle(color: AppTheme.textPrimary),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
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
                text: _isVerifying ? 'Verifying...' : 'Verify OTPs',
                isLoading: _isVerifying,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSending ? null : _sendOtp,
                child: const Text('Resend OTPs'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
