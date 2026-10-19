import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.receipt_long,
      'title': 'Auto-Organize Payment Slips',
      'subtitle': 'Screenshot confirmations from JazzCash, Easypaisa, SadaPay, or any bank. Slip Vault automatically reads amounts, dates, and names.',
    },
    {
      'icon': Icons.lock_outline,
      'title': '100% Offline & Private',
      'subtitle': 'Everything stays strictly on your phone. No logins, no cloud uploads, and zero storage permissions requested.',
    },
    {
      'icon': Icons.picture_as_pdf_outlined,
      'title': 'Export Reports in 1 Tap',
      'subtitle': 'Generate monthly PDF statements with totals, export clean CSV spreadsheets, and share receipt confirmation cards to WhatsApp.',
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page['icon'] as IconData, size: 64, color: AppColors.primaryContainer),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == i ? AppColors.primaryContainer : Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (_currentIndex < _pages.length - 1) {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else {
                    context.go('/');
                  }
                },
                child: Text(
                  _currentIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
