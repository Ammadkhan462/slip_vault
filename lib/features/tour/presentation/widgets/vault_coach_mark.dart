import 'package:flutter/material.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/tour/data/vault_tour_service.dart';

/// Represents a spotlight guide target on the screen
class TourTarget {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData icon;
  final double radius;
  final EdgeInsets targetPadding;

  const TourTarget({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.radius = 12.0,
    this.targetPadding = const EdgeInsets.all(6.0),
  });
}

/// Static manager to trigger and dismiss interactive coach marks
class VaultCoachMark {
  static OverlayEntry? _overlayEntry;

  /// Display the coach mark tour
  static void show({
    required BuildContext context,
    required List<TourTarget> targets,
    VoidCallback? onCompleted,
  }) {
    dismiss();

    if (targets.isEmpty) return;

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => _VaultCoachMarkOverlay(
        targets: targets,
        onDismiss: () {
          dismiss();
          VaultTourService.markCompleted();
          onCompleted?.call();
        },
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  /// Close any active coach mark tour
  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _VaultCoachMarkOverlay extends StatefulWidget {
  final List<TourTarget> targets;
  final VoidCallback onDismiss;

  const _VaultCoachMarkOverlay({
    required this.targets,
    required this.onDismiss,
  });

  @override
  State<_VaultCoachMarkOverlay> createState() => _VaultCoachMarkOverlayState();
}

class _VaultCoachMarkOverlayState extends State<_VaultCoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.targets.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onDismiss();
    }
  }

  Rect? _calculateTargetRect(TourTarget target) {
    final renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(
      offset.dx - target.targetPadding.left,
      offset.dy - target.targetPadding.top,
      size.width + target.targetPadding.horizontal,
      size.height + target.targetPadding.vertical,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTarget = widget.targets[_currentIndex];
    final targetRect = _calculateTargetRect(currentTarget);
    final screenSize = MediaQuery.of(context).size;

    // Fallback if target is offscreen or not yet measured
    final safeRect = targetRect ??
        Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height * 0.3),
          width: screenSize.width * 0.8,
          height: 120,
        );

    final isUpperHalf = safeRect.center.dy < screenSize.height * 0.5;

    return Stack(
      children: [
        // 1. Dimmed scrim with rounded spotlight cutout
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss, // Tap outside skips tour
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: safeRect,
                  radius: currentTarget.radius,
                  overlayColor: Colors.black.withOpacity(0.78),
                  pulseValue: _pulseAnimation.value,
                ),
              );
            },
          ),
        ),

        // 2. Interactive Speech Bubble Card
        Positioned(
          top: isUpperHalf
              ? (safeRect.bottom + 14).clamp(16.0, screenSize.height - 270.0)
              : null,
          bottom: !isUpperHalf
              ? (screenSize.height - safeRect.top + 14).clamp(16.0, screenSize.height - 270.0)
              : null,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _buildBubbleCard(
              context: context,
              target: currentTarget,
              pointerCenterX: safeRect.center.dx,
              isUpperHalf: isUpperHalf,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleCard({
    required BuildContext context,
    required TourTarget target,
    required double pointerCenterX,
    required bool isUpperHalf,
  }) {
    const primaryTeal = Color(0xFF0F766E);
    const brightTeal = Color(0xFF14B8A6);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Modern Slate-900
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: primaryTeal.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Step Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryTeal.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: brightTeal.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tips_and_updates, size: 12, color: brightTeal),
                      const SizedBox(width: 4),
                      Text(
                        'STEP ${_currentIndex + 1} OF ${widget.targets.length}',
                        style: const TextStyle(
                          color: brightTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Skip (X) button
                IconButton(
                  tooltip: 'Skip guide',
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
          ),

          // Title & Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(target.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        target.description,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Actions Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Step Progress Indicators
                Row(
                  children: List.generate(widget.targets.length, (idx) {
                    final isActive = idx == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 5),
                      width: isActive ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? brightTeal : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    );
                  }),
                ),

                // Navigation Buttons
                Row(
                  children: [
                    TextButton(
                      onPressed: widget.onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Skip Tour', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentIndex < widget.targets.length - 1 ? 'Next' : 'Got it!',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _currentIndex < widget.targets.length - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double radius;
  final Color overlayColor;
  final double pulseValue;

  _SpotlightPainter({
    required this.targetRect,
    required this.radius,
    required this.overlayColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final rrect = RRect.fromRectAndRadius(targetRect, Radius.circular(radius));
    final holePath = Path()..addRRect(rrect);

    // Subtract hole from background
    final combined = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(combined, Paint()..color = overlayColor);

    // Pulsing glowing ring border around target
    final strokePaint = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.4 + 0.45 * pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + 1.2 * pulseValue;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect ||
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.radius != radius;
}
