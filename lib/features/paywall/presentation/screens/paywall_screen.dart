import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/settings/presentation/providers/settings_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPro = ref.watch(proStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slip Vault Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pro Header Pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'LIFETIME ACCESS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Invest Once. Own Your Vault Forever.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No subscriptions. No cloud fees. Direct Google Play lifetime unlock.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
              ),
            ),
            const SizedBox(height: 24),

            // Benefits List
            _ProBenefitTile(
              icon: Icons.picture_as_pdf,
              title: 'Ad-Free Instant Exports',
              subtitle: 'Export unlimited monthly PDF statements and CSV files without watching ads.',
            ),
            const SizedBox(height: 12),
            _ProBenefitTile(
              icon: Icons.hide_image_outlined,
              title: 'Clean Unbranded Share Cards',
              subtitle: 'Remove the "Saved with Slip Vault" watermark when sending cards to clients.',
            ),
            const SizedBox(height: 12),
            _ProBenefitTile(
              icon: Icons.fingerprint,
              title: 'Biometric App Lock',
              subtitle: 'Lock down your financial records with fingerprint or face recognition.',
            ),
            const SizedBox(height: 12),
            _ProBenefitTile(
              icon: Icons.archive_outlined,
              title: 'Automated Local Zip Backups',
              subtitle: 'Export full zip archives of your database and images to private storage.',
            ),
            const SizedBox(height: 24),

            // Pricing Card
            Card(
              color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('One-Time Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(r'PKR 1,490 (~$4.99)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ref.read(proStatusProvider.notifier).setPro(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Slip Vault Pro Activated!')),
                        );
                        context.pop();
                      },
                      child: Text(
                        isPro ? 'Pro Already Active' : 'Unlock Pro Lifetime',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.read(proStatusProvider.notifier).setPro(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Purchases Restored Successfully!')),
                        );
                      },
                      child: const Text('Restore Purchases'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProBenefitTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primaryContainer, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
