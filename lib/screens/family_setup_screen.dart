import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/models/user_profile.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/theme/app_theme.dart';

/// Family setup screen - shown after registration if the user doesn't have a family group yet.
/// For parents: create a family group.
/// For family members: this shouldn't normally be reached (they join via JoinFamilyScreen),
/// but if it is, show a code entry option.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDad = provider.userProfile?.role == UserRole.dad;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Setup'),
        actions: [
          TextButton.icon(
            onPressed: () => provider.signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                isDad ? appConfig.parentEmoji : appConfig.familyMemberEmoji,
                style: const TextStyle(fontSize: 60),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isDad ? 'Create Your Family Group' : 'Join a Family',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDad
                  ? 'Set up your family and share the invite code'
                  : 'Enter the code ${appConfig.parentRole} gave you',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.warmBrown.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (isDad) _CreateFamilySection() else _JoinFamilySection(),
          ],
        ),
      ),
    );
  }
}

class _CreateFamilySection extends StatefulWidget {
  @override
  State<_CreateFamilySection> createState() => _CreateFamilySectionState();
}

class _CreateFamilySectionState extends State<_CreateFamilySection> {
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _createdCode;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final group = await provider.createFamilyGroup(
        _nameController.text.trim(),
      );
      if (group != null) {
        setState(() => _createdCode = group.inviteCode);
      }
    } catch (e) {
      setState(() => _error = 'Failed to create family group');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdCode != null) {
      return _ShareCodeView(code: _createdCode!);
    }

    return Column(
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Family Name',
            hintText: 'e.g. The Smiths',
            prefixIcon: const Icon(Icons.home_outlined),
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _createFamily,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Family Group'),
          ),
        ),
      ],
    );
  }
}

class _ShareCodeView extends StatelessWidget {
  final String code;
  const _ShareCodeView({required this.code});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          color: AppTheme.successGreen,
          size: 60,
        ),
        const SizedBox(height: 16),
        Text(
          'Family Created!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share this code with your family:',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.warmBrown,
          ),
        ),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Code copied!')),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.lightOrange,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryOrange, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.copy, color: AppTheme.primaryOrange),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Or scan this QR code:',
          style: TextStyle(color: AppTheme.warmBrown),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: QrImageView(
            data: '${appConfig.deepLinkScheme}://join/$code',
            version: QrVersions.auto,
            size: 200,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppTheme.darkBrown,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppTheme.darkBrown,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _JoinFamilySection extends StatefulWidget {
  @override
  State<_JoinFamilySection> createState() => _JoinFamilySectionState();
}

class _JoinFamilySectionState extends State<_JoinFamilySection> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final group = await provider.joinFamilyByCode(code.trim().toUpperCase());
      if (group == null) {
        setState(() => _error = 'No family found with this code');
      }
    } catch (e) {
      setState(() => _error = 'Failed to join family');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
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
            onPressed: _loading
                ? null
                : () => _joinFamily(_codeController.text),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Join Family'),
          ),
        ),
      ],
    );
  }
}
