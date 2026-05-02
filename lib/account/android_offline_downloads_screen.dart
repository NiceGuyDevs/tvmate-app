import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/vod_offline_library.dart';
import '../l10n/app_localizations.dart';
import '../player/player_navigation.dart';
import '../player/vod_download_helpers.dart';
import '../ui/widgets/tv_media_urls.dart';

/// Matches [AccountOverlay] dashboard styling (_AccColors).
class _AccShell {
  static const Color bgPrimary = Color(0xFF0A0A0C);
  static const Color bgSecondary = Color(0xFF131316);
  static const Color bgTertiary = Color(0xFF1E1E24);
  static const Color borderColor = Color.fromARGB(153, 63, 63, 70);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);
  static const Color accentPrimary = Color(0xFF6366F1);
  static const Color danger = Color(0xFFEF4444);
}

/// Android-only: list of offline VOD files (Account → Offline downloads).
class AndroidOfflineDownloadsScreen extends StatefulWidget {
  const AndroidOfflineDownloadsScreen({super.key});

  @override
  State<AndroidOfflineDownloadsScreen> createState() =>
      _AndroidOfflineDownloadsScreenState();
}

class _AndroidOfflineDownloadsScreenState
    extends State<AndroidOfflineDownloadsScreen> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    await VodOfflineLibrary.instance.reload();
    await VodOfflineLibrary.instance.pruneMissingFiles();
  }

  Future<void> _confirmDelete(VodOfflineItem item) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _AccShell.accentPrimary,
            surface: _AccShell.bgTertiary,
          ),
        ),
        child: AlertDialog(
          backgroundColor: _AccShell.bgTertiary,
          title: Text(
            l10n.accountOfflineDownloadsDeleteTitle,
            style: const TextStyle(color: _AccShell.textPrimary),
          ),
          content: Text(
            l10n.accountOfflineDownloadsDeleteBody,
            style: const TextStyle(color: _AccShell.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.commonCancel,
                style: const TextStyle(color: _AccShell.textTertiary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.accountOfflineDownloadsDeleteConfirm,
                style: const TextStyle(color: _AccShell.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await VodOfflineLibrary.instance.remove(item.id);
    }
  }

  Future<void> _play(VodOfflineItem item) async {
    if (!File(item.filePath).existsSync()) {
      await _sync();
      return;
    }
    if (!mounted) return;
    await openTvMatePlayer(
      context,
      title: item.title,
      streamUrl: Uri.file(item.filePath).toString(),
      isLive: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt = DateFormat.yMMMd().add_Hm();

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _AccShell.bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: _AccShell.accentPrimary,
          surface: _AccShell.bgSecondary,
        ),
      ),
      child: Scaffold(
        backgroundColor: _AccShell.bgPrimary,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: _AccShell.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountOfflineDownloadsTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _AccShell.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.accountOfflineDownloadsSubtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _AccShell.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: VodOfflineLibrary.instance,
                  builder: (context, _) {
                    final items = VodOfflineLibrary.instance.items;
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.accountOfflineDownloadsEmpty,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _AccShell.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _AccShell.bgTertiary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _AccShell.borderColor),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 120,
                                    height: 68,
                                    child: _OfflineThumb(posterUrl: item.posterUrl),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _AccShell.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${vodDownloadFormatBytes(item.sizeBytes)} · ${dateFmt.format(item.savedAt)}',
                                        style: const TextStyle(
                                          color: _AccShell.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _play(item),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _AccShell.accentPrimary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.accountOfflineDownloadsPlay,
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () =>
                                                _confirmDelete(item),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _AccShell.danger,
                                              side: const BorderSide(
                                                color: _AccShell.danger,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.accountOfflineDownloadsDelete,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineThumb extends StatelessWidget {
  const _OfflineThumb({this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final u = posterUrl?.trim() ?? '';
    if (u.isEmpty || !catalogArtUrlLooksLoadable(u)) {
      return ColoredBox(
        color: _AccShell.bgSecondary,
        child: const Icon(
          Icons.movie_outlined,
          color: _AccShell.textTertiary,
          size: 36,
        ),
      );
    }
    if (catalogArtIsBundledAsset(u)) {
      return Image.asset(
        u,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: _AccShell.bgSecondary,
          child: Icon(
            Icons.movie_outlined,
            color: _AccShell.textTertiary,
            size: 36,
          ),
        ),
      );
    }
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: _AccShell.bgSecondary,
        child: Icon(
          Icons.movie_outlined,
          color: _AccShell.textTertiary,
          size: 36,
        ),
      ),
    );
  }
}
