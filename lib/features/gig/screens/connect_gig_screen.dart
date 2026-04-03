import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/main/main_shell.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';

class ConnectGigScreen extends ConsumerStatefulWidget {
  final int? userId;
  final String? identifier;
  final String? password;
  final bool isOnboardingFlow;

  const ConnectGigScreen({
    super.key,
    this.userId,
    this.identifier,
    this.password,
    this.isOnboardingFlow = false,
  });

  @override
  ConsumerState<ConnectGigScreen> createState() => _ConnectGigScreenState();
}

class _ConnectGigScreenState extends ConsumerState<ConnectGigScreen> {
  final TextEditingController _idController = TextEditingController();

  String _selectedPlatform = 'Swiggy';
  bool _isLoading = false;
  String? _error;

  int? get _resolvedUserId => widget.userId ?? ref.read(userProvider)?.userId;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final userId = _resolvedUserId;
    final partnerId = _idController.text.trim();
    if (userId == null) {
      setState(() => _error = 'User session not found');
      return;
    }
    if (partnerId.isEmpty) {
      setState(() => _error = 'Partner ID is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ApiService.connectGigAccount(
        userId: userId,
        platform: _selectedPlatform.toLowerCase(),
        partnerId: partnerId,
      );

      if (widget.isOnboardingFlow && widget.identifier != null && widget.password != null) {
        final login = await ApiService.login(
          identifier: widget.identifier!,
          password: widget.password!,
        );
        await AuthStorageService.saveSession(
          accessToken: login.accessToken,
          user: login.user,
        );
        if (!mounted) return;
        ref.read(userProvider.notifier).setAuthenticatedUser(
              login.user,
              accessToken: login.accessToken,
            );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedPlatform account connected successfully')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Connect Gig Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect your income source',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isOnboardingFlow
                    ? 'Final onboarding step: link a gig platform and we will generate 30 days of earnings history.'
                    : 'Link your delivery partner account to refresh your earnings data.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPlatform,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Swiggy', child: Text('Swiggy')),
                        DropdownMenuItem(value: 'Zomato', child: Text('Zomato')),
                        DropdownMenuItem(value: 'Blinkit', child: Text('Blinkit')),
                        DropdownMenuItem(value: 'Porter', child: Text('Porter')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPlatform = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Partner ID',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _idController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter your platform partner ID',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleConnect,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(widget.isOnboardingFlow ? 'Finish onboarding' : 'Connect account'),
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
}
