import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/money.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/adire_pattern.dart';

/// The finish line: an animated check, what was made, and the next action.
class BeelCreatedView extends StatefulWidget {
  const BeelCreatedView({
    super.key,
    required this.name,
    required this.target,
    required this.schedule,
    this.link,
    this.onShare,
    required this.onView,
    required this.onAnother,
  });

  final String name;
  final num target;
  final String schedule;

  /// Present for open-link beels.
  final String? link;
  final VoidCallback? onShare;
  final VoidCallback onView;
  final VoidCallback onAnother;

  @override
  State<BeelCreatedView> createState() => _BeelCreatedViewState();
}

class _BeelCreatedViewState extends State<BeelCreatedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) _c.value = 1;
    final isOpen = widget.link != null;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
        const Positioned.fill(
          child: Opacity(opacity: 0.35, child: AdirePattern(cell: 36)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _c,
                      curve: Curves.easeOutBack,
                    ),
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: BeelsColors.turmeric,
                        borderRadius: BorderRadius.circular(34),
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 60, color: BeelsColors.dye),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Your beel is live',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatNaira(widget.target)} · ${widget.schedule}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                if (isOpen) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Share your link so people can join and pay.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                if (isOpen) ...[
                  FilledButton.icon(
                    onPressed: widget.onShare,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BeelsColors.dye,
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    label: const Text('Share link'),
                  ),
                  const SizedBox(height: 10),
                ],
                isOpen
                    ? OutlinedButton(
                        onPressed: widget.onView,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: const Text('View beel'),
                      )
                    : FilledButton(
                        onPressed: widget.onView,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: BeelsColors.dye,
                        ),
                        child: const Text('View my beels'),
                      ),
                TextButton(
                  onPressed: widget.onAnother,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.8),
                  ),
                  child: const Text('Create another'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
