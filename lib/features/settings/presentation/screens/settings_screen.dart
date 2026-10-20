import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/core/widgets/vault_bottom_bar.dart';
import 'package:slip_vault/features/settings/data/auth_service.dart';
import 'package:slip_vault/features/settings/data/backup_service.dart';
import 'package:slip_vault/features/settings/presentation/providers/settings_provider.dart';
import 'package:slip_vault/features/tour/data/vault_tour_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPro = ref.watch(proStatusProvider);
    final isAppLock = ref.watch(appLockProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (isPro)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withAlpha(30),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'LIFETIME VAULT',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Local Vault Integrity Hero Card
            StreamBuilder<List<dynamic>>(
              stream: db.select(db.entries).watch(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withAlpha(40),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.verified_user_outlined, size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Local Vault Integrity',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.circle, size: 7, color: Color(0xFF6EE7B7)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Encrypted SQLite FTS5 Safe',
                                        style: TextStyle(
                                          color: Color(0xFFCCFBF1),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: Colors.white.withAlpha(40)),
                            ),
                            child: const Text(
                              'SANDBOXED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'VAULT FOOTPRINT',
                                    style: TextStyle(fontSize: 9, color: Color(0xFFCCFBF1), fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$count Slips Cached',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(25)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CLOUD TELEMETRY',
                                    style: TextStyle(fontSize: 9, color: Color(0xFFCCFBF1), fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Color(0xFF6EE7B7)),
                                      SizedBox(width: 4),
                                      Text(
                                        '0.00 KB (Offline)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Security Section
            Text('SECURITY & BIOMETRICS', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fingerprint, color: AppColors.primaryContainer, size: 22),
                    ),
                    title: const Text('Biometric / Face ID / PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Require hardware authentication upon opening app', style: TextStyle(fontSize: 12)),
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
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                    ),
                    title: const Text('Zero Telemetry Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Strict sandbox blocking all internet access', style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ENFORCED',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Display & Localization
            Text('DISPLAY & LANGUAGE', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.translate, color: AppColors.primaryContainer, size: 22),
                    ),
                    title: const Text('Language / زبان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(currentLocale.languageCode == 'ur' ? 'اردو (Urdu RTL)' : 'English', style: const TextStyle(fontSize: 12)),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'ur', label: Text('اردو', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {currentLocale.languageCode},
                      onSelectionChanged: (val) {
                        ref.read(localeProvider.notifier).setLocale(Locale(val.first));
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_outlined, color: AppColors.primaryContainer, size: 22),
                    ),
                    title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(currentThemeMode.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 20),

            // Offline Backup & Archive
            Text('OFFLINE BACKUP & ARCHIVE', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.archive_outlined, color: AppColors.primaryContainer, size: 22),
                ),
                title: const Text('Export Local Backup (ZIP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Archive SQLite database and images into zip file', style: TextStyle(fontSize: 12)),
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
            ),
            const SizedBox(height: 20),

            // About & Legal
            Text('ABOUT & INTEGRITY', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.school_outlined, size: 22, color: AppColors.primaryContainer),
                    title: const Text('App Onboarding Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Review feature walkthrough & slip detection guides', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => context.push('/onboarding'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tips_and_updates_outlined, size: 22, color: AppColors.primaryContainer),
                    title: const Text('Interactive Vault Guidance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Replay interactive bubble guidance for Auto-Sync & Cash Flow', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      await VaultTourService.reset();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, size: 22),
                    title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('100% offline, zero cloud servers, zero telemetry', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.open_in_new, size: 14),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data is stored exclusively on your device.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline, size: 22),
                    title: Text('Slip Vault: Payment Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Version 1.0.0 • SQLite FTS5 Engine', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const VaultBottomBar(currentIndex: 3),
    );
  }
}
