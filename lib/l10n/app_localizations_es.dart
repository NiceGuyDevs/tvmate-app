// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsTopMenuManager => 'Menú superior';

  @override
  String get settingsTopMenuManagerSubtitle => 'Reordenar, añadir, inicio';

  @override
  String get settingsShellThemeSubtitle => 'Equipo visual y colores de acento';

  @override
  String get settingsShellPlaylistSubtitle => 'Cambiar lista activa';

  @override
  String get settingsAddPlaylist => 'Añadir lista';

  @override
  String get settingsAddPlaylistSubtitle => 'Xtream o M3U';

  @override
  String get settingsMyPlaylists => 'Mis listas';

  @override
  String settingsMyPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
      zero: 'Sin listas',
    );
    return '$_temp0';
  }

  @override
  String get settingsFavoriteSetup => 'Favoritos';

  @override
  String get settingsFavoriteSetupSubtitle => 'Canales de TV favoritos';

  @override
  String get settingsClock => 'Reloj';

  @override
  String get settingsClockOn => 'Sí';

  @override
  String get settingsClockOff => 'No';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String settingsAppearanceSubtitle(int heroPercent, int columns) {
    return 'Héroe $heroPercent% · $columns por fila';
  }

  @override
  String get settingsRecordingEdit => 'Edición de repetición';

  @override
  String get settingsRecordingEditSubtitle => 'Canales de catch-up';

  @override
  String get catchupSelectPlaylistHelp =>
      'Elija una lista para configurar canales de repetición';

  @override
  String get catchupNoXtreamPlaylists =>
      'No se encontró ninguna lista Xtream.\nAñada primero una lista de ese tipo.';

  @override
  String get catchupBreadcrumbCategories => 'Repetición · Categorías';

  @override
  String catchupBreadcrumbWithCategory(String categoryName) {
    return 'Repetición · $categoryName';
  }

  @override
  String get catchupFilterQuickOn => 'Filtro repetición: SÍ';

  @override
  String get catchupFilterQuickOff => 'Filtro repetición: NO';

  @override
  String get catchupEmptyStateTitle => 'Configure el catch-up en Ajustes';

  @override
  String catchupEmptyStateBody(String entryLabel) {
    return 'Vaya a Ajustes → $entryLabel para aprobar\ncategorías y canales.';
  }

  @override
  String get catchupXtreamOnly =>
      'El catch-up solo está disponible para listas Xtream.';

  @override
  String get catchupManage => 'Gestionar catch-up';

  @override
  String get catchupGroupOptions => 'Opciones de catch-up';

  @override
  String get catchupGroupCategories => 'Categorías';

  @override
  String get catchupSelectAll => 'Seleccionar todo';

  @override
  String get catchupClearAll => 'Borrar todo';

  @override
  String catchupFilterSub(String tabName) {
    return 'Solo muestra canales cuyo origen ofrece catch-up. Oculta el resto en la pestaña $tabName de esta lista.';
  }

  @override
  String get catchupClearConfirmTitle => '¿Borrar todas las aprobaciones?';

  @override
  String catchupClearConfirmMessage(String playlistName) {
    return 'Quita cada categoría y canal aprobado de la lista de catch-up de «$playlistName». La propia lista no se modifica.';
  }

  @override
  String get catchupFilterBannerLead => 'Filtro de catch-up activo. ';

  @override
  String catchupFilterHiddenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales sin catch-up ocultos en esta lista.',
      one: '1 canal sin catch-up oculto en esta lista.',
    );
    return '$_temp0 Desactive el filtro en opciones de catch-up para aprobarlos.';
  }

  @override
  String get catchupNoChannelsInCategory => 'No hay canales en esta categoría.';

  @override
  String get catchupNoLiveCategoriesSync =>
      'No se hallaron categorías en vivo.\nSincronice primero esta lista.';

  @override
  String get settingsBackup => 'Copia de seguridad';

  @override
  String get settingsBackupSubtitle => 'Exportar / importar ajustes';

  @override
  String get settingsDemoMode => 'Modo demo';

  @override
  String get settingsDemoModeSubtitleBrowseDemo =>
      'Navegación demo hasta añadir una lista';

  @override
  String get settingsDemoModeSubtitleRealChannels =>
      'Canales reales — demo off con listas';

  @override
  String get settingsDemoModeAbout =>
      'Demo integrada: TV en vivo, películas y series de ejemplo con carteles incluidos y listas simuladas. Reproducción en modo demo. Añade una lista Xtream o M3U para usar tu IPTV real.';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Idioma de la interfaz';

  @override
  String get settingsPerformance => 'Rendimiento';

  @override
  String get settingsPerformanceSubtitle =>
      'Calidad completa u optimizado en dispositivos débiles';

  @override
  String get performanceScreenTitle => 'Rendimiento';

  @override
  String get performanceScreenIntro =>
      'Elige la carga para el dispositivo. Streamers potentes (p. ej. NVIDIA Shield) pueden usar calidad completa. Los sticks suelen ir mejor en Optimizado. Automático usa la memoria del dispositivo. Puedes cambiarlo cuando quieras.';

  @override
  String get performanceModeAuto => 'Automático';

  @override
  String get performanceModeAutoSubtitle =>
      'Recomendado — elige según la memoria';

  @override
  String get performanceModeFull => 'Calidad completa';

  @override
  String get performanceModeFullSubtitle => 'Mejor aspecto — hardware potente';

  @override
  String get performanceModeOptimized => 'Optimizado';

  @override
  String get performanceModeOptimizedSubtitle =>
      'Fondo más ligero, caché menor, catálogo diferido. Un decodificador de vídeo a la vez (el hero de la parrilla se pausa a pantalla completa) — más fluido en TVs modestos';

  @override
  String performanceDetectedRam(String mb) {
    return 'RAM total detectada: $mb MB';
  }

  @override
  String get performanceDetectedRamUnknown =>
      'RAM no detectada — Automático usa calidad completa';

  @override
  String get performanceAutoCurrentlyUsingFull =>
      'Ahora mismo, Automático usa calidad completa.';

  @override
  String get performanceAutoCurrentlyUsingOptimized =>
      'Ahora mismo, Automático usa Optimizado.';

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
  String get tvRemoteTypingButton => 'Escribir con el control remoto';

  @override
  String get tvRemoteTypingTitle => 'Introducir texto';

  @override
  String get tvRemoteTypingDone => 'Listo';

  @override
  String get tvRemoteGoogleTvKeyboardHint =>
      'El teclado en pantalla puede no abrirse en Google TV o Chromecast. Usa la línea de arriba para escribir con el mando.';

  @override
  String get tvKeyboardLanguagesTitle => 'Idiomas';

  @override
  String get tvKeyboardPickLanguagesSubtitle =>
      'Marca los idiomas que quieres ver en la lista (arriba o globo). El orden es el de añadirlos.';

  @override
  String get tvKeyboardLayoutNotAvailable =>
      'Teclado en pantalla aún no disponible para este idioma.';

  @override
  String get languageScreenTitle => 'Idioma';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageHebrew => 'Hebreo';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languageChinese => 'Chino';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get actionPlay => 'Reproducir';

  @override
  String get actionExternal => 'Externo';

  @override
  String get actionTrailer => 'Tráiler';

  @override
  String get actionMyList => 'Mi lista';

  @override
  String get actionRemove => 'Quitar';

  @override
  String get actionWatched => 'Visto';

  @override
  String get actionUnwatch => 'Desmarcar';

  @override
  String get actionWatching => 'Viendo';

  @override
  String get actionWatchingOff => 'Quitar';

  @override
  String get actionContinueWatching => 'Continuar';

  @override
  String get actionContinueWatchingOff => 'Borrar';

  @override
  String get navLiveTv => 'TV en vivo';

  @override
  String get navMovies => 'Películas';

  @override
  String get navSeries => 'Series';

  @override
  String get navRecording => 'Repetición';

  @override
  String get navPlaylist => 'Lista de reproducción';

  @override
  String get navTheme => 'Tema';

  @override
  String get navClock => 'Reloj';

  @override
  String get navAppearance => 'Apariencia';

  @override
  String get navBackup => 'Copia de seguridad';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navLanguage => 'Idioma';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get nsCategoryOldSettings => 'Ajustes antiguos';

  @override
  String get searchMoviesAndSeries => 'Buscar películas y series';

  @override
  String get searchLiveTv => 'Buscar TV en vivo';

  @override
  String get searchRecording => 'Buscar repeticiones';

  @override
  String get searchHint => 'Escribe para filtrar esta página';

  @override
  String get searchClear => 'Borrar';

  @override
  String get searchApply => 'Aplicar';

  @override
  String get searchLabel => 'Buscar';

  @override
  String searchPrefixWithQuery(String query) {
    return 'Buscar: $query';
  }

  @override
  String get playlistEmptyTitle => 'Aún no hay listas';

  @override
  String get playlistEmptySubtitle => 'Añade una en Ajustes';

  @override
  String get playlistGoToSettings => 'Ir a ajustes';

  @override
  String get playlistDismissBarrier => 'Cerrar selector de lista';

  @override
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount) {
    return '$liveCount en vivo · $movieCount películas · $seriesCount series';
  }

  @override
  String get topMenuManagerTitle => 'Administrador del menú superior';

  @override
  String get topMenuOrderSection => 'Orden del menú';

  @override
  String get topMenuReorderHelp =>
      'OK para coger, Arriba/Abajo para mover, OK para soltar.';

  @override
  String get topMenuRemoveHelp =>
      'Opcionales: Derecha para quitar de la barra (OK solo coger/soltar).';

  @override
  String get topMenuAddToMenu => 'Añadir al menú';

  @override
  String get topMenuStartupSection => 'Categoría de inicio';

  @override
  String get topMenuStartupHelp => 'Pantalla al iniciar la app.';

  @override
  String get topMenuSettingsLocked => 'Ajustes';

  @override
  String get topMenuAlwaysLast => 'Siempre al final';

  @override
  String get commonBack => 'Atrás';

  @override
  String get mvPickerAddChannel => 'Añadir canal';

  @override
  String get mvPickerChangeChannel => 'Cambiar canal';

  @override
  String get mvChooseChannel => 'Elegir canal';

  @override
  String get mvAddScreen => 'Añadir pantalla';

  @override
  String get mvChangeChannel => 'Cambiar canal';

  @override
  String get mvReduceScreen => 'Reducir pantalla';

  @override
  String get mvEnlargeScreen => 'Ampliar pantalla';

  @override
  String get mvFullScreen => 'Pantalla completa';

  @override
  String get mvRemoveScreen => 'Quitar pantalla';

  @override
  String get mvExitMultiview => 'Salir de multivista';

  @override
  String get mvMenuTitle => 'Multivista';

  @override
  String get mvMenuHint => '▲▼ mover · OK · Atrás';

  @override
  String get demoBlurbLiveTv =>
      'Demo TV en vivo: categorías y parrilla con logos incluidos. Panel héroe y etiquetas; stream de muestra al abrir el reproductor.';

  @override
  String get demoBlurbMovies =>
      'Demo películas: filas con carteles incluidos y datos ficticios. Enfoca un título para el héroe y la sinopsis.';

  @override
  String get demoBlurbSeries =>
      'Demo series: carteles incluidos, temporadas y episodios. Mismo flujo que Películas; stream de muestra al reproducir.';

  @override
  String get demoBlurbRecording =>
      'Navega el catch-up por categoría, fecha y canal.';

  @override
  String get demoBlurbTeam =>
      'Elige Cosmic, Aurora, Solar o Heritage para el tema.';

  @override
  String get demoBlurbSettings =>
      'Centro de ajustes demo. Lista y reproducción más adelante.';

  @override
  String get demoBlurbOptional =>
      'Destino opcional. Actívalo en el administrador del menú.';

  @override
  String get clockInfoBanner =>
      'Optional floating clock on top of the app. Turn it ON or OFF — the top bar always shows the time; this overlay is extra. Choose 12 or 24 hour, size, corner of the screen, brightness (opacity), and color. Frame adds a border and shows the date under the time; turn it off for time only. Use Adjust position to nudge the overlay per corner with the D-pad. Move focus with the remote and Select to apply each option; changes apply everywhere while you use the app.';

  @override
  String get clockToggleOn => 'Reloj ON';

  @override
  String get clockToggleOff => 'Reloj OFF';

  @override
  String get clockTapHide => 'Pulsa para ocultar';

  @override
  String get clockTapShow => 'Pulsa para mostrar';

  @override
  String get clockFrameOn => 'Marco ON';

  @override
  String get clockFrameOff => 'Marco OFF';

  @override
  String get clockFrameSubOn => 'Borde + fecha bajo la hora';

  @override
  String get clockFrameSubOff => 'Solo hora (sin borde ni fecha)';

  @override
  String get clock12Hour => '12 horas';

  @override
  String get clock12HourSub => 'a. m. / p. m.';

  @override
  String get clock24Hour => '24 horas';

  @override
  String get clock24HourSub => '00–23';

  @override
  String get clockSizeSmall => 'Pequeño';

  @override
  String get clockSizeMedium => 'Mediano';

  @override
  String get clockSizeLarge => 'Grande';

  @override
  String get clockSizeSubtitle => 'Tamaño';

  @override
  String get clockCornerSubtitle => 'Esquina';

  @override
  String get clockCornerTopLeft => 'Arriba izquierda';

  @override
  String get clockCornerTopRight => 'Arriba derecha';

  @override
  String get clockCornerBottomLeft => 'Abajo izquierda';

  @override
  String get clockCornerBottomRight => 'Abajo derecha';

  @override
  String get clockAdjustPosition => 'Ajustar posición';

  @override
  String get clockAdjustPositionSub => 'D-pad mueve · Atrás guarda';

  @override
  String get clockOpacitySubtitle => 'Opacidad';

  @override
  String clockOpacityPercent(int percent) {
    return '$percent %';
  }

  @override
  String clockColorPreset(int index) {
    return 'Color $index';
  }

  @override
  String get clockColorPresetSubtitle => 'Preajuste';

  @override
  String get clockPositionAdjustTitle => 'Ajustar posición';

  @override
  String clockPositionCornerLine(String corner) {
    return 'Esquina: $corner';
  }

  @override
  String clockPositionOffsetLine(int dx, int dy, int max) {
    return 'Desplazamiento: $dx × $dy (máx. ±$max)';
  }

  @override
  String get clockPositionHelpEnabled =>
      'Usa el D-pad para mover el reloj en pantalla. Los cambios solo afectan a esta esquina. Atrás vuelve a Ajustes del reloj.';

  @override
  String get clockPositionHelpDisabled =>
      'Activa el reloj para ver la superposición mientras ajustas. Los desplazamientos se guardan por esquina.';

  @override
  String get appearanceLayoutEditors => 'Editores de diseño';

  @override
  String get appearanceHeroBackgroundTitle => 'Fondo del héroe';

  @override
  String get appearanceHeroBackgroundSubtitle =>
      'Colores detrás de la vista previa de TV';

  @override
  String get heroAppearanceScreenTitle => 'Fondo del héroe';

  @override
  String get heroAppearanceHint =>
      'Los cambios se guardan solos. Restablecer vuelve al tema por defecto.';

  @override
  String get heroAppearanceReset => 'Restablecer';

  @override
  String get heroAppearanceHideControls => 'Ocultar controles';

  @override
  String get heroAppearanceShowControls => 'Mostrar controles';

  @override
  String get heroAppearanceBase => 'Color base';

  @override
  String get heroAppearanceWash => 'Color del pincel';

  @override
  String get heroAppearanceIntensity => 'Intensidad del pincel';

  @override
  String get heroAppearanceBrushStyle => 'Estilo de pincel';

  @override
  String get heroAppearanceSectionBackground => 'Fondo';

  @override
  String get heroAppearanceSectionTv => 'Marco de vista previa';

  @override
  String get heroAppearanceSectionFineTune => 'Ajuste fino';

  @override
  String get heroAppearanceShowFrame => 'Mostrar marco de TV';

  @override
  String get heroAppearanceFrameProfile => 'Perfil del marco';

  @override
  String get heroAppearanceBezelFinish => 'Acabado del marco';

  @override
  String get heroAppearanceGradientDepth => 'Profundidad del degradado';

  @override
  String get heroAppearanceFrameSlim => 'Fino';

  @override
  String get heroAppearanceFrameClassic => 'Clásico';

  @override
  String get heroAppearanceFrameBold => 'Grueso';

  @override
  String get heroAppearanceFrameMinimal => 'Mínimo';

  @override
  String get heroAppearanceOn => 'Sí';

  @override
  String get heroAppearanceOff => 'No';

  @override
  String get heroAppearanceTabColors => 'Colores';

  @override
  String get heroAppearanceTabOverlay => 'Capa';

  @override
  String get heroAppearanceTabFrame => 'Marco';

  @override
  String get heroAppearanceTabMore => 'Más';

  @override
  String get heroAppearanceWashModeBrush => 'Pincel';

  @override
  String get heroAppearanceWashModeSolid => 'Sólido';

  @override
  String get heroAppearanceHintShort => 'Se guarda solo.';

  @override
  String get heroAppearanceSolidHint => 'Tinte uniforme — fuerza en Capa.';

  @override
  String get heroAppearanceHelpIntro =>
      'Usa − y + en cada fila. Los cuadrados grandes muestran fondo y capa. Mira la vista previo de TV arriba.';

  @override
  String get heroAppearancePreviewBackgroundLabel => 'Fondo';

  @override
  String get heroAppearancePreviewOverlayLabel => 'Capa';

  @override
  String get heroAppearanceHueRow => 'Tono';

  @override
  String get heroAppearanceSatRow => 'Intensidad';

  @override
  String get heroAppearanceBriRow => 'Brillo';

  @override
  String get heroAppearanceHueExplain => 'Por el arcoíris';

  @override
  String get heroAppearanceSatExplain => 'Gris ↔ color';

  @override
  String get heroAppearanceBriExplain => 'Oscuro ↔ claro';

  @override
  String get heroAppearanceFrameBanner => 'Marco del TV';

  @override
  String get heroAppearanceFrameExplain =>
      'Borde alrededor del preview. Activa, grosor y acabado.';

  @override
  String appearancePerRowSubtitle(int count) {
    return '$count/fila';
  }

  @override
  String get appearanceChannelCardStyle => 'Estilo tarjeta de canal';

  @override
  String get appearanceMovieCardStyle => 'Estilo tarjeta de película';

  @override
  String get appearanceSeriesCardStyle => 'Estilo tarjeta de serie';

  @override
  String get cardStyleLiveNameOnly => 'Solo nombre';

  @override
  String get cardStyleLiveLogoNameProgram => 'Logo + nombre + programa';

  @override
  String get cardStyleLiveLogoNameOnly => 'Logo + nombre';

  @override
  String get cardStyleLiveLogoOnly => 'Solo logo';

  @override
  String get movieGridSettingsTitle => 'Ajustes de cuadrícula de películas';

  @override
  String get movieGridMoviesPerRow => 'Películas por fila:';

  @override
  String get movieGridPosterDisplay => 'Cartel:';

  @override
  String get movieGridExit => 'Salir';

  @override
  String get movieGridResetDefaults => 'Restablecer';

  @override
  String get movieGridHidePanel => 'Ocultar';

  @override
  String get movieGridShowPanel => 'Mostrar';

  @override
  String get seriesGridSettingsTitle => 'Ajustes de cuadrícula de series';

  @override
  String get seriesGridSeriesPerRow => 'Series por fila:';

  @override
  String get channelGridSettingsTitle => 'Cuadrícula de canales';

  @override
  String get channelGridHeroBannerSize => 'Tamaño del banner principal:';

  @override
  String get channelGridChannelsPerRowLabel => 'Canales por fila:';

  @override
  String get channelGridChannelDisplay => 'Visualización del canal:';

  @override
  String get channelGridChNamePosition => 'Posición del nombre:';

  @override
  String get channelGridShowSettingsPanel => 'Mostrar ajustes';

  @override
  String get cardStylePosterTitle => 'Póster+nombre+año';

  @override
  String get cardStylePosterOnly => 'Solo póster';

  @override
  String get cardStyleNamePoster => 'Nombre+póster';

  @override
  String get cardStyleTitleOnly => 'Solo título';

  @override
  String get catalogLoading => 'Cargando…';

  @override
  String get catalogLoadingChannels => 'Cargando canales…';

  @override
  String get catalogLoadingLibrary => 'Cargando biblioteca…';

  @override
  String get catalogPreparing => 'Preparando…';

  @override
  String get catalogErrorPlaylist => 'No se pudo cargar la lista';

  @override
  String get catalogErrorLibrary => 'No se pudo cargar la biblioteca';

  @override
  String get catalogNoCategories => 'Sin categorías';

  @override
  String get catalogNoCategoriesSubtitle =>
      'Esta lista no devolvió categorías en vivo.';

  @override
  String get myPlaylistsTitle => 'Mis listas';

  @override
  String get myPlaylistsSubtitle => 'Solo una lista activa a la vez.';

  @override
  String get myPlaylistsEmpty => 'Aún no hay listas. Añade una en Ajustes.';

  @override
  String get dialogRenamePlaylist => 'Renombrar lista';

  @override
  String get dialogEditPlaylist => 'Editar lista';

  @override
  String get dialogPlaylistServerUrl => 'URL del servidor';

  @override
  String get dialogPlaylistUsername => 'Usuario';

  @override
  String get dialogPlaylistPassword => 'Contraseña';

  @override
  String get dialogPlaylistM3uUrl => 'URL M3U';

  @override
  String get dialogPlaylistEditInvalid =>
      'Complete todos los campos obligatorios.';

  @override
  String get dialogPlaylistNameHint => 'Nombre';

  @override
  String get dialogCancel => 'Cancelar';

  @override
  String get dialogSave => 'Guardar';

  @override
  String get dialogDelete => 'Eliminar';

  @override
  String get dialogDeletePlaylistTitle => '¿Eliminar lista?';

  @override
  String dialogDeletePlaylistBody(String name) {
    return '«$name» se eliminará de este dispositivo.';
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
  String get playlistActiveBadge => 'ACTIVA';

  @override
  String get playlistSubscriptionActive => 'Activa';

  @override
  String get playlistSubscriptionExpired => 'Caducada';

  @override
  String playlistExpireOn(String date) {
    return 'Vence el $date';
  }

  @override
  String get playlistChipGroups => 'Grupos';

  @override
  String get playlistChipManageChannels => 'Gestionar canales';

  @override
  String get manageLiveChannelsTitle => 'Gestionar canales';

  @override
  String get manageLiveChannelsSubtitle =>
      'Elige una categoría y cambia nombres, visibilidad en TV en vivo o logo.';

  @override
  String get manageLiveChannelsNeedActive => 'Activa esta lista primero.';

  @override
  String get manageLiveChannelsNoCategories =>
      'Sin categorías en vivo. Sincroniza la lista.';

  @override
  String get manageLiveChannelsCategoryEmpty =>
      'No hay canales en esta categoría.';

  @override
  String get channelOverrideNameAction => 'Nombre';

  @override
  String get channelOverrideLogoAction => 'Logo';

  @override
  String get channelOverrideHiddenFromLive => 'Oculto en TV en vivo';

  @override
  String get channelOverrideVisibleInLive => 'Visible en TV en vivo';

  @override
  String get channelOverrideDisplayNameDialogTitle => 'Nombre mostrado';

  @override
  String get channelOverrideDisplayNameHint => 'Vacío = nombre del servidor.';

  @override
  String get channelOverrideLogoDialogTitle => 'URL del logo';

  @override
  String get channelOverrideLogoDialogHint =>
      'Pega un enlace https:// a PNG o JPG. Vacío = logo de la lista.';

  @override
  String get playlistGroupEdit => 'Editar';

  @override
  String playlistGroupOriginalLabel(String name) {
    return 'Original: $name';
  }

  @override
  String get playlistGroupCustomNameHint => 'Nombre personalizado';

  @override
  String get playlistGroupResetAlias => 'Restablecer';

  @override
  String get playlistGroupPillOrderTitle => 'Orden de pastillas (TV en vivo)';

  @override
  String get playlistGroupPillAfterFavorites => 'Después de mis favoritos';

  @override
  String get playlistGroupPillBeforeFavorites => 'Antes de mis favoritos';

  @override
  String get playlistGroupPillPositionLabel => 'Posición (1 = la primera)';

  @override
  String get playlistGroupPillPositionHint => '1';

  @override
  String get playlistEpgLocal => 'EPG: local';

  @override
  String get playlistEpgOriginal => 'EPG: original';

  @override
  String get playlistEpgTimeScreenTitle => 'Hora EPG';

  @override
  String get playlistEpgTimeScreenHint =>
      'Elige cómo se muestran las horas de los programas para esta lista.';

  @override
  String get playlistEpgTimeRowLocal => 'Local';

  @override
  String get playlistEpgTimeRowLocalSubtitle => 'Zona horaria del dispositivo';

  @override
  String get playlistEpgTimeRowOriginal => 'Original (servidor)';

  @override
  String get playlistEpgTimeRowOriginalSubtitle =>
      'Horas tal como las envía el proveedor';

  @override
  String playlistEpgZoneChip(String zone) {
    return 'EPG: $zone';
  }

  @override
  String get playlistChipUse => 'Usar';

  @override
  String get playlistChipOn => 'Sí';

  @override
  String get playlistChipRename => 'Ren';

  @override
  String get playlistChipDelete => 'Supr';

  @override
  String get favSetupInfoBanner =>
      'Crea tus propias categorías de TV en vivo. Añade un favor nuevo, pon nombre y orden (los números bajos van primero) y luego Elige canales — la primera elección es la posición 1, la segunda la 2, etc. Abre una tarjeta para editar o borrar. Tus favoritos aparecen en TV en vivo como pastillas junto a tu lista, aunque ocultes grupos de la lista.';

  @override
  String get favNewFavorite => 'Nuevo favorito';

  @override
  String get favCreateGroup => 'Crear grupo';

  @override
  String favGroupSubtitle(int count, int order) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales',
      one: '1 canal',
    );
    return '$_temp0 · orden $order';
  }

  @override
  String get favEditNew => 'Nuevo favorito';

  @override
  String get favEditEdit => 'Editar favorito';

  @override
  String get favEditNameLabel => 'Nombre';

  @override
  String get favEditNameHint => 'Se muestra en TV en vivo como categoría';

  @override
  String get favEditOrderLabel => 'Orden';

  @override
  String get favEditOrderHint => 'Más bajo = primero entre favoritos';

  @override
  String get favEditChooseChannels => 'Elegir canales';

  @override
  String selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get favEditOrderHelp =>
      'Orden: primer toque = 1, segundo = 2… Usa Todo en categoría / Vaciar categoría en el selector.';

  @override
  String get favEditChannelsHeading => 'Canales en este favorito';

  @override
  String get favEditNoChannels => 'Aún no hay canales.\nPulsa Elegir canales.';

  @override
  String get favEditSave => 'Guardar';

  @override
  String get favEditDelete => 'Eliminar';

  @override
  String get defaultFavoriteName => 'Favorito';

  @override
  String get favPickNoXtream => 'Sin lista Xtream';

  @override
  String get favPickNoXtreamSubtitle =>
      'Añade una lista Xtream Codes en Mis listas para elegir canales de cualquier panel guardado.';

  @override
  String get favPickHelpWithPlaylist =>
      'Lista → categoría → cuadrícula. Guardar abajo. Atrás → Guardar.';

  @override
  String get favPickHelpOrderBadges =>
      'Elecciones arriba (1,2,3…). Atrás → Guardar.';

  @override
  String get favPickHelpSimple => 'Elecciones arriba. Atrás → Guardar.';

  @override
  String get favPickInFavorite => 'En este favorito';

  @override
  String get favPickNoChannelsDraft =>
      'Aún no hay canales — elige en la cuadrícula.';

  @override
  String get favPickChannelUnavailable => 'Canal no disponible';

  @override
  String get favPickAddMore => 'Añadir más';

  @override
  String get favPickNoChannelsCategory => 'No hay canales en esta categoría.';

  @override
  String get favPickAllInCategory => 'Todo en categoría';

  @override
  String get favPickClearCategory => 'Vaciar categoría';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get backupInfoBanner =>
      'Personal incluye contraseñas (manténlo privado). Compartir quita contraseñas (seguro para enviar).';

  @override
  String get backupExportPersonal => 'Exportar personal';

  @override
  String get backupExportPersonalSub => 'Copia completa con contraseñas';

  @override
  String get backupExportShare => 'Exportar para compartir';

  @override
  String get backupExportShareSub => 'Contraseñas eliminadas';

  @override
  String get backupShareLastExport => 'Compartir última exportación';

  @override
  String get backupShareLastExportSub =>
      'Enviar el archivo que acabas de guardar';

  @override
  String get backupShareLatest => 'Compartir la última';

  @override
  String get backupShareLatestSub => 'Correo, Drive, etc.';

  @override
  String get backupImportNavigate => 'Importar copia';

  @override
  String get backupImportNavigateSub => 'Restaurar desde archivo';

  @override
  String get backupDeleteNavigate => 'Eliminar copias';

  @override
  String get backupDeleteNavigateSub => 'Quitar archivos antiguos';

  @override
  String get backupToastStorageRequired =>
      'Se necesita permiso de almacenamiento para guardar copias.';

  @override
  String backupToastSavedDownloads(String name) {
    return 'Guardado en Descargas: $name';
  }

  @override
  String backupToastExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get backupShareSubject => 'Copia TVMate Pro';

  @override
  String get backupShareBody => 'Copia de ajustes TVMate Pro';

  @override
  String get backupToastNoBackupsToShare =>
      'No hay archivos de copia. Exporta primero.';

  @override
  String backupToastShareFailed(String error) {
    return 'Error al compartir: $error';
  }

  @override
  String get backupImportRestoredToast =>
      'Copia restaurada. Actualizando catálogos.';

  @override
  String get nsMessageBackupAppliedTitle => 'Copia aplicada';

  @override
  String get nsMessageErrorTitle => 'Algo salió mal';

  @override
  String get nsMessageDismiss => 'Cerrar';

  @override
  String backupImportFailedToast(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get backupImportTitle => 'Importar copia';

  @override
  String get backupImportScanSubtitle =>
      'Buscando en Descargas archivos tvmate-backup';

  @override
  String get backupImportRefresh => 'Actualizar';

  @override
  String get backupImportRestoring => 'Restaurando copia…';

  @override
  String get backupImportEmpty => 'No hay archivos de copia en Descargas.';

  @override
  String get backupManageTitle => 'Eliminar copias';

  @override
  String get backupManageSelectAll => 'Seleccionar todo';

  @override
  String get backupManageClearAll => 'Limpiar selección';

  @override
  String get backupManageDelete => 'Eliminar';

  @override
  String backupManageDeleteCount(int count) {
    return 'Eliminar ($count)';
  }

  @override
  String get backupManageDeleteConfirmTitle => '¿Eliminar copias?';

  @override
  String backupManageDeleteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminarán $count archivos de Descargas.',
      one: 'Se eliminará 1 archivo de Descargas.',
    );
    return '$_temp0';
  }

  @override
  String get backupManageToastRemoved => 'Copias seleccionadas eliminadas.';

  @override
  String get backupManageEmpty => 'No hay archivos de copia.';

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
      'Fondo de subtítulos:';

  @override
  String get subtitleAppearanceLabelTransparency => 'Transparencia:';

  @override
  String get subtitleAppearancePreviewLine => 'Así se verán los subtítulos';

  @override
  String get subtitleAppearanceVodPanelTitle => 'Editar subtítulos';

  @override
  String get subtitleAppearancePositionShort => 'Posición';

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
  String get parentalUnlocked => 'Desbloqueado.';

  @override
  String get parentalUnlockThisChannel => 'Desbloquear este canal';

  @override
  String get parentalUnlockCategoryOrGroup =>
      'Desbloquear esta categoría o grupo';

  @override
  String get parentalUnlockThisMovie => 'Desbloquear esta película';

  @override
  String get parentalUnlockMovieCategory =>
      'Desbloquear esta categoría de películas';

  @override
  String get parentalUnlockThisShow => 'Desbloquear esta serie';

  @override
  String get parentalUnlockSeriesCategory =>
      'Desbloquear esta categoría de series';

  @override
  String get parentalPlayerParental => 'Parental';

  @override
  String get playerEpgPanelLabel => 'EPG';

  @override
  String get playerRightPanelQuality => 'Calidad';

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
  String get playerEpgOverlayTitle => 'Guía del canal';

  @override
  String get playerEpgOverlaySchedule => 'Próximos';

  @override
  String get playerEpgOverlayLoading => 'Cargando guía de programación…';

  @override
  String get playerEpgOverlayEmpty =>
      'No hay información de programas para este canal.';

  @override
  String get playerEpgNowBadge => 'AHORA';

  @override
  String get playerEpgLiveRightNow => 'En vivo ahora';

  @override
  String get playerEpgDayToday => 'Hoy';

  @override
  String get playerEpgDayTomorrow => 'Mañana';

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
