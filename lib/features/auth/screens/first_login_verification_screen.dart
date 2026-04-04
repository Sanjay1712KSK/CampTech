import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/custom_text_field.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/features/auth/auth_flow_helper.dart';
import 'package:guidewire_gig_ins/features/dashboard/screens/dashboard_loader.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class FirstLoginVerificationScreen extends ConsumerStatefulWidget {
  final String challengeToken;
  final List<String> availableChannels;

  const FirstLoginVerificationScreen({
    super.key,
    required this.challengeToken,
    required this.availableChannels,
  });

  @override
  ConsumerState<FirstLoginVerificationScreen> createState() => _FirstLoginVerificationScreenState();
}

class _FirstLoginVerificationScreenState extends ConsumerState<FirstLoginVerificationScreen> {
  final _otpController = TextEditingController();
  String? _selectedChannel;
  SendOtpResult? _deliveryResult;
  bool _isSending = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.availableChannels.contains('phone')
        ? 'phone'
        : (widget.availableChannels.isNotEmpty ? widget.availableChannels.first : null);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_selectedChannel == null) return;
    setState(() => _isSending = true);
    try {
      final result = await ApiService.sendFirstLoginOtp(
        challengeToken: widget.challengeToken,
        channel: _selectedChannel!,
      );
      if (!mounted) return;
      setState(() => _deliveryResult = result);
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
    if (_selectedChannel == null) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP first.')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final result = await ApiService.verifyFirstLoginOtp(
        challengeToken: widget.challengeToken,
        channel: _selectedChannel!,
        otp: otp,
      );
      if (!mounted) return;
      await AuthFlowHelper.finalizeAuthenticatedSession(context, ref, result);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardLoader()),
        (route) => false,
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
    DeliveryPreview? delivery;
    if (_deliveryResult != null && _deliveryResult!.deliveries.isNotEmpty) {
      delivery = _deliveryResult!.deliveries.first;
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'First-time login verification',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Choose one channel for your one-time first login verification.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedChannel,
                decoration: const InputDecoration(
                  labelText: 'Verification channel',
                ),
                items: widget.availableChannels
                    .map(
                      (channel) => DropdownMenuItem(
                        value: channel,
                        child: Text(channel == 'email' ? 'Email' : 'Phone'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedChannel = value;
                    _deliveryResult = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: delivery == null
                    ? const Text('Send an OTP to your chosen channel to continue.')
                    : Text(
                        delivery.channel == 'phone'
                            ? 'Phone OTP sent to ${delivery.destination}\nDemo OTP: ${delivery.mockOtp ?? ""}'
                            : 'Email OTP sent to ${delivery.destination}',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: _isSending ? 'Sending OTP...' : 'Send OTP',
                isLoading: _isSending,
                onPressed: _sendOtp,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _otpController,
                hintText: _selectedChannel == 'email' ? 'Email OTP' : 'Phone OTP',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: _isVerifying ? 'Verifying...' : 'Verify and continue',
                isLoading: _isVerifying,
                onPressed: _verifyOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
