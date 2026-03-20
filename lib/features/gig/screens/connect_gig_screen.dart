import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

class ConnectGigScreen extends ConsumerStatefulWidget {
  const ConnectGigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConnectGigScreen> createState() => _ConnectGigScreenState();
}

class _ConnectGigScreenState extends ConsumerState<ConnectGigScreen> {
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  String _selectedPlatform = 'Swiggy';
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _idFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    FocusScope.of(context).unfocus();
    final partnerId = _idController.text.trim();

    if (partnerId.isEmpty) {
      setState(() => _error = 'Partner ID is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(userProvider);
      if (user == null) throw Exception('User not logged in');

      final success = await ApiService.connectGigAccount(
        userId: user.userId,
        platform: _selectedPlatform.toLowerCase(),
        partnerId: partnerId,
      );
      if (!mounted) return;

      if (success) {
        setState(() => _isConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_selectedPlatform account connected successfully',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'Unable to connect account right now');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                'Link your earnings source',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your partner ID to connect your delivery account and unlock insights.',
                style: TextStyle(
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
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
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
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _idController,
                      keyboardType: TextInputType.text,
                      focusNode: _idFocusNode,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: l10n?.enterIdOrPhone ?? 'Enter Partner ID',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isConnected)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Account connected. Earnings data is now ready.',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_isConnected) const SizedBox(height: 16),
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
                            : const Text('Connect Account'),
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
