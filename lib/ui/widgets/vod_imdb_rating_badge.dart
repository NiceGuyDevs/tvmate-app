import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Gold star + white score with a **soft** translucent black scrim (blurred), not a hard chip.
///
/// Used on browse posters (top-right), hero backdrops, and detail metadata rows.
class VodImdbRatingBadge extends StatelessWidget {
  const VodImdbRatingBadge({
    super.key,
    required this.rating,
    this.size = VodImdbRatingBadgeSize.poster,
  });

  final String rating;
  final VodImdbRatingBadgeSize size;

  static const Color _kStarGold = Color(0xFFEECB26);

  @override
  Widget build(BuildContext context) {
    final trimmed = rating.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final gap = switch (size) {
      VodImdbRatingBadgeSize.poster => 4.0,
      VodImdbRatingBadgeSize.heroMeta => 4.5,
      VodImdbRatingBadgeSize.detail => 10.0,
    };
    final padH = switch (size) {
      VodImdbRatingBadgeSize.poster => 6.0,
      VodImdbRatingBadgeSize.heroMeta => 7.0,
      VodImdbRatingBadgeSize.detail => 14.0,
    };
    final padV = switch (size) {
      VodImdbRatingBadgeSize.poster => 5.0,
      VodImdbRatingBadgeSize.heroMeta => 6.0,
      VodImdbRatingBadgeSize.detail => 12.0,
    };
    final valueFs = switch (size) {
      VodImdbRatingBadgeSize.poster => 12.0,
      VodImdbRatingBadgeSize.heroMeta => 14.5,
      VodImdbRatingBadgeSize.detail => 28.0,
    };
    final starSize = switch (size) {
      VodImdbRatingBadgeSize.poster => 14.5,
      VodImdbRatingBadgeSize.heroMeta => 17.0,
      VodImdbRatingBadgeSize.detail => 34.0,
    };
    final blurSigma = switch (size) {
      VodImdbRatingBadgeSize.poster => 15.0,
      VodImdbRatingBadgeSize.heroMeta => 15.0,
      VodImdbRatingBadgeSize.detail => 42.0,
    };
    final scrimOpacity = switch (size) {
      VodImdbRatingBadgeSize.poster => 0.46,
      VodImdbRatingBadgeSize.heroMeta => 0.39,
      VodImdbRatingBadgeSize.detail => 0.66,
    };
    final outerPad = switch (size) {
      VodImdbRatingBadgeSize.poster => 11.0,
      VodImdbRatingBadgeSize.heroMeta => 11.0,
      VodImdbRatingBadgeSize.detail => 33.0,
    };
    final corner = switch (size) {
      VodImdbRatingBadgeSize.poster => 22.0,
      VodImdbRatingBadgeSize.heroMeta => 22.0,
      VodImdbRatingBadgeSize.detail => 48.0,
    };

    return Semantics(
      label: 'IMDb rating $trimmed',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -outerPad,
              top: -outerPad * 0.75,
              right: -outerPad,
              bottom: -outerPad * 0.75,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(corner),
                    color: Colors.black.withValues(alpha: scrimOpacity),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: starSize,
                  color: _kStarGold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: size == VodImdbRatingBadgeSize.detail ? 5 : 3,
                    ),
                  ],
                ),
                SizedBox(width: gap),
                Text(
                  trimmed,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: valueFs,
                    height: 1.0,
                    letterSpacing: 0.15,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius:
                            size == VodImdbRatingBadgeSize.detail ? 7 : 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum VodImdbRatingBadgeSize { poster, heroMeta, detail }
