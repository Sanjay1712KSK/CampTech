import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/bank_service.dart';

class LinkBankScreen extends ConsumerStatefulWidget {
  const LinkBankScreen({super.key});

  @override
  ConsumerState<LinkBankScreen> createState() => _LinkBankScreenState();
}

class _LinkBankScreenState extends ConsumerState<LinkBankScreen> {
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accountController.text = '123456789012';
    _ifscController.text = 'HDFC0001234';
  }

  @override
  void dispose() {
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(userProvider);
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService.linkBankAccount(
        user.userId,
        accountNumber: _accountController.text.trim(),
        ifsc: _ifscController.text.trim(),
      );
      await BankService.linkBank(
        accountNumber: _accountController.text.trim(),
        ifsc: _ifscController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account linked')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Link Bank'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect your payout account',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Premium payments and claim payouts will flow through this linked bank account.',
                        style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _accountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.length < 8) {
                            return 'Enter a valid account number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ifscController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'IFSC',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.length < 4) return 'Enter a valid IFSC';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? 'Linking...' : 'Link Bank Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
