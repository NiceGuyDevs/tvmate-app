import 'package:flutter/material.dart';

import '../../data/device_memory_channel.dart';
import '../../data/tv_keyboard_language_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'parental_panel_shell.dart';

// Gboard-on-TV style (light keys, dark labels, blue enter).
const Color _kKeyBg = Color(0xFFE8E8E8);
const Color _kKeyBgFocused = Color(0xFFFAFAFA);
const Color _kKeyText = Color(0xFF212121);
const Color _kKeyBorder = Color(0xFFBDBDBD);
const Color _kAltLabel = Color(0xFF757575);
const Color _kPanelBg = Color(0xCC2C2C2C);
const Color _kEnter = Color(0xFF64B5F6);
const Color _kEnterBorder = Color(0xFF42A5F5);
const Color _kShiftOn = Color(0xFFD0D0D0);

/// On-screen character entry for Android TV / Chromecast when the system IME
/// is unreliable — styled like Google TV Gboard.
Future<void> showTvRemoteCharPad(
  BuildContext context, {
  required TextEditingController controller,
  required String fieldLabel,
  bool obscure = false,
}) async {
  if (DeviceMemoryChannel.useInAppTextPadOnly) {
    await DeviceMemoryChannel.prepareForTextInput();
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _TvRemoteCharPadDialog(
      controller: controller,
      fieldLabel: fieldLabel,
      obscure: obscure,
    ),
  );
}

enum _KbdLang { english, hebrew, arabic }

class _TvRemoteCharPadDialog extends StatefulWidget {
  const _TvRemoteCharPadDialog({
    required this.controller,
    required this.fieldLabel,
    required this.obscure,
  });

  final TextEditingController controller;
  final String fieldLabel;
  final bool obscure;

  @override
  State<_TvRemoteCharPadDialog> createState() => _TvRemoteCharPadDialogState();
}

class _TvRemoteCharPadDialogState extends State<_TvRemoteCharPadDialog> {
  var _caps = false;
  var _symbolMode = false;
  var _lang = _KbdLang.english;
  var _langMenuOpen = false;

  /// Ordered `en` / `he` / `ar` ids — same list for top chip + globe (persisted).
  var _kbdOrderIds = List<String>.from(TvKeyboardLanguageStore.defaultOrder);

  static const _rowQwerty = [
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',
  ];
  static const _rowAsdf = [
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ',',
  ];
  static const _rowZxcv = ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.'];

  static const _he1 = ['ק', 'ר', 'א', 'ט', 'ו', 'ן', 'ם', 'פ'];
  static const _he2 = ['ש', 'ד', 'ג', 'כ', 'ע', 'י', 'ח', 'ל', 'ך', 'ף'];
  static const _he3 = ['ז', 'ס', 'ב', 'ה', 'נ', 'מ', 'צ', 'ת', 'ץ'];

  static const _ar1 = ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'];
  static const _ar2 = ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'];
  static const _ar3 = ['ئ', 'ء', 'ؤ', 'ر', 'ى', 'ة', 'و', 'ز', 'ظ', 'ذ', 'د'];

  static const _sym1 = [
    '!', '@', '#', r'$', '%', '^', '&', '*', '(', ')',
  ];
  static const _sym2 = [
    '-', '_', '=', '+', '[', ']', '{', '}', ':', ';',
  ];
  static const _sym3 = [
    '\'', '"', '<', '>', '/', '?', '\\', '|', '~', '`',
  ];

  static const List<(String, String)> _numAlts = [
    ('1', '!'),
    ('2', '@'),
    ('3', '#'),
    ('4', r'$'),
    ('5', '%'),
    ('6', '^'),
    ('7', '&'),
    ('8', '*'),
    ('9', '('),
    ('0', ')'),
  ];

  /// Compact footprint: ~40% width like Google TV keyboard (reference).
  double _scaleForWidth(double screenW) {
    final target = (screenW * 0.40).clamp(280.0, 480.0);
    return target / 760.0;
  }

  static const _digitKeyW = 46.0;
  static const _letterKeyW = 44.0;

