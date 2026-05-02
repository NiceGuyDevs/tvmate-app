import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/vod_download_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../player/vod_download_helpers.dart';

/// App-wide floating strip: VOD download progress + cancel (Windows / Android).
class VodDownloadStripLayer extends StatelessWidget {
  const VodDownloadStripLayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isAndroid)) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: VodDownloadController.instance,
      builder: (context, _) {
        final c = VodDownloadController.instance;
        if (!c.isActive) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);

        final accent = Theme.of(context).colorScheme.primary;
        String phaseLabel;
        switch (c.phase) {
          case VodDownloadPhase.downloading:
            phaseLabel = l10n.playerVodDownloadDownloading;
          case VodDownloadPhase.copying:
            phaseLabel = Platform.isAndroid
                ? l10n.playerVodDownloadSavingOffline
                : l10n.playerVodDownloadSavingToDownloadsFolder;
          case VodDownloadPhase.idle:
            phaseLabel = '';
        }

        final frac = c.progressFraction;
        final received = vodDownloadFormatBytes(c.receivedBytes);
        final total = c.totalBytes;
        final progressText = total != null && total > 0
            ? '$received / ${vodDownloadFormatBytes(total)}'
            : received;

        return Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
              ignoring: true,
              child: SizedBox.expand(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    // [MaterialApp.builder] places this strip as a **sibling** of [Navigator],
                    // so there is no [Overlay] ancestor. Avoid [Material]/[IconButton]/[Tooltip]
                    // (they call [Overlay.of] for ink / tooltips).
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xEE121212),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, color: accent, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phaseLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (c.phase == VodDownloadPhase.downloading) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: frac,
                                        minHeight: 6,
                                        backgroundColor: Colors.white12,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      progressText,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ] else if (c.phase == VodDownloadPhase.copying) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: const LinearProgressIndicator(
                                        minHeight: 6,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (c.canCancelDownload) ...[
                              const SizedBox(width: 4),
                              Semantics(
                                label: l10n.playerVodDownloadCancel,
                                button: true,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () =>
                                        VodDownloadController.instance.cancel(),
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
