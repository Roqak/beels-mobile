import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'adire_pattern.dart';

/// Compact indigo banner that opens a form flow: a title and one line of
/// context, with the adire motif. Keeps setup screens on the brand.
class IntroBanner extends StatelessWidget {
  const IntroBanner({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
          const Positioned.fill(child: AdirePattern(cell: 26)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: BeelsColors.turmeric,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
