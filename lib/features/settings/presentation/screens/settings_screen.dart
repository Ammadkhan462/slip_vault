import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/settings/data/auth_service.dart';
import 'package:slip_vault/features/settings/data/backup_service.dart';
import 'package:slip_vault/features/settings/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPro = ref.watch(proStatusProvider);
    final isAppLock = ref.watch(appLockProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (isPro)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Text('PRO ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.workspace_premium, size: 16, color: AppColors.secondary),
              label: const Text('Get Pro', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
              onPressed: () => context.push('/paywall'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Security Section
            Text('SECURITY & PRIVACY', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('App Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Require biometric fingerprint or PIN upon opening'),
                    value: isAppLock,
                    activeThumbColor: AppColors.primaryContainer,
                    onChanged: (val) async {
                      if (!isPro && val) {
                        context.push('/paywall');
                        return;
                      }
                      if (val) {
                        final authenticated = await AuthService.authenticate();
                        if (authenticated) {
                          ref.read(appLockProvider.notifier).setLock(true);
                        }
                      } else {
                        ref.read(appLockProvider.notifier).setLock(false);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: AppColors.primaryContainer),
                    title: const Text('Export Local Backup (ZIP)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Archive SQLite database and images into zip file'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      if (!isPro) {
                        context.push('/paywall');
                        return;
                      }
                      final file = await BackupService.createBackupZip();
                      await SharePlus.instance.share(
                        ShareParams(files: [XFile(file.path)], text: 'Slip Vault Backup Zip Archive'),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Display & Localization
            Text('DISPLAY & LANGUAGE', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate, color: AppColors.primaryContainer),
                    title: const Text('Language / زبان', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(currentLocale.languageCode == 'ur' ? 'اردو (Urdu RTL)' : 'English'),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN')),
                        ButtonSegment(value: 'ur', label: Text('اردو')),
                      ],
                      selected: {currentLocale.languageCode},
                      onSelectionChanged: (val) {
                        ref.read(localeProvider.notifier).setLocale(Locale(val.first));
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: AppColors.primaryContainer),
                    title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(currentThemeMode.name.toUpperCase()),
                    trailing: DropdownButton<ThemeMode>(
                      value: currentThemeMode,
                      underline: const SizedBox(),
                      onChanged: (mode) {
                        if (mode != null) {
                          ref.read(themeModeProvider.notifier).setThemeMode(mode);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About & Legal
            Text('ABOUT & LEGAL', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('100% offline, zero cloud servers, zero analytics'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data is stored exclusively on your device.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Slip Vault: Payment Receipts'),
                    subtitle: Text('Version 1.0.0 (Core Flavor)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
