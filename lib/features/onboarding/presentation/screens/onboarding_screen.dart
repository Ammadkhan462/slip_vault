import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/onboarding/data/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Animation controller for Slide 2 laser scanner
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await OnboardingService.markCompleted();
    if (mounted) {
      context.go('/');
    }
  }

  void _nextPage() {
    if (_currentIndex < 2) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8F9FF);
    final cardBg = isDark ? const Color(0xFF131C31) : const Color(0xFFEFF4FF);
    final voucherBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0B1C30);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final primaryTeal = const Color(0xFF0F766E);
    final primaryDarkTeal = const Color(0xFF005C55);
    final emeraldGreen = const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryDarkTeal,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primaryDarkTeal.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Slip Vault',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // Page Content Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                children: [
                  _buildSlide1(isDark, cardBg, voucherBg, textPrimary, textSecondary, primaryTeal, emeraldGreen),
                  _buildSlide2(isDark, cardBg, voucherBg, textPrimary, textSecondary, primaryTeal, emeraldGreen),
                  _buildSlide3(isDark, cardBg, voucherBg, textPrimary, textSecondary, primaryTeal, emeraldGreen),
                ],
              ),
            ),

            // Bottom Navigation & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3-Dot Slider Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (idx) {
                      final isActive = idx == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive ? primaryTeal : (isDark ? const Color(0xFF334155) : const Color(0xFFD3E4FE)),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Main CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDarkTeal,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentIndex == 2 ? 'Enter Slip Vault' : 'Continue',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // Secondary Action
                  if (_currentIndex < 2) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        'Skip introduction',
                        style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: textSecondary.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          '100% On-Device & Private',
                          style: TextStyle(fontSize: 11, color: textSecondary.withOpacity(0.8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to settings or trigger restore
                        _finishOnboarding();
                      },
                      icon: const Icon(Icons.settings_backup_restore, size: 16),
                      label: const Text('Restore Vault Backup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(foregroundColor: textSecondary),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'No account required • Your financial data never leaves your device',
                          style: TextStyle(fontSize: 10, color: textSecondary.withOpacity(0.9), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 1: 1-Tap Auto-Sync & Instant Slip Detection
  // -------------------------------------------------------------
  Widget _buildSlide1(
    bool isDark,
    Color cardBg,
    Color voucherBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryTeal,
    Color emeraldGreen,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          // Visual Showcase Stage
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                // Pill Badge: Lightning Import
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: voucherBg,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          '1-Tap Auto-Sync & Multi-Folder Scan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Layered Card Assembly (Depth Illusion)
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Backdrop sheet 1
                    Transform.rotate(
                      angle: -0.03,
                      child: Container(
                        width: 270,
                        height: 180,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFDCE9FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    // Backdrop sheet 2
                    Transform.rotate(
                      angle: 0.02,
                      child: Container(
                        width: 280,
                        height: 185,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.8) : const Color(0xFFD3E4FE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // Foreground Primary Voucher Card
                    Container(
                      width: 290,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: voucherBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: primaryTeal.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.verified, size: 16, color: primaryTeal),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Verified',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      const Text(
                                        'TXN-89410294',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  'PKR',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryTeal),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Transferred Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Transferred', style: TextStyle(fontSize: 11, color: textSecondary)),
                                Text(
                                  'Rs 14,850',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTeal,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Channel Details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('From', style: TextStyle(fontSize: 11, color: textSecondary)),
                              Text('SadaPay Personal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('To (Raast ID)', style: TextStyle(fontSize: 11, color: textSecondary)),
                              const Text('0300 •••• 921', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Detection Tag
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9CF2E8).withOpacity(isDark ? 0.2 : 0.6),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: primaryTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Auto-Detected: SadaPay',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF80D5CB) : primaryTeal),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: emeraldGreen, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text('100% Parsed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: emeraldGreen)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Floating WhatsApp badge on bottom-right corner
                    Positioned(
                      bottom: -8,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 13, color: emeraldGreen),
                            const SizedBox(width: 4),
                            Text(
                              'From WhatsApp',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Channel Support Chips Showcase
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE5EEFF)).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder_open, size: 14, color: primaryTeal),
                          const SizedBox(width: 5),
                          Text('Scan 3 Directories', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                        ],
                      ),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: emeraldGreen, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Auto-Sync Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: emeraldGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildDirBadge(Icons.image, '/Screenshots', isDark, voucherBg, textPrimary),
                    _buildDirBadge(Icons.chat, 'WhatsApp', isDark, voucherBg, textPrimary),
                    _buildDirBadge(Icons.account_balance, 'Banking Apps', isDark, voucherBg, textPrimary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Narrative Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner, size: 13, color: primaryTeal),
                const SizedBox(width: 4),
                Text(
                  'STEP 1 OF 3',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryTeal, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1-Tap Auto-Sync & Instant Slip Detection',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically scans your Screenshots, WhatsApp receipts, and banking folders with Android 15 permission support. Slip Vault instantly detects and indexes every voucher offline.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 2: Instant Neural OCR & Zero Duplicates
  // -------------------------------------------------------------
  Widget _buildSlide2(
    bool isDark,
    Color cardBg,
    Color voucherBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryTeal,
    Color emeraldGreen,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          // Visual Stage Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                // Top Pill
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: voucherBg,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          'OFFLINE NEURAL OCR ENGINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Main Card Container with Scanning Laser Animation
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: voucherBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Meezan Bank • Raast
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: primaryTeal.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.account_balance, size: 18, color: primaryTeal),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Meezan Bank • Raast',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      const Text(
                                        'INSTANT CLEARING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: emeraldGreen, shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Text('99.8%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emeraldGreen)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Inset Tier Box
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('PARSED AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textSecondary)),
                                    Text('PKR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryTeal)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '18,500',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text('.00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary)),
                                  ],
                                ),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Transaction ID', style: TextStyle(fontSize: 9, color: textSecondary)),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'TID-89201948',
                                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(Icons.verified, size: 11, color: primaryTeal),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Timestamp', style: TextStyle(fontSize: 9, color: textSecondary)),
                                        const SizedBox(height: 2),
                                        Text('Today, 14:32 PKT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textPrimary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Duplicate Protection Shield Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: primaryTeal.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: primaryTeal,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.shield, size: 14, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('Verified Unique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                                            const SizedBox(width: 4),
                                            Text('• Guard Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryTeal)),
                                          ],
                                        ),
                                        const Text(
                                          'SHA-256 HASH MATCH: 0 DUPLICATES',
                                          style: TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Icon(Icons.check_circle, size: 16, color: emeraldGreen),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Thumbnail Grid
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: emeraldGreen.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(Icons.crop, size: 14, color: emeraldGreen),
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Receipt Crop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
                                          Text('Zero Distortion', style: TextStyle(fontSize: 8, color: emeraldGreen, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: primaryTeal.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(Icons.receipt, size: 14, color: primaryTeal),
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Paper Slip', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
                                          Text('Auto-Perspective', style: TextStyle(fontSize: 8, color: textSecondary, fontWeight: FontWeight.w600)),
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
                    ),

                    // Laser Scanner Animated Overlay
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value * 220,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  primaryTeal,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryTeal.withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Narrative Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_outlined, size: 13, color: primaryTeal),
                const SizedBox(width: 4),
                Text(
                  'STEP 2 OF 3',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryTeal, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Instant Neural OCR & Zero Duplicates',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Amounts, transaction reference IDs, and dates are extracted instantly on-device. Identical receipts are flagged so you never pay or claim twice.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),

          // Interactive prompt pill
          InkWell(
            onTap: () {
              _laserController.forward(from: 0.0);
            },
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.autorenew, size: 14, color: primaryTeal),
                  const SizedBox(width: 6),
                  Text(
                    'Tap to Simulate OCR Extraction',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 3: Your Encrypted Ledger & WhatsApp Cards
  // -------------------------------------------------------------
  Widget _buildSlide3(
    bool isDark,
    Color cardBg,
    Color voucherBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryTeal,
    Color emeraldGreen,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          // Visual Stage Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                // Minimal Context Pill Tag
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: voucherBg,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: primaryTeal, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'STEP 3 OF 3 • LEDGER READY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // WhatsApp Share Card Mockup
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: voucherBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: emeraldGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.send, size: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'WHATSAPP VOUCHER',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: emeraldGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Payload
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('M. Hamza Tariq', style: TextStyle(fontSize: 11, color: textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                'PKR 18,500',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: emeraldGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: emeraldGreen),
                                    const SizedBox(width: 3),
                                    Text('Settled', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emeraldGreen)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('ID: RAAST-881920', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // WhatsApp Quick Share Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.chat, size: 14, color: primaryTeal),
                                const SizedBox(width: 6),
                                Text('Instant WhatsApp Proof', style: TextStyle(fontSize: 11, color: textSecondary)),
                              ],
                            ),
                            Text('READY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primaryTeal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lower Overlapping Ledger Strip
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5EEFF),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Inflow', style: TextStyle(fontSize: 10, color: textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '+Rs 104,300',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryTeal,
                              ),
                            ),
                          ],
                        ),

                        // Sparkline Curve
                        SizedBox(
                          width: 80,
                          height: 24,
                          child: CustomPaint(
                            painter: _SparklinePainter(color: primaryTeal),
                          ),
                        ),

                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.lock, size: 16, color: primaryTeal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Floating Micro Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMicroBadge(Icons.shield, 'AES-256 Encrypted', isDark, voucherBg, textPrimary),
                    const SizedBox(width: 8),
                    _buildMicroBadge(Icons.share, '1-Tap WhatsApp Share', isDark, voucherBg, textPrimary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Narrative Text
          Text(
            'Your Encrypted Ledger & WhatsApp Cards',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate polished proof receipts to share on WhatsApp, and review your monthly cash flow with hardware-backed encryption.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildDirBadge(IconData icon, String label, bool isDark, Color bg, Color textPrimary) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF0F766E)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }

  Widget _buildMicroBadge(IconData icon, String label, bool isDark, Color bg, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF0F766E)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2, size.height * 0.8)
      ..lineTo(size.width * 0.22, size.height * 0.6)
      ..lineTo(size.width * 0.40, size.height * 0.82)
      ..lineTo(size.width * 0.58, size.height * 0.4)
      ..lineTo(size.width * 0.78, size.height * 0.55)
      ..lineTo(size.width * 0.95, size.height * 0.15);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.15), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
