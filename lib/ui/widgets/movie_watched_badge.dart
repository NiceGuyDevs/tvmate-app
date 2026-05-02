import 'package:flutter/material.dart';

/// Stamp on movie details backdrop / hero art when marked watched.
class MovieWatchedBackdropStamp extends StatelessWidget {
  const MovieWatchedBackdropStamp({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Text(
            'WATCHED',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small corner mark on browse posters.
class MovieWatchedCornerBadge extends StatelessWidget {
  const MovieWatchedCornerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(
        'WATCHED',
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Stamp when title is marked "watching" (same family as [MovieWatchedBackdropStamp]).
class MovieWatchingBackdropStamp extends StatelessWidget {
  const MovieWatchingBackdropStamp({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00838F).withOpacity(0.78),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.38)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Text(
            'WATCHING',
            style: TextStyle(
              color: Colors.white.withOpacity(0.98),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class MovieContinueWatchingBackdropStamp extends StatelessWidget {
  const MovieContinueWatchingBackdropStamp({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withOpacity(0.78),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Text(
            'CONTINUE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.98),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}

class MovieWatchingCornerBadge extends StatelessWidget {
  const MovieWatchingCornerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00838F).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.32)),
      ),
      child: Text(
        'WATCH',
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w800,
          fontSize: 8.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class MovieContinueWatchingCornerBadge extends StatelessWidget {
  const MovieContinueWatchingCornerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Text(
        'CONTINUE',
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w800,
          fontSize: 8,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
