import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/core/widgets/primary_button.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

enum VerificationStatus { notVerified, verifying, verified }

class DigilockerVerificationScreen extends StatefulWidget {
  final int userId;

  const DigilockerVerificationScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<DigilockerVerificationScreen> createState() => _DigilockerVerificationScreenState();
}

class _DigilockerVerificationScreenState extends State<DigilockerVerificationScreen> {
  String? _selectedDocument;
  VerificationStatus _status = VerificationStatus.notVerified;

  void _verifyNow() async {
    if (_selectedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document type first')),
      );
      return;
    }

    setState(() {
      _status = VerificationStatus.verifying;
    });

    try {
      final success = await ApiService.verifyIdentity(
        userId: widget.userId,
        documentType: _selectedDocument!,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _status = VerificationStatus.verified;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verified ✔')),
        );
      } else {
        setState(() {
          _status = VerificationStatus.notVerified;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed. Try again.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = VerificationStatus.notVerified;
      });
      final message = error.toString().contains('SocketException')
          ? 'Server not reachable'
          : 'Verification service unavailable';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify Your Identity',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Required to activate insurance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 40),
              if (_status == VerificationStatus.verified) ...[
                _buildSuccessState(),
              ] else ...[
                _buildDocumentSelection(),
                const SizedBox(height: 24),
                _buildMockUploadButton(),
                const SizedBox(height: 24),
                _buildStatusIndicator(),
                const SizedBox(height: 40),
                PrimaryButton(
                  text: _status == VerificationStatus.verifying ? 'Verifying...' : 'Verify Now',
                  isLoading: _status == VerificationStatus.verifying,
                  onPressed: _verifyNow,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Document',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DocumentCard(
                title: 'Aadhaar Card',
                icon: Icons.credit_card,
                isSelected: _selectedDocument == 'Aadhaar Card',
                onTap: () {
                  setState(() {
                    _selectedDocument = 'Aadhaar Card';
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DocumentCard(
                title: 'Driving License',
                icon: Icons.drive_eta,
                isSelected: _selectedDocument == 'Driving License',
                onTap: () {
                  setState(() {
                    _selectedDocument = 'Driving License';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMockUploadButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Tap to upload document',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Supported formats: JPG, PNG, PDF',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_status) {
      case VerificationStatus.notVerified:
        statusColor = AppTheme.errorColor;
        statusText = 'Not Verified';
        statusIcon = Icons.cancel_outlined;
        break;
      case VerificationStatus.verifying:
        statusColor = AppTheme.warningColor;
        statusText = 'Verifying...';
        statusIcon = Icons.hourglass_empty;
        break;
      case VerificationStatus.verified:
        statusColor = AppTheme.successColor;
        statusText = 'Verified';
        statusIcon = Icons.check_circle_outline;
        break;
    }

    return Row(
      children: [
        Text('Status: ', style: Theme.of(context).textTheme.bodyLarge),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Identity Verified ✔',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const _SuccessListItem(text: 'DigiLocker Verified'),
          const SizedBox(height: 12),
          const _SuccessListItem(text: 'Secured with Blockchain 🔗'),
          const SizedBox(height: 40),
          PrimaryButton(
            text: 'Continue to Dashboard',
            onPressed: () {
              Navigator.pop(context); // Demo go back
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessListItem extends StatelessWidget {
  final String text;

  const _SuccessListItem({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DocumentCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
