import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';

class BackendConfigSheet extends StatefulWidget {
  const BackendConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BackendConfigSheet(),
    );
  }

  @override
  State<BackendConfigSheet> createState() => _BackendConfigSheetState();
}

class _BackendConfigSheetState extends State<BackendConfigSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _anonKeyController;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: SupabaseConfig.activeUrl);
    _anonKeyController = TextEditingController(text: SupabaseConfig.activeAnonKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final url = _urlController.text.trim();
    final anon = _anonKeyController.text.trim();

    if (url.isEmpty || !url.startsWith('https://')) {
      setState(() {
        _statusMessage = 'Please enter a valid Supabase URL starting with https://';
        _isSuccess = false;
      });
      return;
    }

    if (anon.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your project anon public key.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await SupabaseConfig.saveCustomBackend(url: url, anonKey: anon);
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _statusMessage = 'Backend connected & saved successfully!';
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Failed to configure backend: $e';
      });
    }
  }

  Future<void> _handleReset() async {
    await SupabaseConfig.resetToDefault();
    setState(() {
      _urlController.text = SupabaseConfig.activeUrl;
      _anonKeyController.text = SupabaseConfig.activeAnonKey;
      _statusMessage = 'Reset to default configuration.';
      _isSuccess = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supabase Backend Setup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Configure Project URL & Anon Key',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info box on where to get keys
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How to get your credentials:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryDark),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Go to supabase.com -> Your Project\n'
                    '2. Navigate to Project Settings -> API\n'
                    '3. Copy Project URL and Project API Key (anon / public)',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status banner if present
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      color: _isSuccess ? AppColors.success : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? AppColors.success : AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Text('Supabase Project URL', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://xxxxxxxxxxxx.supabase.co',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),

            Text('Supabase Anon Public Key', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            TextField(
              controller: _anonKeyController,
              decoration: InputDecoration(
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleReset,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Reset Default'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save & Connect',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