  /// Widest key row inside the gray panel — drives a flush side frame (no extra outer bands).
  double _intrinsicKbdBodyWidth(double s) {
    final g = 3.5 * s;
    if (_lang == _KbdLang.arabic) {
      return 11 * _letterKeyW * s + 10 * g;
    }
    // English / Hebrew: number row (46×10) is wider than 10× letter rows.
    return 10 * _digitKeyW * s + 9 * g;
  }

  void _setLang(_KbdLang l) {
    setState(() {
      _lang = l;
      _langMenuOpen = false;
      _caps = false;
      _symbolMode = false;
    });
  }

  String _langLabel(_KbdLang l) {
    switch (l) {
      case _KbdLang.english:
        return 'English';
      case _KbdLang.hebrew:
        return 'עברית';
      case _KbdLang.arabic:
        return 'العربية';
    }
  }

  void _toggleLangMenu() {
    setState(() => _langMenuOpen = !_langMenuOpen);
  }

  @override
  void initState() {
    super.initState();
    _loadKbdOrder();
  }

  Future<void> _loadKbdOrder() async {
    final list = await TvKeyboardLanguageStore.loadOrderedIds();
    if (!mounted) return;
    setState(() {
      _kbdOrderIds = list;
      final id = _langToId(_lang);
      if (!_kbdOrderIds.contains(id)) {
        final f = _langFromId(_kbdOrderIds.first);
        if (f != null) {
          _lang = f;
          _caps = false;
          _symbolMode = false;
        }
      }
    });
  }

  String _langToId(_KbdLang l) {
    switch (l) {
      case _KbdLang.english:
        return 'en';
      case _KbdLang.hebrew:
        return 'he';
      case _KbdLang.arabic:
        return 'ar';
    }
  }

  _KbdLang? _langFromId(String id) {
    switch (id) {
      case 'en':
        return _KbdLang.english;
      case 'he':
        return _KbdLang.hebrew;
      case 'ar':
        return _KbdLang.arabic;
      default:
        return null;
    }
  }

