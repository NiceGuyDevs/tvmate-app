// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsTopMenuManager => 'Menu principal';

  @override
  String get settingsTopMenuManagerSubtitle =>
      'Réorganiser, ajouter, démarrage';

  @override
  String get settingsShellThemeSubtitle =>
      'Équipe visuelle et couleurs d’accent';

  @override
  String get settingsShellPlaylistSubtitle => 'Changer la liste active';

  @override
  String get settingsAddPlaylist => 'Ajouter une liste';

  @override
  String get settingsAddPlaylistSubtitle => 'Xtream ou M3U';

  @override
  String get settingsMyPlaylists => 'Mes listes';

  @override
  String settingsMyPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listes',
      one: '1 liste',
      zero: 'Aucune liste',
    );
    return '$_temp0';
  }

  @override
  String get settingsFavoriteSetup => 'Favoris';

  @override
  String get settingsFavoriteSetupSubtitle => 'Chaînes TV favorites';

  @override
  String get settingsClock => 'Horloge';

  @override
  String get settingsClockOn => 'Activé';

  @override
  String get settingsClockOff => 'Désactivé';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String settingsAppearanceSubtitle(int heroPercent, int columns) {
    return 'Héros $heroPercent% · $columns par ligne';
  }

  @override
  String get settingsRecordingEdit => 'Édition rattrapage';

  @override
  String get settingsRecordingEditSubtitle => 'Configuration rattrapage';

  @override
  String get catchupSelectPlaylistHelp =>
      'Sélectionnez une liste pour configurer les chaînes rattrapage';

  @override
  String get catchupNoXtreamPlaylists =>
      'Aucune liste Xtream trouvée.\nAjoutez d’abord une liste Xtream.';

  @override
  String get catchupBreadcrumbCategories => 'Rattrapage · Catégories';

  @override
  String catchupBreadcrumbWithCategory(String categoryName) {
    return 'Rattrapage · $categoryName';
  }

  @override
  String get catchupFilterQuickOn => 'Filtre rattrapage : activé';

  @override
  String get catchupFilterQuickOff => 'Filtre rattrapage : désactivé';

  @override
  String get catchupEmptyStateTitle =>
      'Configurez le rattrapage dans Paramètres';

  @override
  String catchupEmptyStateBody(String entryLabel) {
    return 'Allez dans Paramètres → $entryLabel pour approuver\ncatégories et chaînes.';
  }

  @override
  String get catchupXtreamOnly =>
      'Le rattrapage n’est disponible que pour les listes Xtream.';

  @override
  String get catchupManage => 'Gérer le rattrapage';

  @override
  String get catchupGroupOptions => 'Options rattrapage';

  @override
  String get catchupGroupCategories => 'Catégories';

  @override
  String get catchupSelectAll => 'Tout sélectionner';

  @override
  String get catchupClearAll => 'Tout effacer';

  @override
  String catchupFilterSub(String tabName) {
    return 'N’afficher que les chaînes dont la source indique le rattrapage. Cache le reste dans l’onglet $tabName pour cette liste.';
  }

  @override
  String get catchupClearConfirmTitle => 'Tout retirer des approbations ?';

  @override
  String catchupClearConfirmMessage(String playlistName) {
    return 'Supprime toutes les catégories et chaînes approuvées de la liste rattrapage de « $playlistName ». La liste elle-même n’est pas modifiée.';
  }

  @override
  String get catchupFilterBannerLead => 'Filtre rattrapage activé. ';

  @override
  String catchupFilterHiddenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaînes sans rattrapage sont masquées dans cette liste.',
      one: '1 chaîne sans rattrapage est masquée dans cette liste.',
    );
    return '$_temp0 Désactivez le filtre dans les options rattrapage pour les approuver.';
  }

  @override
  String get catchupNoChannelsInCategory =>
      'Aucune chaîne dans cette catégorie.';

  @override
  String get catchupNoLiveCategoriesSync =>
      'Aucune catégorie directe trouvée.\nSynchronisez d’abord cette liste.';

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get settingsBackupSubtitle => 'Exporter / importer';

  @override
  String get settingsDemoMode => 'Mode démo';

  @override
  String get settingsDemoModeSubtitleBrowseDemo =>
      'Navigation démo jusqu\'à ajout d\'une liste';

  @override
  String get settingsDemoModeSubtitleRealChannels =>
      'Chaînes réelles — démo désactivée si listes';

  @override
  String get settingsDemoModeAbout =>
      'Démo intégrée : TV direct, films et séries d\'exemple avec visuels inclus et listes fictives. Lecture en flux démo. Ajoutez une liste Xtream ou M3U pour votre IPTV réel.';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Langue de l\'interface';

  @override
  String get settingsPerformance => 'Performances';

  @override
  String get settingsPerformanceSubtitle =>
      'Qualité complète ou optimisé pour appareils modestes';

  @override
  String get performanceScreenTitle => 'Performances';

  @override
  String get performanceScreenIntro =>
      'Choisissez la charge pour l\'appareil. Les streamers puissants (ex. NVIDIA Shield) peuvent utiliser la qualité complète. Les clés TV tournent souvent mieux en Optimisé. Automatique se base sur la mémoire. Modifiable à tout moment.';

  @override
  String get performanceModeAuto => 'Automatique';

  @override
  String get performanceModeAutoSubtitle =>
      'Recommandé — choix selon la mémoire';

  @override
  String get performanceModeFull => 'Qualité complète';

  @override
  String get performanceModeFullSubtitle =>
      'Meilleur rendu — matériel puissant';

  @override
  String get performanceModeOptimized => 'Optimisé';

  @override
  String get performanceModeOptimizedSubtitle =>
      'Fond plus léger, cache réduit, catalogue différé. Un décodeur vidéo à la fois (l’aperçu grille se met en pause au plein écran) — plus fluide sur les TV modestes';

  @override
  String performanceDetectedRam(String mb) {
    return 'RAM totale détectée : $mb Mo';
  }

  @override
  String get performanceDetectedRamUnknown =>
      'RAM non détectée — Automatique = qualité complète';

  @override
  String get performanceAutoCurrentlyUsingFull =>
      'Pour l’instant, Automatique utilise la qualité complète.';

  @override
  String get performanceAutoCurrentlyUsingOptimized =>
      'Pour l’instant, Automatique utilise Optimisé.';

  @override
  String get settingsLightningSwitch => 'Lightning switch';

  @override
  String get settingsLightningSwitchSubtitle =>
      'Faster live channel changes (strong devices only)';

  @override
  String get lightningSwitchScreenTitle => 'Lightning switch';

  @override
  String get lightningSwitchScreenIntro =>
      'When off, live TV uses the same single-decoder path as Optimized — same buffering and timing. Turn on to use a second decoder for very fast channel changes; this uses more memory and may cause lag on some devices.';

  @override
  String get lightningSwitchModeOff => 'Off';

  @override
  String get lightningSwitchModeOffSubtitle =>
      'Same live player behavior as Optimized';

  @override
  String get lightningSwitchModeOn => 'On';

  @override
  String get lightningSwitchModeOnSubtitle =>
      'Dual-decoder pool — fastest zaps; may lag on some devices';

  @override
  String get lightningSwitchLagSnack =>
      'Lightning is on. If you notice lag, turn it off here.';

  @override
  String get tvRemoteTypingButton => 'Saisir avec la télécommande';

  @override
  String get tvRemoteTypingTitle => 'Saisie de texte';

  @override
  String get tvRemoteTypingDone => 'Terminé';

  @override
  String get tvRemoteGoogleTvKeyboardHint =>
      'Le clavier à l’écran peut ne pas s’ouvrir sur Google TV ou Chromecast. Utilisez la ligne ci-dessus pour saisir avec la télécommande.';

  @override
  String get tvKeyboardLanguagesTitle => 'Langues';

  @override
  String get tvKeyboardPickLanguagesSubtitle =>
      'Cochez les langues à afficher dans la liste (haut ou globe). L’ordre suit l’ordre d’ajout.';

  @override
  String get tvKeyboardLayoutNotAvailable =>
      'Clavier à l’écran pas encore disponible pour cette langue.';

  @override
  String get languageScreenTitle => 'Langue';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageHebrew => 'Hébreu';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get languageRussian => 'Russe';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageItalian => 'Italien';

  @override
  String get languageTurkish => 'Turc';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languageChinese => 'Chinois';

  @override
  String get languageVietnamese => 'Vietnamien';

  @override
  String get actionPlay => 'Lecture';

  @override
  String get actionExternal => 'Externe';

  @override
  String get actionTrailer => 'Bande-annonce';

  @override
  String get actionMyList => 'Ma liste';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionWatched => 'Vu';

  @override
  String get actionUnwatch => 'Annuler';

  @override
  String get actionWatching => 'En cours';

  @override
  String get actionWatchingOff => 'Retirer';

  @override
  String get actionContinueWatching => 'Reprendre';

  @override
  String get actionContinueWatchingOff => 'Effacer';

  @override
  String get navLiveTv => 'TV en direct';

  @override
  String get navMovies => 'Films';

  @override
  String get navSeries => 'Séries';

  @override
  String get navRecording => 'Rattrapage';

  @override
  String get navPlaylist => 'Playlist';

  @override
  String get navTheme => 'Thème';

  @override
  String get navClock => 'Horloge';

  @override
  String get navAppearance => 'Apparence';

  @override
  String get navBackup => 'Sauvegarde';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navLanguage => 'Langue';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get nsCategoryOldSettings => 'Anciens paramètres';

  @override
  String get searchMoviesAndSeries => 'Rechercher films et séries';

  @override
  String get searchLiveTv => 'Rechercher TV en direct';

  @override
  String get searchRecording => 'Rechercher rattrapage';

  @override
  String get searchHint => 'Saisir pour filtrer cette page';

  @override
  String get searchClear => 'Effacer';

  @override
  String get searchApply => 'Appliquer';

  @override
  String get searchLabel => 'Rechercher';

  @override
  String searchPrefixWithQuery(String query) {
    return 'Recherche : $query';
  }

  @override
  String get playlistEmptyTitle => 'Aucune playlist';

  @override
  String get playlistEmptySubtitle => 'Ajoutez-en dans Paramètres';

  @override
  String get playlistGoToSettings => 'Aller aux paramètres';

  @override
  String get playlistDismissBarrier => 'Fermer le sélecteur de playlist';

  @override
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount) {
    return '$liveCount direct · $movieCount films · $seriesCount séries';
  }

  @override
  String get topMenuManagerTitle => 'Gestionnaire du menu supérieur';

  @override
  String get topMenuOrderSection => 'Ordre du menu';

  @override
  String get topMenuReorderHelp =>
      'OK pour prendre, Haut/Bas pour déplacer, OK pour déposer.';

  @override
  String get topMenuRemoveHelp =>
      'Onglets optionnels : Droite pour retirer de la barre (OK = prendre / déposer).';

  @override
  String get topMenuAddToMenu => 'Ajouter au menu';

  @override
  String get topMenuStartupSection => 'Catégorie au démarrage';

  @override
  String get topMenuStartupHelp => 'Écran affiché au lancement de l’app.';

  @override
  String get topMenuSettingsLocked => 'Paramètres';

  @override
  String get topMenuAlwaysLast => 'Toujours en dernier';

  @override
  String get commonBack => 'Retour';

  @override
  String get mvPickerAddChannel => 'Ajouter une chaîne';

  @override
  String get mvPickerChangeChannel => 'Changer de chaîne';

  @override
  String get mvChooseChannel => 'Choisir une chaîne';

  @override
  String get mvAddScreen => 'Ajouter un écran';

  @override
  String get mvChangeChannel => 'Changer de chaîne';

  @override
  String get mvReduceScreen => 'Réduire l’écran';

  @override
  String get mvEnlargeScreen => 'Agrandir l’écran';

  @override
  String get mvFullScreen => 'Plein écran';

  @override
  String get mvRemoveScreen => 'Retirer l’écran';

  @override
  String get mvExitMultiview => 'Quitter le multiview';

  @override
  String get mvMenuTitle => 'Multiview';

  @override
  String get mvMenuHint => '▲▼ déplacer · OK · Retour';

  @override
  String get demoBlurbLiveTv =>
      'Démo TV direct : pastilles et grille avec logos inclus. Panneau héros et libellés ; flux démo à l’ouverture du lecteur.';

  @override
  String get demoBlurbMovies =>
      'Démo films : rangées avec affiches incluses et détails fictifs. Focus sur un titre pour le héros et le synopsis.';

  @override
  String get demoBlurbSeries =>
      'Démo séries : affiches incluses, saisons et épisodes. Même flux que Films ; flux démo à la lecture.';

  @override
  String get demoBlurbRecording =>
      'Parcourir le catch-up par catégorie, date et chaîne.';

  @override
  String get demoBlurbTeam =>
      'Choisissez Cosmic, Aurora, Solar ou Heritage pour le thème.';

  @override
  String get demoBlurbSettings =>
      'Hub paramètres démo. Playlist et lecture plus tard.';

  @override
  String get demoBlurbOptional =>
      'Destination optionnelle. Activez-la dans le gestionnaire de menu.';

  @override
  String get clockInfoBanner =>
      'Optional floating clock on top of the app. Turn it ON or OFF — the top bar always shows the time; this overlay is extra. Choose 12 or 24 hour, size, corner of the screen, brightness (opacity), and color. Frame adds a border and shows the date under the time; turn it off for time only. Use Adjust position to nudge the overlay per corner with the D-pad. Move focus with the remote and Select to apply each option; changes apply everywhere while you use the app.';

  @override
  String get clockToggleOn => 'Horloge ON';

  @override
  String get clockToggleOff => 'Horloge OFF';

  @override
  String get clockTapHide => 'Appuyer pour masquer';

  @override
  String get clockTapShow => 'Appuyer pour afficher';

  @override
  String get clockFrameOn => 'Cadre ON';

  @override
  String get clockFrameOff => 'Cadre OFF';

  @override
  String get clockFrameSubOn => 'Bordure + date sous l’heure';

  @override
  String get clockFrameSubOff => 'Heure seule (sans bordure ni date)';

  @override
  String get clock12Hour => '12 h';

  @override
  String get clock12HourSub => 'AM / PM';

  @override
  String get clock24Hour => '24 h';

  @override
  String get clock24HourSub => '00–23';

  @override
  String get clockSizeSmall => 'Petit';

  @override
  String get clockSizeMedium => 'Moyen';

  @override
  String get clockSizeLarge => 'Grand';

  @override
  String get clockSizeSubtitle => 'Taille';

  @override
  String get clockCornerSubtitle => 'Coin';

  @override
  String get clockCornerTopLeft => 'Haut gauche';

  @override
  String get clockCornerTopRight => 'Haut droite';

  @override
  String get clockCornerBottomLeft => 'Bas gauche';

  @override
  String get clockCornerBottomRight => 'Bas droite';

  @override
  String get clockAdjustPosition => 'Ajuster la position';

  @override
  String get clockAdjustPositionSub => 'D-pad déplace · Retour enregistre';

  @override
  String get clockOpacitySubtitle => 'Opacité';

  @override
  String clockOpacityPercent(int percent) {
    return '$percent %';
  }

  @override
  String clockColorPreset(int index) {
    return 'Couleur $index';
  }

  @override
  String get clockColorPresetSubtitle => 'Préréglage';

  @override
  String get clockPositionAdjustTitle => 'Ajuster la position';

  @override
  String clockPositionCornerLine(String corner) {
    return 'Coin : $corner';
  }

  @override
  String clockPositionOffsetLine(int dx, int dy, int max) {
    return 'Décalage : $dx × $dy (max ±$max)';
  }

  @override
  String get clockPositionHelpEnabled =>
      'Utilisez la croix directionnelle pour déplacer l’horloge. Changements pour ce coin uniquement. Retour vers Réglages horloge.';

  @override
  String get clockPositionHelpDisabled =>
      'Activez l’horloge pour voir la superposition pendant le réglage. Les décalages sont enregistrés par coin.';

  @override
  String get appearanceLayoutEditors => 'Éditeurs de mise en page';

  @override
  String get appearanceHeroBackgroundTitle => 'Arrière-plan du héros';

  @override
  String get appearanceHeroBackgroundSubtitle =>
      'Couleurs derrière l’aperçu TV';

  @override
  String get heroAppearanceScreenTitle => 'Arrière-plan du héros';

  @override
  String get heroAppearanceHint =>
      'Les changements sont enregistrés automatiquement. Réinitialiser restaure le thème par défaut.';

  @override
  String get heroAppearanceReset => 'Réinitialiser';

  @override
  String get heroAppearanceHideControls => 'Masquer les commandes';

  @override
  String get heroAppearanceShowControls => 'Afficher les commandes';

  @override
  String get heroAppearanceBase => 'Couleur de base';

  @override
  String get heroAppearanceWash => 'Couleur de lavis';

  @override
  String get heroAppearanceIntensity => 'Intensité du lavis';

  @override
  String get heroAppearanceBrushStyle => 'Style de lavis';

  @override
  String get heroAppearanceSectionBackground => 'Arrière-plan';

  @override
  String get heroAppearanceSectionTv => 'Cadre de l’aperçu';

  @override
  String get heroAppearanceSectionFineTune => 'Réglages fins';

  @override
  String get heroAppearanceShowFrame => 'Afficher le cadre TV';

  @override
  String get heroAppearanceFrameProfile => 'Profil du cadre';

  @override
  String get heroAppearanceBezelFinish => 'Fini du cadre';

  @override
  String get heroAppearanceGradientDepth => 'Profondeur du dégradé';

  @override
  String get heroAppearanceFrameSlim => 'Fin';

  @override
  String get heroAppearanceFrameClassic => 'Classique';

  @override
  String get heroAppearanceFrameBold => 'Épais';

  @override
  String get heroAppearanceFrameMinimal => 'Minimal';

  @override
  String get heroAppearanceOn => 'Actif';

  @override
  String get heroAppearanceOff => 'Inactif';

  @override
  String get heroAppearanceTabColors => 'Couleurs';

  @override
  String get heroAppearanceTabOverlay => 'Calque';

  @override
  String get heroAppearanceTabFrame => 'Cadre';

  @override
  String get heroAppearanceTabMore => 'Plus';

  @override
  String get heroAppearanceWashModeBrush => 'Pinceau';

  @override
  String get heroAppearanceWashModeSolid => 'Uni';

  @override
  String get heroAppearanceHintShort => 'Enregistrement auto.';

  @override
  String get heroAppearanceSolidHint =>
      'Teinte plein écran — réglage sous Calque.';

  @override
  String get heroAppearanceHelpIntro =>
      'Utilisez − et + sur chaque ligne. Les grands carrés montrent le fond et la couche. Regardez l’aperçu TV ci-dessus.';

  @override
  String get heroAppearancePreviewBackgroundLabel => 'Fond';

  @override
  String get heroAppearancePreviewOverlayLabel => 'Calque';

  @override
  String get heroAppearanceHueRow => 'Teinte';

  @override
  String get heroAppearanceSatRow => 'Vividité';

  @override
  String get heroAppearanceBriRow => 'Luminosité';

  @override
  String get heroAppearanceHueExplain => 'Autour de l’arc-en-ciel';

  @override
  String get heroAppearanceSatExplain => 'Gris ↔ couleur';

  @override
  String get heroAppearanceBriExplain => 'Sombre ↔ clair';

  @override
  String get heroAppearanceFrameBanner => 'Cadre TV';

  @override
  String get heroAppearanceFrameExplain =>
      'Bordure autour du petit aperçu TV. Activez, puis épaisseur et finition.';

  @override
  String appearancePerRowSubtitle(int count) {
    return '$count/ligne';
  }

  @override
  String get appearanceChannelCardStyle => 'Style carte chaîne';

  @override
  String get appearanceMovieCardStyle => 'Style carte film';

  @override
  String get appearanceSeriesCardStyle => 'Style carte série';

  @override
  String get cardStyleLiveNameOnly => 'Nom seul';

  @override
  String get cardStyleLiveLogoNameProgram => 'Logo + nom + programme';

  @override
  String get cardStyleLiveLogoNameOnly => 'Logo + nom';

  @override
  String get cardStyleLiveLogoOnly => 'Logo seul';

  @override
  String get movieGridSettingsTitle => 'Paramètres grille films';

  @override
  String get movieGridMoviesPerRow => 'Films par rangée :';

  @override
  String get movieGridPosterDisplay => 'Affichage affiche :';

  @override
  String get movieGridExit => 'Quitter';

  @override
  String get movieGridResetDefaults => 'Réinitialiser';

  @override
  String get movieGridHidePanel => 'Masquer';

  @override
  String get movieGridShowPanel => 'Afficher';

  @override
  String get seriesGridSettingsTitle => 'Paramètres grille séries';

  @override
  String get seriesGridSeriesPerRow => 'Séries par rangée :';

  @override
  String get channelGridSettingsTitle => 'Grille des chaînes';

  @override
  String get channelGridHeroBannerSize => 'Taille du bandeau héros :';

  @override
  String get channelGridChannelsPerRowLabel => 'Chaînes par ligne :';

  @override
  String get channelGridChannelDisplay => 'Affichage chaîne :';

  @override
  String get channelGridChNamePosition => 'Position du nom :';

  @override
  String get channelGridShowSettingsPanel => 'Afficher les réglages';

  @override
  String get cardStylePosterTitle => 'Affiche+nom+année';

  @override
  String get cardStylePosterOnly => 'Affiche seule';

  @override
  String get cardStyleNamePoster => 'Nom+affiche';

  @override
  String get cardStyleTitleOnly => 'Titre seul';

  @override
  String get catalogLoading => 'Chargement…';

  @override
  String get catalogLoadingChannels => 'Chargement des chaînes…';

  @override
  String get catalogLoadingLibrary => 'Chargement de la bibliothèque…';

  @override
  String get catalogPreparing => 'Préparation…';

  @override
  String get catalogErrorPlaylist => 'Impossible de charger la liste';

  @override
  String get catalogErrorLibrary => 'Impossible de charger la bibliothèque';

  @override
  String get catalogNoCategories => 'Aucune catégorie';

  @override
  String get catalogNoCategoriesSubtitle =>
      'Cette liste n’a renvoyé aucune catégorie live.';

  @override
  String get myPlaylistsTitle => 'Mes listes';

  @override
  String get myPlaylistsSubtitle => 'Une seule liste active à la fois.';

  @override
  String get myPlaylistsEmpty => 'Aucune liste. Ajoutez-en dans Paramètres.';

  @override
  String get dialogRenamePlaylist => 'Renommer la liste';

  @override
  String get dialogEditPlaylist => 'Modifier la liste';

  @override
  String get dialogPlaylistServerUrl => 'URL du serveur';

  @override
  String get dialogPlaylistUsername => 'Nom d\'utilisateur';

  @override
  String get dialogPlaylistPassword => 'Mot de passe';

  @override
  String get dialogPlaylistM3uUrl => 'URL M3U';

  @override
  String get dialogPlaylistEditInvalid =>
      'Remplissez tous les champs obligatoires.';

  @override
  String get dialogPlaylistNameHint => 'Nom';

  @override
  String get dialogCancel => 'Annuler';

  @override
  String get dialogSave => 'Enregistrer';

  @override
  String get dialogDelete => 'Supprimer';

  @override
  String get dialogDeletePlaylistTitle => 'Supprimer la liste ?';

  @override
  String dialogDeletePlaylistBody(String name) {
    return '« $name » sera supprimé de cet appareil.';
  }

  @override
  String get playlistTypeXtream => 'Xtream';

  @override
  String get playlistTypeM3u => 'M3U';

  @override
  String myPlaylistTileStats(String type, int live, int movies, int series) {
    return '$type · L$live M$movies S$series';
  }

  @override
  String get playlistActiveBadge => 'ACTIF';

  @override
  String get playlistSubscriptionActive => 'Actif';

  @override
  String get playlistSubscriptionExpired => 'Expiré';

  @override
  String playlistExpireOn(String date) {
    return 'Expire le $date';
  }

  @override
  String get playlistChipGroups => 'Groupes';

  @override
  String get playlistChipManageChannels => 'Gérer les chaînes';

  @override
  String get manageLiveChannelsTitle => 'Gérer les chaînes';

  @override
  String get manageLiveChannelsSubtitle =>
      'Choisissez une catégorie, puis renommez, masquez ou définissez un logo.';

  @override
  String get manageLiveChannelsNeedActive => 'Activez d’abord cette liste.';

  @override
  String get manageLiveChannelsNoCategories =>
      'Aucune catégorie live. Synchronisez la liste.';

  @override
  String get manageLiveChannelsCategoryEmpty =>
      'Aucune chaîne dans cette catégorie.';

  @override
  String get channelOverrideNameAction => 'Nom';

  @override
  String get channelOverrideLogoAction => 'Logo';

  @override
  String get channelOverrideHiddenFromLive => 'Masqué dans le direct';

  @override
  String get channelOverrideVisibleInLive => 'Visible dans le direct';

  @override
  String get channelOverrideDisplayNameDialogTitle => 'Nom affiché';

  @override
  String get channelOverrideDisplayNameHint => 'Vide = nom du serveur.';

  @override
  String get channelOverrideLogoDialogTitle => 'URL du logo';

  @override
  String get channelOverrideLogoDialogHint =>
      'Lien https:// vers PNG ou JPG. Vide = logo de la liste.';

  @override
  String get playlistGroupEdit => 'Modifier';

  @override
  String playlistGroupOriginalLabel(String name) {
    return 'D’origine : $name';
  }

  @override
  String get playlistGroupCustomNameHint => 'Nom personnalisé';

  @override
  String get playlistGroupResetAlias => 'Réinitialiser';

  @override
  String get playlistGroupPillOrderTitle => 'Ordre des pastilles (direct)';

  @override
  String get playlistGroupPillAfterFavorites => 'Après mes favoris';

  @override
  String get playlistGroupPillBeforeFavorites => 'Avant mes favoris';

  @override
  String get playlistGroupPillPositionLabel => 'Position (1 = première)';

  @override
  String get playlistGroupPillPositionHint => '1';

  @override
  String get playlistEpgLocal => 'EPG : local';

  @override
  String get playlistEpgOriginal => 'EPG : d’origine';

  @override
  String get playlistEpgTimeScreenTitle => 'Heure EPG';

  @override
  String get playlistEpgTimeScreenHint =>
      'Choisissez comment afficher les heures des programmes pour cette liste.';

  @override
  String get playlistEpgTimeRowLocal => 'Local';

  @override
  String get playlistEpgTimeRowLocalSubtitle => 'Fuseau horaire de l’appareil';

  @override
  String get playlistEpgTimeRowOriginal => 'Original (serveur)';

  @override
  String get playlistEpgTimeRowOriginalSubtitle =>
      'Heures envoyées par le fournisseur';

  @override
  String playlistEpgZoneChip(String zone) {
    return 'EPG : $zone';
  }

  @override
  String get playlistChipUse => 'Utiliser';

  @override
  String get playlistChipOn => 'On';

  @override
  String get playlistChipRename => 'Ren';

  @override
  String get playlistChipDelete => 'Suppr';

  @override
  String get favSetupInfoBanner =>
      'Créez vos propres catégories TV en direct. Ajoutez un favori, donnez un nom et un ordre (les petits numéros passent en premier), puis Choisissez les chaînes — le premier choix est la position 1, le second la 2, etc. Ouvrez une fiche pour modifier ou supprimer. Vos favoris apparaissent sur la TV en direct comme des pastilles de catégorie à côté de votre liste, même si vous masquez les groupes de la liste.';

  @override
  String get favNewFavorite => 'Nouveau favori';

  @override
  String get favCreateGroup => 'Créer un groupe';

  @override
  String favGroupSubtitle(int count, int order) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaînes',
      one: '1 chaîne',
    );
    return '$_temp0 · ordre $order';
  }

  @override
  String get favEditNew => 'Nouveau favori';

  @override
  String get favEditEdit => 'Modifier le favori';

  @override
  String get favEditNameLabel => 'Nom';

  @override
  String get favEditNameHint => 'Affiché sur la TV en direct comme catégorie';

  @override
  String get favEditOrderLabel => 'Ordre';

  @override
  String get favEditOrderHint => 'Plus petit = en premier parmi les favoris';

  @override
  String get favEditChooseChannels => 'Choisir les chaînes';

  @override
  String selectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get favEditOrderHelp =>
      'Ordre : 1er appui = 1, 2e = 2… Utilisez Tout dans la catégorie / Vider la catégorie dans le sélecteur.';

  @override
  String get favEditChannelsHeading => 'Chaînes dans ce favori';

  @override
  String get favEditNoChannels =>
      'Aucune chaîne pour l’instant.\nAppuyez sur Choisir les chaînes.';

  @override
  String get favEditSave => 'Enregistrer';

  @override
  String get favEditDelete => 'Supprimer';

  @override
  String get defaultFavoriteName => 'Favori';

  @override
  String get favPickNoXtream => 'Pas de liste Xtream';

  @override
  String get favPickNoXtreamSubtitle =>
      'Ajoutez une liste Xtream Codes dans Mes listes pour choisir des chaînes depuis tout panneau enregistré.';

  @override
  String get favPickHelpWithPlaylist =>
      'Liste → catégorie → grille. Enregistrer en bas. Retour → Enregistrer.';

  @override
  String get favPickHelpOrderBadges =>
      'Choix en haut (1,2,3…). Retour → Enregistrer.';

  @override
  String get favPickHelpSimple => 'Choix en haut. Retour → Enregistrer.';

  @override
  String get favPickInFavorite => 'Dans ce favori';

  @override
  String get favPickNoChannelsDraft =>
      'Aucune chaîne — choisissez dans la grille ci-dessous.';

  @override
  String get favPickChannelUnavailable => 'Chaîne indisponible';

  @override
  String get favPickAddMore => 'Ajouter';

  @override
  String get favPickNoChannelsCategory => 'Aucune chaîne dans cette catégorie.';

  @override
  String get favPickAllInCategory => 'Tout dans la catégorie';

  @override
  String get favPickClearCategory => 'Vider la catégorie';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get backupInfoBanner =>
      'Personnel inclut les mots de passe (gardez-le privé). Partage retire les mots de passe (sûr à envoyer).';

  @override
  String get backupExportPersonal => 'Exporter personnel';

  @override
  String get backupExportPersonalSub =>
      'Sauvegarde complète avec mots de passe';

  @override
  String get backupExportShare => 'Exporter pour partager';

  @override
  String get backupExportShareSub => 'Mots de passe retirés';

  @override
  String get backupShareLastExport => 'Partager la dernière exportation';

  @override
  String get backupShareLastExportSub =>
      'Envoyer le fichier que vous venez d’enregistrer';

  @override
  String get backupShareLatest => 'Partager la dernière';

  @override
  String get backupShareLatestSub => 'E-mail, Drive, etc.';

  @override
  String get backupImportNavigate => 'Importer une sauvegarde';

  @override
  String get backupImportNavigateSub => 'Restaurer depuis un fichier';

  @override
  String get backupDeleteNavigate => 'Supprimer les sauvegardes';

  @override
  String get backupDeleteNavigateSub => 'Supprimer d’anciens fichiers';

  @override
  String get backupToastStorageRequired =>
      'L’autorisation de stockage est requise pour enregistrer les sauvegardes.';

  @override
  String backupToastSavedDownloads(String name) {
    return 'Enregistré dans Téléchargements : $name';
  }

  @override
  String backupToastExportFailed(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String get backupShareSubject => 'Sauvegarde TVMate Pro';

  @override
  String get backupShareBody => 'Sauvegarde des paramètres TVMate Pro';

  @override
  String get backupToastNoBackupsToShare =>
      'Aucun fichier de sauvegarde. Exportez d’abord.';

  @override
  String backupToastShareFailed(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get backupImportRestoredToast =>
      'Sauvegarde restaurée. Actualisation des catalogues.';

  @override
  String get nsMessageBackupAppliedTitle => 'Sauvegarde appliquée';

  @override
  String get nsMessageErrorTitle => 'Un problème est survenu';

  @override
  String get nsMessageDismiss => 'Fermer';

  @override
  String backupImportFailedToast(String error) {
    return 'Échec de l’import : $error';
  }

  @override
  String get backupImportTitle => 'Importer une sauvegarde';

  @override
  String get backupImportScanSubtitle =>
      'Analyse de tout le dossier Téléchargements pour les fichiers tvmate-backup';

  @override
  String get backupImportRefresh => 'Actualiser';

  @override
  String get backupImportRestoring => 'Restauration…';

  @override
  String get backupImportEmpty =>
      'Aucun fichier de sauvegarde dans Téléchargements.';

  @override
  String get backupManageTitle => 'Supprimer les sauvegardes';

  @override
  String get backupManageSelectAll => 'Tout sélectionner';

  @override
  String get backupManageClearAll => 'Tout désélectionner';

  @override
  String get backupManageDelete => 'Supprimer';

  @override
  String backupManageDeleteCount(int count) {
    return 'Supprimer ($count)';
  }

  @override
  String get backupManageDeleteConfirmTitle => 'Supprimer les sauvegardes ?';

  @override
  String backupManageDeleteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers seront supprimés de Téléchargements.',
      one: '1 fichier sera supprimé de Téléchargements.',
    );
    return '$_temp0';
  }

  @override
  String get backupManageToastRemoved =>
      'Sauvegardes sélectionnées supprimées.';

  @override
  String get backupManageEmpty => 'Aucun fichier de sauvegarde.';

  @override
  String get settingsSubtitles => 'Subtitles';

  @override
  String get settingsSubtitlesSubtitle => 'Default subtitle language';

  @override
  String get subtitleSettingsTitle => 'Subtitles';

  @override
  String get subtitleSettingsDefaultLanguage => 'Default subtitle language';

  @override
  String get subtitleSettingsDefaultLanguageHint =>
      'Search results list this language first.';

  @override
  String get subtitleSettingsApiKey => 'OpenSubtitles API key';

  @override
  String get subtitleSettingsApiKeyHint =>
      'Create a free consumer key at opensubtitles.com';

  @override
  String get subtitleSettingsSaveApiKey => 'Save API key';

  @override
  String get subtitleVodPickerTitle => 'Subtitles';

  @override
  String get subtitleVodLoading => 'Searching…';

  @override
  String get subtitleVodEmpty => 'No subtitles found.';

  @override
  String get subtitleVodLanguages => 'Languages';

  @override
  String get subtitleVodFiles => 'Files';

  @override
  String get subtitleVodClear => 'Off';

  @override
  String get subtitleVodPickLanguage =>
      'Choose a language on the left, or turn subtitles off.';

  @override
  String get subtitleVodNoApiKey =>
      'Add your OpenSubtitles API key in Settings → Subtitles.';

  @override
  String get subtitleVodFooterSelect => 'Select';

  @override
  String get subtitleAppearanceTitle => 'Subtitle look';

  @override
  String get subtitleAppearanceSubtitles => 'Subtitles';

  @override
  String get subtitleAppearanceBackground => 'Background color';

  @override
  String get subtitleAppearanceBackgroundOpacity => 'Background transparency';

  @override
  String get subtitleAppearanceTextColor => 'Subtitle color';

  @override
  String get subtitleAppearanceSize => 'Subtitle size';

  @override
  String get subtitleAppearancePosition => 'Subtitle position';

  @override
  String get subtitleAppearancePositionReady =>
      'Press Select (OK) to move; press again when done. Then ↑↓←→.';

  @override
  String get subtitleAppearancePositionMoving =>
      'Moving — D-pad to place. Select to finish. Back cancels move.';

  @override
  String get subtitleAppearanceHint =>
      '↑↓ rows · Position: Select twice to move. Exit or Reset below.';

  @override
  String get subtitleAppearanceExitMenu => 'Exit';

  @override
  String get subtitleAppearanceResetDefaults => 'Reset defaults';

  @override
  String get subtitleAppearanceLabelSubtitleBackground =>
      'Fond des sous-titres :';

  @override
  String get subtitleAppearanceLabelTransparency => 'Transparence :';

  @override
  String get subtitleAppearancePreviewLine => 'Aperçu des sous-titres';

  @override
  String get subtitleAppearanceVodPanelTitle => 'Édition des sous-titres';

  @override
  String get subtitleAppearancePositionShort => 'Position';

  @override
  String get parentalSettingsTitle => 'Parental control';

  @override
  String get parentalSettingsSubtitle =>
      'PIN, locks, and blocked channels or titles';

  @override
  String get parentalDialogEnterPin => 'Enter PIN';

  @override
  String get parentalDialogPinLabel => 'PIN (4–8 digits)';

  @override
  String get parentalDialogSubmit => 'Submit';

  @override
  String get parentalPinWrong => 'Wrong PIN.';

  @override
  String get parentalSetupWarning =>
      'Important: remember this PIN. If you forget it, you may need to clear app data or restore from backup. TVMate Pro cannot show your PIN again.';

  @override
  String get parentalSetupTitle => 'Create PIN';

  @override
  String get parentalSetupPinLabel => 'New PIN';

  @override
  String get parentalSetupConfirmLabel => 'Confirm PIN';

  @override
  String get parentalMismatch => 'PINs do not match.';

  @override
  String get parentalEnabledLabel => 'Parental control on';

  @override
  String get parentalLockAllLive => 'Lock all Live TV';

  @override
  String get parentalLockAllMovies => 'Lock all Movies';

  @override
  String get parentalLockAllSeries => 'Lock all Series';

  @override
  String get parentalHelpTitle => 'How it works';

  @override
  String get parentalHelpBody =>
      'Set a 4–8 digit PIN. Turn on locks here, or from Live TV (Menu on a channel), movie or series screens (lock icon) to block one channel, category, title, or show. Blocked items ask for the PIN before playback.';

  @override
  String get parentalSetPinCta => 'Save PIN';

  @override
  String get parentalCreateYourKeyTile => 'Create your key';

  @override
  String get parentalCreateYourKeySubtitle =>
      'Select to set a PIN and use these controls';

  @override
  String get parentalChangePin => 'Change PIN';

  @override
  String get parentalClearAll => 'Clear parental (reset PIN and rules)';

  @override
  String get parentalScopeTitleLive => 'Lock on Live TV';

  @override
  String get parentalBlockThisChannel => 'This channel only';

  @override
  String get parentalScopeLockChannelOnly => 'Lock channel';

  @override
  String get parentalScopeLockChannelAndHideBrowse =>
      'Lock channel & hide in browse';

  @override
  String get parentalScopeLockCategoryOnly => 'Lock category or group';

  @override
  String get parentalScopeLockCategoryAndHideBrowse =>
      'Lock category or group & hide in browse';

  @override
  String get parentalBlockCategoryOrGroup =>
      'Entire category or favorite group';

  @override
  String get parentalScopeTitleMovie => 'Lock movie';

  @override
  String get parentalBlockThisMovie => 'This movie only';

  @override
  String get parentalBlockMovieCategory => 'Entire movie category';

  @override
  String get parentalScopeTitleSeries => 'Lock series';

  @override
  String get parentalBlockThisShow => 'This show only';

  @override
  String get parentalBlockSeriesCategory => 'Entire series category';

  @override
  String get parentalLockSaved => 'Lock saved.';

  @override
  String get parentalUnlocked => 'Déverrouillé.';

  @override
  String get parentalUnlockThisChannel => 'Déverrouiller cette chaîne';

  @override
  String get parentalUnlockCategoryOrGroup =>
      'Déverrouiller cette catégorie ou ce groupe';

  @override
  String get parentalUnlockThisMovie => 'Déverrouiller ce film';

  @override
  String get parentalUnlockMovieCategory =>
      'Déverrouiller cette catégorie de films';

  @override
  String get parentalUnlockThisShow => 'Déverrouiller cette série';

  @override
  String get parentalUnlockSeriesCategory =>
      'Déverrouiller cette catégorie de séries';

  @override
  String get parentalPlayerParental => 'Parental';

  @override
  String get playerEpgPanelLabel => 'EPG';

  @override
  String get playerRightPanelQuality => 'Qualité';

  @override
  String get playerVodDownloadDownloading => 'Downloading…';

  @override
  String get playerVodDownloadVideoTypes => 'Video files';

  @override
  String get playerVodDownloadPlaylistNotSupported =>
      'This stream is a playlist (HLS), not a single video file. Download is not available for this format.';

  @override
  String playerVodDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String playerVodDownloadSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get playerVodDownloadAlreadyInProgress =>
      'A download is already in progress.';

  @override
  String get playerVodDownloadCancel => 'Cancel download';

  @override
  String get playerVodDownloadPickingLocation => 'Choose where to save…';

  @override
  String get playerVodDownloadSavingToDownloadsFolder => 'Saving to Downloads…';

  @override
  String get playerVodDownloadCopying => 'Saving…';

  @override
  String get playerVodDownloadErrorEmpty => 'Empty file';

  @override
  String playerVodDownloadSavedShort(String title) {
    return 'Saved offline: $title';
  }

  @override
  String get playerVodDownloadSavingOffline => 'Saving offline…';

  @override
  String get accountOfflineDownloadsMenuLabel => 'Offline downloads';

  @override
  String get accountOfflineDownloadsTitle => 'Offline downloads';

  @override
  String get accountOfflineDownloadsSubtitle =>
      'Videos saved on this device. Delete items to free space.';

  @override
  String get accountOfflineDownloadsEmpty =>
      'No offline videos yet. Download from a movie or episode while playing.';

  @override
  String get accountOfflineDownloadsPlay => 'Play';

  @override
  String get accountOfflineDownloadsDelete => 'Delete';

  @override
  String get accountOfflineDownloadsDeleteTitle => 'Delete download?';

  @override
  String get accountOfflineDownloadsDeleteBody =>
      'This removes the file from your device.';

  @override
  String get accountOfflineDownloadsDeleteConfirm => 'Delete';

  @override
  String get playerEpgOverlayTitle => 'Guide des chaînes';

  @override
  String get playerEpgOverlaySchedule => 'À venir';

  @override
  String get playerEpgOverlayLoading => 'Chargement du guide…';

  @override
  String get playerEpgOverlayEmpty =>
      'Aucune information programme pour cette chaîne.';

  @override
  String get playerEpgNowBadge => 'EN DIRECT';

  @override
  String get playerEpgLiveRightNow => 'En direct maintenant';

  @override
  String get playerEpgDayToday => 'Aujourd’hui';

  @override
  String get playerEpgDayTomorrow => 'Demain';

  @override
  String get parentalMenuContextLive => 'Parental lock…';

  @override
  String get parentalMustEnableInSettings =>
      'Turn on parental control and set a PIN in Settings first.';

  @override
  String get parentalLockAndHideTitle => 'Lock & hide in browse';

  @override
  String get parentalLockAndHideSubtitle =>
      'Hide restricted items from lists (still PIN-protected if shown elsewhere)';

  @override
  String get parentalManageRestrictedRules => 'Manage restricted rules';

  @override
  String get parentalManageRestrictedRulesSubtitle =>
      'View or remove locks on channels, categories, and titles';

  @override
  String get parentalRulesTitle => 'Restricted rules';

  @override
  String get parentalRulesSectionLive => 'Live TV';

  @override
  String get parentalRulesSectionMovies => 'Movies';

  @override
  String get parentalRulesSectionSeries => 'Series';

  @override
  String get parentalRulesLockAllOn => 'Lock entire section: on';

  @override
  String get parentalRulesLockAllOff => 'Lock entire section: off';

  @override
  String get parentalRulesEmpty => 'No per-item rules for this section.';

  @override
  String get parentalRulesFavoriteGroup => 'Favorite group';

  @override
  String get parentalRulesCategory => 'Category';

  @override
  String get parentalRulesChannel => 'Channel';

  @override
  String get parentalRulesMovie => 'Movie';

  @override
  String get parentalRulesSeries => 'Series';

  @override
  String get parentalPlayerOverlayTitle => 'Parental';

  @override
  String get parentalPlayerOverlayPinTitle => 'Create PIN';

  @override
  String get parentalPlayerOverlayEnableTitle => 'Turn on parental control';

  @override
  String get parentalPlayerOverlayEnableSubtitle =>
      'Verify your PIN to enable locks from the player';

  @override
  String get parentalRulesRemoveRule => 'Remove rule';

  @override
  String get parentalScopeActionNotAvailable =>
      'This action does not apply right now.';

  @override
  String get parentalScopeChannelAlreadyBlocked =>
      'This channel is already blocked.';

  @override
  String get parentalScopeChannelNotBlocked => 'This channel is not blocked.';

  @override
  String get parentalScopeCategoryAlreadyBlocked =>
      'This category or group is already blocked.';

  @override
  String get parentalScopeCategoryNotBlocked =>
      'This category or group is not blocked.';

  @override
  String get parentalScopeNoCategoryContext =>
      'No category or group is available for this view.';

  @override
  String get parentalScopeMovieAlreadyBlocked =>
      'This movie is already blocked.';

  @override
  String get parentalScopeMovieNotBlocked => 'This movie is not blocked.';

  @override
  String get parentalScopeMovieCategoryAlreadyBlocked =>
      'This movie category is already blocked.';

  @override
  String get parentalScopeMovieCategoryNotBlocked =>
      'This movie category is not blocked.';

  @override
  String get parentalScopeSeriesAlreadyBlocked =>
      'This show is already blocked.';

  @override
  String get parentalScopeSeriesNotBlocked => 'This show is not blocked.';

  @override
  String get parentalScopeSeriesCategoryAlreadyBlocked =>
      'This series category is already blocked.';

  @override
  String get parentalScopeSeriesCategoryNotBlocked =>
      'This series category is not blocked.';

  @override
  String get parentalSideMenuSetupBody =>
      'To use parental controls, set a password first. Enter a 4–8 digit PIN below.';

  @override
  String get parentalSideMenuSetupSave => 'Save and continue';
}
