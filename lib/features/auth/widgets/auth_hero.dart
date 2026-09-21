import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beels_mobile/core/theme.dart';
import 'package:beels_mobile/core/widgets/adire_pattern.dart';

/// Dye banner with the adire motif, wordmark and a one-line promise. Used at
/// the top of every signed-out screen so the brand is consistent.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: compact ? 132 : 196,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
            const Positioned.fill(child: AdirePattern()),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: BeelsColors.turmeric,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'beels',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: compact ? 34 : 44,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                      color: Colors.white,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Save together. Know where you stand.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.75),
                      ),
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
}
