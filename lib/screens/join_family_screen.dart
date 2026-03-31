import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/theme/app_theme.dart';

/// Simplified join flow for family members: code/QR -> name -> done.
class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showScanner = false;
  bool _codeVerified = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final group = await provider.joinFamilyAsGuest(
        name: name,
        inviteCode: code,
      ).timeout(const Duration(seconds: 15));
      if (group == null) {
        await provider.signOut();
        if (mounted) {
          setState(() => _error = 'No family found with code "$code". Check the code and try again.');
        }
      }
      // If successful, AuthGate will route to the main app automatically
    } catch (e) {
      try {
        final provider = context.read<AppProvider>();
        await provider.signOut();
      } catch (_) {}
      if (mounted) {
        setState(() => _error = 'Failed to join: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCodeEntered(String code) {
    _codeController.text = code.toUpperCase();
    setState(() {
      _codeVerified = true;
      _showScanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Family')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.lightOrange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  appConfig.familyMemberEmoji,
                  style: const TextStyle(fontSize: 60),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Join Your Family',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkBrown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask ${appConfig.parentRole} for the 6-digit family code',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.warmBrown.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_showScanner)
                _buildScanner()
              else if (!_codeVerified)
                _buildCodeEntry()
              else
                _buildNameEntry(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      children: [
        // Step indicator
        _StepIndicator(currentStep: 1, totalSteps: 2),
        const SizedBox(height: 24),

        Text(
          'Step 1: Enter Family Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            color: AppTheme.darkBrown,
          ),
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Invite Code',
            hintText: 'ABC123',
            counterText: '',
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppTheme.primaryOrange,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _codeController.text.trim().length == 6
                ? () => _onCodeEntered(_codeController.text)
                : null,
            child: const Text('Next'),
          ),
        ),
        const SizedBox(height: 20),

        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showScanner = true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryOrange,
              side: BorderSide(color: AppTheme.primaryOrange),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameEntry() {
    return Column(
      children: [
        _StepIndicator(currentStep: 2, totalSteps: 2),
        const SizedBox(height: 24),

        Text(
          "Step 2: What's Your Name?",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This is how your family will see you in the app",
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.warmBrown.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 16),

        // Show the code they entered
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.lightOrange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Code: ${_codeController.text}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkBrown,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _codeVerified = false),
                child: Icon(Icons.edit, size: 16, color: AppTheme.warmBrown),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Your Name',
            hintText: 'e.g. Sarah, Tom, etc.',
            prefixIcon: const Icon(Icons.person_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppTheme.primaryOrange,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading || _nameController.text.trim().isEmpty
                ? null
                : _joinFamily,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Join Family!'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Text(
          'Scan the QR code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final value = barcode.rawValue;
                  if (value == null) continue;
                  // Try deep link format: dadaroo://join/ABC123
                  if (value.contains('://join/')) {
                    final code = value.split('://join/').last.trim();
                    if (code.length == 6) {
                      _onCodeEntered(code);
                      return;
                    }
                  }
                  // Also accept raw 6-character code
                  final trimmed = value.trim().toUpperCase();
                  if (trimmed.length == 6 && RegExp(r'^[A-Z0-9]+$').hasMatch(trimmed)) {
                    _onCodeEntered(trimmed);
                    return;
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _showScanner = false),
          child: const Text('Enter code manually'),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i + 1 <= currentStep;
        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppTheme.primaryOrange : Colors.grey.shade300,
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (i < totalSteps - 1)
              Container(
                width: 40,
                height: 2,
                color: isActive ? AppTheme.primaryOrange : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }
}