  String _catalogLanguageLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'en':
        return l10n.languageEnglish;
      case 'he':
        return l10n.languageHebrew;
      case 'ar':
        return l10n.languageArabic;
      case 'fr':
        return l10n.languageFrench;
      case 'es':
        return l10n.languageSpanish;
      case 'ru':
        return l10n.languageRussian;
      case 'de':
        return l10n.languageGerman;
      case 'pt':
        return l10n.languagePortuguese;
      case 'it':
        return l10n.languageItalian;
      case 'tr':
        return l10n.languageTurkish;
      case 'hi':
        return l10n.languageHindi;
      case 'ja':
        return l10n.languageJapanese;
      case 'ko':
        return l10n.languageKorean;
      case 'zh':
        return l10n.languageChinese;
      case 'vi':
        return l10n.languageVietnamese;
      default:
        return id;
    }
  }

  Future<void> _showLanguageCatalog() async {
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.sizeOf(context);
    final s = _scaleForWidth(mq.width);
    // Keyboard layouts: en, he, ar. Rest: common global languages (layout TBD in UI).
    const catalogAll = [
      'en', 'he', 'ar',
      'fr', 'es',
      'ru', 'de', 'pt', 'it', 'tr', 'hi', 'ja', 'ko', 'zh', 'vi',
    ];

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        final order = List<String>.from(_kbdOrderIds);
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              backgroundColor: const Color(0xEE242424),
              insetPadding: EdgeInsets.symmetric(
                horizontal: (mq.width * 0.06).clamp(16.0, 48.0),
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (mq.width * 0.88).clamp(280.0, 520.0),
                  maxHeight: mq.height * 0.72,
                ),
                child: Padding(
                  padding: EdgeInsets.all(14 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tvKeyboardLanguagesTitle,
                        style: TextStyle(
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      Text(
                        l10n.tvKeyboardPickLanguagesSubtitle,
                        style: TextStyle(
                          fontSize: 11 * s,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      SizedBox(height: 10 * s),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: mq.height * 0.54,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < catalogAll.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                _catalogLanguageRow(
                                  id: catalogAll[i],
                                  supported: TvKeyboardLanguageStore
                                      .keyboardLocaleIds
                                      .contains(catalogAll[i]),
                                  order: order,
                                  setLocal: setLocal,
                                  s: s,
                                  l10n: l10n,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TvFocusable(
                            onActivate: () =>
                                Navigator.of(dialogContext).pop(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * s,
                                vertical: 8 * s,
                              ),
                              child: Text(
                                l10n.commonCancel,
                                style: TextStyle(
                                  fontSize: 13 * s,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          TvFocusable(
                            onActivate: () async {
                              await TvKeyboardLanguageStore.saveOrderedIds(
                                order,
                              );
                              if (!mounted) return;
                              setState(() {
                                _kbdOrderIds = List<String>.from(order);
                                final cur = _langToId(_lang);
                                if (!_kbdOrderIds.contains(cur)) {
                                  final f = _langFromId(_kbdOrderIds.first);
                                  if (f != null) _lang = f;
                                  _caps = false;
                                  _symbolMode = false;
                                }
                              });
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * s,
                                vertical: 8 * s,
                              ),
                              child: Text(
                                l10n.tvRemoteTypingDone,
                                style: TextStyle(
                                  fontSize: 13 * s,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFD54F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _catalogLanguageRow({
    required String id,
    required bool supported,
    required List<String> order,
    required StateSetter setLocal,
    required double s,
    required AppLocalizations l10n,
  }) {
    final checked = order.contains(id);
    return TvFocusable(
      onActivate: () {
        if (!supported) return;
        setLocal(() {
          if (checked) {
            if (order.length > 1) order.remove(id);
          } else {
            order.add(id);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * s, horizontal: 4 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              supported
                  ? (checked
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : Icons.check_box_outline_blank_rounded,
              size: 22 * s,
              color: supported
                  ? Colors.white.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.28),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _catalogLanguageLabel(l10n, id),
                    style: TextStyle(
                      fontSize: 13.5 * s,
                      fontWeight: FontWeight.w600,
                      color: supported
                          ? Colors.white.withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  if (!supported) ...[
                    SizedBox(height: 3 * s),
                    Text(
                      l10n.tvKeyboardLayoutNotAvailable,
                      style: TextStyle(
                        fontSize: 10.5 * s,
                        height: 1.25,
                        color: Colors.white.withValues(alpha: 0.38),
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

  /// Small control next to the language chip — opens full list + marks (order = add order).
  Widget _languagesPickerIcon(double s) {
    return TvFocusable(
      onActivate: _showLanguageCatalog,
      child: Padding(
        padding: EdgeInsets.all(2 * s),
        child: Icon(
          Icons.translate_rounded,
          size: 18 * s,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  /// Single-line preview + field hint when empty (no extra title block).
  Widget _previewStrip(ThemeData theme, double s) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final t = widget.controller.text;
        final show = widget.obscure
            ? (t.isEmpty ? '' : ''.padLeft(t.length, '•'))
            : t;
        final empty = show.isEmpty;
        return parentalPanelInsetBlock(
          compact: true,
          child: Text(
            empty ? widget.fieldLabel : show,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: _lang == _KbdLang.english
                ? TextDirection.ltr
                : TextDirection.rtl,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5 * s,
              color: empty
                  ? Colors.white.withValues(alpha: 0.48)
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final shell = context.teamPalette;
    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );
    final mq = MediaQuery.sizeOf(context);
    final s = _scaleForWidth(mq.width);
    final pad = 10 * s;
    const outerR = 12.0;
    final maxW = (mq.width * 0.38).clamp(268.0, 440.0);
    final kbdMaxH = (mq.height * 0.52).clamp(260.0, 560.0);

    final bodyW = _intrinsicKbdBodyWidth(s);
    final kbdPanelPadH = 2.2 * s;
    final outerPadH = pad * 0.45;
    // Card width = key grid + gray panel padding + outer horizontal insets (flush to red lines).
    final cardIntrinsicW = bodyW + 2 * kbdPanelPadH + 2 * outerPadH;
    final frameW = cardIntrinsicW.clamp(0.0, maxW);

    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(10, 36, 10, 8),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: frameW,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerR),
            color: const Color(0xEE242424),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(outerR),
            child: Padding(
              padding: EdgeInsets.fromLTRB(outerPadH, 5 * s, outerPadH, 4 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _previewStrip(theme, s)),
                      SizedBox(width: 4 * s),
                      _langChipButton(s),
                      SizedBox(width: 3 * s),
                      _languagesPickerIcon(s),
                    ],
                  ),
                  if (_langMenuOpen) ...[
                    SizedBox(height: 4 * s),
                    parentalPanelInsetBlock(
                      compact: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _kbdOrderIds.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            _langRow(_langFromId(_kbdOrderIds[i])!, s),
                          ],
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 4 * s),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        kbdPanelPadH,
                        3 * s,
                        kbdPanelPadH,
                        3 * s,
                      ),
                      decoration: BoxDecoration(
                        color: _kPanelBg,
                        borderRadius: BorderRadius.circular(7 * s),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: kbdMaxH),
                        child: ListView(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            _symbolMode
                                ? _buildSymbolPad(s)
                                : _buildLangPad(s),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  TvFocusable(
                    onActivate: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * s,
                        vertical: 5 * s,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7 * s),
                        color: shell.accent.withValues(alpha: 0.2),
                        border: Border.all(
                          color: shell.accent.withValues(alpha: 0.45),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.tvRemoteTypingDone,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 11 * s,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header: opens same list as globe — dropdown style.
  Widget _langChipButton(double s) {
    return TvFocusable(
      onActivate: _toggleLangMenu,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 5 * s),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8 * s),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _langLabel(_lang),
              style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            SizedBox(width: 3 * s),
            Icon(
              _langMenuOpen
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
              size: 18 * s,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langRow(_KbdLang lang, double s) {
    final selected = _lang == lang;
    return TvFocusable(
      onActivate: () => _setLang(lang),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * s, horizontal: 4 * s),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _langLabel(lang),
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFFFFD54F)
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: 18 * s,
                color: const Color(0xFFFFD54F),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangPad(double s) {
    switch (_lang) {
      case _KbdLang.english:
        return _buildQwertyPad(s);
      case _KbdLang.hebrew:
        return _buildHebrewPad(s);
      case _KbdLang.arabic:
        return _buildArabicPad(s);
    }
  }

  Widget _buildQwertyPad(double s) {
    final g = 3.2 * s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _numRowGboard(s),
        SizedBox(height: g),
        _keyRowChars(_rowQwerty, s),
        SizedBox(height: g),
        _asdfRowEnglish(s),
        SizedBox(height: g),
        _rowShiftAndZxcv(s),
        SizedBox(height: g),
        _bottomRow(s),
      ],
    );
  }

  Widget _buildHebrewPad(double s) {
    final g = 3.2 * s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _numRowGboard(s),
        SizedBox(height: g),
        _keyRowChars(_he1, s, heAr: true),
        SizedBox(height: g),
        _keyRowChars(_he2, s, heAr: true),
        SizedBox(height: g),
        _keyRowChars(_he3, s, heAr: true),
        SizedBox(height: g),
        _bottomRow(s),
      ],
    );
  }

  Widget _buildArabicPad(double s) {
    final g = 3.2 * s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _numRowGboard(s),
        SizedBox(height: g),
        _keyRowChars(_ar1, s, heAr: true),
        SizedBox(height: g),
        _keyRowChars(_ar2, s, heAr: true),
        SizedBox(height: g),
        _keyRowChars(_ar3, s, heAr: true),
        SizedBox(height: g),
        _bottomRow(s),
      ],
    );
  }

  Widget _buildSymbolPad(double s) {
    final g = 3.2 * s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _numRowGboard(s),
        SizedBox(height: g),
        _keyRowChars(_sym1, s),
        SizedBox(height: g),
        _keyRowChars(_sym2, s),
        SizedBox(height: g),
        _keyRowChars(_sym3, s),
        SizedBox(height: 5 * s),
        Align(
          alignment: Alignment.centerLeft,
          child: _wideTextKey(
            'ABC',
            s,
            onActivate: () => setState(() => _symbolMode = false),
            minWidth: 64,
          ),
        ),
      ],
    );
  }

  Widget _numRowGboard(double s) {
    final gap = 3.5 * s;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _numAlts.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _digitKey(_numAlts[i].$1, _numAlts[i].$2, s),
        ],
      ],
    );
  }

  Widget _digitKey(String digit, String alt, double s) {
    final kr = 5 * s;
    final kw = 46 * s;
    final kh = 38 * s;
    return SizedBox(
      width: kw,
      height: kh,
      child: _GboardTvKey(
        s: s,
        borderRadius: kr,
        onActivate: () => _append(digit),
        child: Stack(
          children: [
            Center(
              child: Text(
                digit,
                style: TextStyle(
                  color: _kKeyText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15 * s,
                ),
              ),
            ),
            Positioned(
              right: 5 * s,
              top: 4 * s,
              child: Text(
                alt,
                style: TextStyle(
                  color: _kAltLabel,
                  fontSize: 9.5 * s,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Same inset + total width as [_rowShiftAndZxcv]: `a` aligns with shift, comma with backspace.
  Widget _asdfRowEnglish(double s) {
    final gap = 3.5 * s;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(left: 16 * s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _rowAsdf.length; i++) ...[
              _charKey(_rowAsdf[i], s),
              if (i < _rowAsdf.length - 1) SizedBox(width: gap),
            ],
          ],
        ),
      ),
    );
  }

  /// Shift under `a`, backspace under comma — fixed row width (no Expanded / side gutters).
  Widget _rowShiftAndZxcv(double s) {
    final gap = 3.5 * s;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(left: 16 * s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _iconKey(
              s,
              _caps ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              () => setState(() => _caps = !_caps),
              minWidth: 44,
              filled: _caps,
            ),
            SizedBox(width: gap),
            for (var i = 0; i < _rowZxcv.length; i++) ...[
              _charKey(_rowZxcv[i], s),
              if (i < _rowZxcv.length - 1) SizedBox(width: gap),
            ],
            SizedBox(width: gap),
            _iconKey(s, Icons.backspace_outlined, _backspace, minWidth: 44),
          ],
        ),
      ),
    );
  }

  Widget _bottomRow(double s) {
    final gap = 3.5 * s;
    // Fixed width (~2 letter keys): was Expanded and ate the row — caused wide empty bands.
    final spaceW = 88 * s;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _wideTextKey(
            '?123',
            s,
            onActivate: () => setState(() => _symbolMode = true),
            minWidth: 52,
          ),
          SizedBox(width: gap),
          _iconKey(s, Icons.keyboard_arrow_left, _cursorLeft, minWidth: 40),
          SizedBox(width: gap),
          _iconKey(s, Icons.keyboard_arrow_right, _cursorRight, minWidth: 40),
          SizedBox(width: gap),
          _globeKey(s),
          SizedBox(width: gap),
          SizedBox(
            width: spaceW,
            height: 38 * s,
            child: _spaceKey(s),
          ),
          SizedBox(width: gap),
          _charKey('-', s, narrow: true),
          SizedBox(width: gap),
          _charKey('_', s, narrow: true),
          SizedBox(width: gap),
          _enterKey(s),
        ],
      ),
    );
  }

  Widget _globeKey(double s) {
    return SizedBox(
      width: 42 * s,
      height: 38 * s,
      child: _GboardTvKey(
        s: s,
        borderRadius: 5 * s,
        onActivate: _toggleLangMenu,
        child: Icon(
          Icons.language_rounded,
          size: 20 * s,
          color: _kKeyText,
        ),
      ),
    );
  }

  Widget _keyRowChars(List<String> chars, double s, {bool heAr = false}) {
    final gap = 3.5 * s;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < chars.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _charKey(chars[i], s, narrow: false, heAr: heAr),
        ],
      ],
    );
  }

  Widget _charKey(
    String c,
    double s, {
    bool narrow = false,
    bool heAr = false,
  }) {
    final display = _displayChar(c);
    final kw = narrow ? 36 * s : 44 * s;
    final kh = 38 * s;
    return SizedBox(
      width: kw,
      height: kh,
      child: _GboardTvKey(
        s: s,
        borderRadius: 5 * s,
        onActivate: () => _append(c),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              color: _kKeyText,
              fontWeight: FontWeight.w600,
              fontSize: heAr ? 14.5 * s : 14 * s,
            ),
          ),
        ),
      ),
    );
  }

  String _displayChar(String c) {
    if (c.length != 1) return c;
    if (_lang == _KbdLang.english &&
        RegExp(r'[a-z]').hasMatch(c) &&
        _caps) {
      return c.toUpperCase();
    }
    return c;
  }

  Widget _iconKey(
    double s,
    IconData icon,
    VoidCallback onTap, {
    required double minWidth,
    bool filled = false,
  }) {
    return SizedBox(
      width: minWidth * s,
      height: 38 * s,
      child: _GboardTvKey(
        s: s,
        borderRadius: 5 * s,
        onActivate: onTap,
        fill: filled ? _kShiftOn : null,
        child: Icon(icon, size: 19 * s, color: _kKeyText),
      ),
    );
  }

  Widget _spaceKey(double s) {
    return SizedBox(
      height: 38 * s,
      child: _GboardTvKey(
        s: s,
        borderRadius: 5 * s,
        onActivate: () => _append(' '),
        child: Icon(
          Icons.space_bar_rounded,
          color: _kKeyText.withValues(alpha: 0.85),
          size: 20 * s,
        ),
      ),
    );
  }

  Widget _enterKey(double s) {
    return SizedBox(
      width: 50 * s,
      height: 38 * s,
      child: TvFocusable(
        onActivate: () => Navigator.of(context).pop(),
        showFocusElevation: false,
        focusedBorderWidth: 0,
        focusPadding: EdgeInsets.all(1.5 * s),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _kEnter,
              borderRadius: BorderRadius.circular(5 * s),
              border: Border.all(color: _kEnterBorder),
            ),
            child: Icon(
              Icons.keyboard_return_rounded,
              color: Colors.white,
              size: 20 * s,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideTextKey(
    String label,
    double s, {
    required VoidCallback onActivate,
    required double minWidth,
    bool filled = false,
  }) {
    return SizedBox(
      height: 38 * s,
      width: minWidth * s,
      child: _GboardTvKey(
        s: s,
        borderRadius: 5 * s,
        onActivate: onActivate,
        fill: filled ? _kShiftOn : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _kKeyText,
              fontWeight: FontWeight.w700,
              fontSize: 11 * s,
            ),
          ),
        ),
      ),
    );
  }

  void _append(String c) {
    final v = widget.controller;
    final t = v.text;
    final sel = v.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;

    String ch;
    if (_lang == _KbdLang.english &&
        c.length == 1 &&
        RegExp(r'[a-zA-Z]').hasMatch(c)) {
      final base = c.toLowerCase();
      ch = _caps ? base.toUpperCase() : base;
    } else {
      ch = c;
    }

    final newText = t.replaceRange(start, end, ch);
    final newOffset = start + ch.length;
    v.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _backspace() {
    final v = widget.controller;
    final t = v.text;
    final sel = v.selection;
    if (sel.isValid && sel.start != sel.end) {
      final newText = t.replaceRange(sel.start, sel.end, '');
      v.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    final o = sel.isValid ? sel.start : t.length;
    if (o <= 0) return;
    final newText = t.replaceRange(o - 1, o, '');
    v.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: o - 1),
    );
  }

  void _cursorLeft() {
    final v = widget.controller;
    final t = v.text;
    final sel = v.selection;
    final o = sel.isValid ? sel.baseOffset : t.length;
    if (o <= 0) return;
    v.selection = TextSelection.collapsed(offset: o - 1);
  }

  void _cursorRight() {
    final v = widget.controller;
    final t = v.text;
    final sel = v.selection;
    final o = sel.isValid ? sel.baseOffset : t.length;
    if (o >= t.length) return;
    v.selection = TextSelection.collapsed(offset: o + 1);
  }
}

/// One key: [TvFocusable] + Gboard-like fill; white highlight when focused.
class _GboardTvKey extends StatefulWidget {
  const _GboardTvKey({
    required this.s,
    required this.borderRadius,
    required this.onActivate,
    required this.child,
    this.fill,
  });

  final double s;
  final double borderRadius;
  final VoidCallback onActivate;
  final Widget child;
  final Color? fill;

  @override
  State<_GboardTvKey> createState() => _GboardTvKeyState();
}

class _GboardTvKeyState extends State<_GboardTvKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = _focused
        ? _kKeyBgFocused
        : (widget.fill ?? _kKeyBg);
    return TvFocusable(
      onActivate: widget.onActivate,
      showFocusElevation: false,
      focusedBorderWidth: 0,
      focusPadding: EdgeInsets.all(1.5 * widget.s),
      onFocusedChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _focused
                ? Colors.white.withValues(alpha: 0.88)
                : _kKeyBorder,
            width: _focused ? 1.75 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
