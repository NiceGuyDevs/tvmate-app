import '../../data/library_controller.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../l10n/app_localizations.dart';
import '../live_tv/mock_live_tv_data.dart';
import '../movies/mock_movies_data.dart';
import '../series/mock_series_data.dart';

/// Human-readable playlist label for lock rules (e.g. backup from another playlist).
String parentalPlaylistLabel(String playlistId, AppLocalizations l10n) {
  if (playlistId == ParentalControlStore.kDemoPlaylistId) {
    return l10n.settingsDemoMode;
  }
  for (final p in libraryController.playlists) {
    if (p.id == playlistId) return p.name;
  }
  return playlistId;
}

String? _liveChannelTitle(String playlistKey, String channelId) {
  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final c in kMockLiveChannels) {
      if (c.id == channelId) return c.name;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    for (final c in xtreamCatalogRepository.liveChannelsAll) {
      if (c.id == channelId) return c.name;
    }
  }
  return null;
}

String? _liveCategoryTitle(String playlistKey, String categoryId) {
  if (categoryId == kLiveTvFavoritesCategoryId) {
    return kLiveTvMyFavoritesCategory.name;
  }
  final fav = LiveFavoriteGroupsStore.instance.groupById(categoryId);
  if (fav != null) return fav.name;

  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final c in kMockLiveCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    if (categoryId == kLiveTvAllCategoryId) return 'All';
    for (final c in xtreamCatalogRepository.liveCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  return null;
}

String? _vodCategoryTitle(String playlistKey, String categoryId) {
  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final c in kMockMovieCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    for (final c in xtreamCatalogRepository.vodCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  return null;
}

String? _movieTitle(String playlistKey, String movieId) {
  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final m in kMockMovies) {
      if (m.id == movieId) return m.title;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    for (final m in xtreamCatalogRepository.vodMoviesAll) {
      if (m.id == movieId) return m.title;
    }
  }
  return null;
}

String? _seriesCategoryTitle(String playlistKey, String categoryId) {
  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final c in kMockSeriesCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    for (final c in xtreamCatalogRepository.seriesCategories) {
      if (c.id == categoryId) return c.name;
    }
  }
  return null;
}

String? _seriesTitle(String playlistKey, String seriesId) {
  if (libraryController.useDemoData && playlistKey == ParentalControlStore.kDemoPlaylistId) {
    for (final s in kMockSeries) {
      if (s.id == seriesId) return s.title;
    }
  }
  final active = libraryController.activePlaylistId;
  if (active != null && playlistKey == active) {
    for (final s in xtreamCatalogRepository.seriesAll) {
      if (s.id == seriesId) return s.title;
    }
  }
  return null;
}

/// Primary line: resolved title; secondary: type · playlist · id (when useful).
String formatLiveChannelRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String channelId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _liveChannelTitle(playlistId, channelId);
  if (title != null) {
    return '${l10n.parentalRulesChannel}: $title · $pl';
  }
  return '${l10n.parentalRulesChannel} · $pl · $channelId';
}

String formatLiveCategoryRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String categoryId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _liveCategoryTitle(playlistId, categoryId);
  if (title != null) {
    return '${l10n.parentalRulesCategory}: $title · $pl';
  }
  return '${l10n.parentalRulesCategory} · $pl · $categoryId';
}

String formatFavoriteGroupRuleLabel(
  AppLocalizations l10n,
  String groupId,
) {
  final name = LiveFavoriteGroupsStore.instance.groupById(groupId)?.name;
  if (name != null && name.isNotEmpty) {
    return '${l10n.parentalRulesFavoriteGroup}: $name';
  }
  return '${l10n.parentalRulesFavoriteGroup} · $groupId';
}

String formatVodCategoryRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String categoryId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _vodCategoryTitle(playlistId, categoryId);
  if (title != null) {
    return '${l10n.parentalRulesCategory}: $title · $pl';
  }
  return '${l10n.parentalRulesCategory} · $pl · $categoryId';
}

String formatMovieRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String movieId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _movieTitle(playlistId, movieId);
  if (title != null) {
    return '${l10n.parentalRulesMovie}: $title · $pl';
  }
  return '${l10n.parentalRulesMovie} · $pl · $movieId';
}

String formatSeriesCategoryRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String categoryId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _seriesCategoryTitle(playlistId, categoryId);
  if (title != null) {
    return '${l10n.parentalRulesCategory}: $title · $pl';
  }
  return '${l10n.parentalRulesCategory} · $pl · $categoryId';
}

String formatSeriesRuleLabel(
  AppLocalizations l10n,
  String playlistId,
  String seriesId,
) {
  final pl = parentalPlaylistLabel(playlistId, l10n);
  final title = _seriesTitle(playlistId, seriesId);
  if (title != null) {
    return '${l10n.parentalRulesSeries}: $title · $pl';
  }
  return '${l10n.parentalRulesSeries} · $pl · $seriesId';
}
