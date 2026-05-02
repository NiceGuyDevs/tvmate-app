import 'package:flutter/material.dart';

import '../../data/live_favorite_groups_store.dart';
import '../../data/parental_control_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/live_tv/mock_live_tv_data.dart';
import '../new_settings/new_settings_palette.dart';
import '../new_settings/widgets/ns_focusable.dart';
import '../new_settings/widgets/ns_parental_scope_modals.dart';
import 'parental_pin_dialog.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Live TV: PIN first, then lock or unlock channel / category for this view.
///
/// When [skipPinVerify] is true (e.g. user just verified or created a PIN in the
/// player overlay), the PIN dialog is skipped once.
Future<void> showLiveParentalScopeDialog(
  BuildContext context, {
  required String playlistId,
  required String viewCategoryId,
  required String channelId,
  bool skipPinVerify = false,
}) async {
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return;
  if (!parentalControlStore.enabled || !parentalControlStore.isPinConfigured) {
    return;
  }
  if (!skipPinVerify) {
    final ok = await showParentalPinVerifyDialog(context);
    if (!ok || !context.mounted) return;
  }

  final l10n = AppLocalizations.of(context);
  final chLocked =
      parentalControlStore.isLiveChannelDirectlyLocked(playlistId, channelId);
  final chHide =
      parentalControlStore.isLiveChannelBrowseHidden(playlistId, channelId);
  final viewLocked = parentalControlStore.isLiveViewCategoryOrFavoriteLocked(
    playlistId,
    viewCategoryId,
  );
  final viewHide = parentalControlStore.isLiveViewCategoryBrowseHidden(
    playlistId,
    viewCategoryId,
  );
  final hasCategoryContext = viewCategoryId.trim().isNotEmpty;

  final canLockChannelOnly = !chLocked;
  final canLockChannelAndHide = !chHide;
  final canLockCategoryOnly = hasCategoryContext && !viewLocked;
  final canLockCategoryAndHide = hasCategoryContext && !viewHide;

  final showUnlockChannel = chLocked || chHide;
  final showUnlockCategory =
      hasCategoryContext && (viewLocked || viewHide);

  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return Theme(
        data: nsIslandThemeData(context),
        child: NsFocusAccentScope(
          overridePlatformGate: true,
          child: Dialog(
            alignment: Alignment.center,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: NsParentalScopeDialogCard(
              title: l10n.parentalScopeTitleLive,
              children: [
                NsParentalScopeActionRow(
                  autofocus: true,
                  label: l10n.parentalScopeLockChannelOnly,
                  isAvailable: canLockChannelOnly,
                  onPressed: () {
                    if (!canLockChannelOnly) {
                      _snack(ctx, l10n.parentalScopeChannelAlreadyBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('lock_ch');
                  },
                ),
                NsParentalScopeActionRow(
                  label: l10n.parentalScopeLockChannelAndHideBrowse,
                  isAvailable: canLockChannelAndHide,
                  onPressed: () {
                    if (!canLockChannelAndHide) {
                      _snack(ctx, l10n.parentalScopeChannelAlreadyBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('lock_ch_hide');
                  },
                ),
                NsParentalScopeActionRow(
                  label: l10n.parentalScopeLockCategoryOnly,
                  isAvailable: canLockCategoryOnly,
                  onPressed: () {
                    if (!canLockCategoryOnly) {
                      _snack(
                        ctx,
                        !hasCategoryContext
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeCategoryAlreadyBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('lock_cat');
                  },
                ),
                NsParentalScopeActionRow(
                  label: l10n.parentalScopeLockCategoryAndHideBrowse,
                  isAvailable: canLockCategoryAndHide,
                  onPressed: () {
                    if (!canLockCategoryAndHide) {
                      _snack(
                        ctx,
                        !hasCategoryContext
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeCategoryAlreadyBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('lock_cat_hide');
                  },
                ),
                if (showUnlockChannel)
                  NsParentalScopeActionRow(
                    danger: true,
                    label: l10n.parentalUnlockThisChannel,
                    isAvailable: true,
                    onPressed: () => Navigator.of(ctx).pop('unlock_ch'),
                  ),
                if (showUnlockCategory)
                  NsParentalScopeActionRow(
                    danger: true,
                    label: l10n.parentalUnlockCategoryOrGroup,
                    isAvailable: true,
                    onPressed: () => Navigator.of(ctx).pop('unlock_cat'),
                  ),
                NsParentalScopeCancelRow(
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'unlock_ch':
      await parentalControlStore.removeLockedLiveChannel(playlistId, channelId);
      await parentalControlStore.removeBrowseHideLiveChannel(
        playlistId,
        channelId,
      );
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'unlock_cat':
      final fav = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
      if (viewCategoryId == kLiveTvFavoritesCategoryId || fav != null) {
        await parentalControlStore.removeLockedFavoriteGroup(viewCategoryId);
        await parentalControlStore.removeBrowseHideFavoriteGroup(viewCategoryId);
      } else {
        await parentalControlStore.removeLockedLiveCategory(
          playlistId,
          viewCategoryId,
        );
        await parentalControlStore.removeBrowseHideLiveCategory(
          playlistId,
          viewCategoryId,
        );
      }
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'lock_ch':
      await parentalControlStore.addLockedLiveChannel(playlistId, channelId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    case 'lock_ch_hide':
      await parentalControlStore.addLockedLiveChannel(playlistId, channelId);
      await parentalControlStore.addBrowseHideLiveChannel(playlistId, channelId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    case 'lock_cat':
      final fav2 = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
      if (viewCategoryId == kLiveTvFavoritesCategoryId || fav2 != null) {
        await parentalControlStore.addLockedFavoriteGroup(viewCategoryId);
      } else {
        await parentalControlStore.addLockedLiveCategory(
          playlistId,
          viewCategoryId,
        );
      }
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    case 'lock_cat_hide':
      final fav3 = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
      if (viewCategoryId == kLiveTvFavoritesCategoryId || fav3 != null) {
        await parentalControlStore.addLockedFavoriteGroup(viewCategoryId);
        await parentalControlStore.addBrowseHideFavoriteGroup(viewCategoryId);
      } else {
        await parentalControlStore.addLockedLiveCategory(
          playlistId,
          viewCategoryId,
        );
        await parentalControlStore.addBrowseHideLiveCategory(
          playlistId,
          viewCategoryId,
        );
      }
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    default:
      break;
  }
}

/// Movies: lock or unlock this title / category.
Future<void> showMovieParentalScopeDialog(
  BuildContext context, {
  required String playlistId,
  required String movieId,
  required String categoryId,
}) async {
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return;
  if (!parentalControlStore.enabled || !parentalControlStore.isPinConfigured) {
    return;
  }
  final ok = await showParentalPinVerifyDialog(context);
  if (!ok || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final movieL =
      parentalControlStore.isMovieDirectlyLocked(playlistId, movieId);
  final catL =
      parentalControlStore.isVodCategoryLocked(playlistId, categoryId);
  final hasCat = categoryId.trim().isNotEmpty;

  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return Theme(
        data: nsIslandThemeData(context),
        child: NsFocusAccentScope(
          overridePlatformGate: true,
          child: Dialog(
            alignment: Alignment.center,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: NsParentalScopeDialogCard(
              title: l10n.parentalScopeTitleMovie,
              children: [
                NsParentalScopeActionRow(
                  autofocus: true,
                  label: l10n.parentalBlockThisMovie,
                  isAvailable: !movieL,
                  onPressed: () {
                    if (movieL) {
                      _snack(ctx, l10n.parentalScopeMovieAlreadyBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('lock_m');
                  },
                ),
                NsParentalScopeActionRow(
                  danger: true,
                  label: l10n.parentalUnlockThisMovie,
                  isAvailable: movieL,
                  onPressed: () {
                    if (!movieL) {
                      _snack(ctx, l10n.parentalScopeMovieNotBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('unlock_m');
                  },
                ),
                NsParentalScopeActionRow(
                  label: l10n.parentalBlockMovieCategory,
                  isAvailable: !catL && hasCat,
                  onPressed: () {
                    if (catL || !hasCat) {
                      _snack(
                        ctx,
                        !hasCat
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeMovieCategoryAlreadyBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('lock_c');
                  },
                ),
                NsParentalScopeActionRow(
                  danger: true,
                  label: l10n.parentalUnlockMovieCategory,
                  isAvailable: catL && hasCat,
                  onPressed: () {
                    if (!catL || !hasCat) {
                      _snack(
                        ctx,
                        !hasCat
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeMovieCategoryNotBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('unlock_c');
                  },
                ),
                NsParentalScopeCancelRow(
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'unlock_m':
      await parentalControlStore.removeLockedMovie(playlistId, movieId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'unlock_c':
      await parentalControlStore.removeLockedVodCategory(playlistId, categoryId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'lock_m':
      await parentalControlStore.addLockedMovie(playlistId, movieId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    case 'lock_c':
      await parentalControlStore.addLockedVodCategory(playlistId, categoryId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    default:
      break;
  }
}

/// Series: lock or unlock show / category.
Future<void> showSeriesParentalScopeDialog(
  BuildContext context, {
  required String playlistId,
  required String seriesId,
  required String categoryId,
}) async {
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return;
  if (!parentalControlStore.enabled || !parentalControlStore.isPinConfigured) {
    return;
  }
  final ok = await showParentalPinVerifyDialog(context);
  if (!ok || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final serL =
      parentalControlStore.isSeriesDirectlyLocked(playlistId, seriesId);
  final catL =
      parentalControlStore.isSeriesCategoryLocked(playlistId, categoryId);
  final hasCat = categoryId.trim().isNotEmpty;

  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return Theme(
        data: nsIslandThemeData(context),
        child: NsFocusAccentScope(
          overridePlatformGate: true,
          child: Dialog(
            alignment: Alignment.center,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: NsParentalScopeDialogCard(
              title: l10n.parentalScopeTitleSeries,
              children: [
                NsParentalScopeActionRow(
                  autofocus: true,
                  label: l10n.parentalBlockThisShow,
                  isAvailable: !serL,
                  onPressed: () {
                    if (serL) {
                      _snack(ctx, l10n.parentalScopeSeriesAlreadyBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('lock_s');
                  },
                ),
                NsParentalScopeActionRow(
                  danger: true,
                  label: l10n.parentalUnlockThisShow,
                  isAvailable: serL,
                  onPressed: () {
                    if (!serL) {
                      _snack(ctx, l10n.parentalScopeSeriesNotBlocked);
                      return;
                    }
                    Navigator.of(ctx).pop('unlock_s');
                  },
                ),
                NsParentalScopeActionRow(
                  label: l10n.parentalBlockSeriesCategory,
                  isAvailable: !catL && hasCat,
                  onPressed: () {
                    if (catL || !hasCat) {
                      _snack(
                        ctx,
                        !hasCat
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeSeriesCategoryAlreadyBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('lock_sc');
                  },
                ),
                NsParentalScopeActionRow(
                  danger: true,
                  label: l10n.parentalUnlockSeriesCategory,
                  isAvailable: catL && hasCat,
                  onPressed: () {
                    if (!catL || !hasCat) {
                      _snack(
                        ctx,
                        !hasCat
                            ? l10n.parentalScopeNoCategoryContext
                            : l10n.parentalScopeSeriesCategoryNotBlocked,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop('unlock_sc');
                  },
                ),
                NsParentalScopeCancelRow(
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'unlock_s':
      await parentalControlStore.removeLockedSeries(playlistId, seriesId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'unlock_sc':
      await parentalControlStore.removeLockedSeriesCategory(
        playlistId,
        categoryId,
      );
      if (!context.mounted) return;
      _snack(context, l10n.parentalUnlocked);
      break;
    case 'lock_s':
      await parentalControlStore.addLockedSeries(playlistId, seriesId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    case 'lock_sc':
      await parentalControlStore.addLockedSeriesCategory(playlistId, categoryId);
      if (!context.mounted) return;
      _snack(context, l10n.parentalLockSaved);
      break;
    default:
      break;
  }
}
