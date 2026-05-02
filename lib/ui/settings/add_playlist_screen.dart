import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/device_memory_channel.dart';
import '../../data/playlist_type.dart';
import '../../data/stored_playlist.dart';
import '../../shell/shell_destination.dart';
import '../../shell/shell_navigation_hub.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart'
    show TvFocusable, scheduleSteadyChannelTileFocus;
import 'player_settings_overlay_scope.dart';
import 'playlist_loading_screen.dart';
import 'shield_tv_text_field.dart';
import 'tv_remote_keys.dart';

class AddPlaylistScreen extends StatefulWidget {
  const AddPlaylistScreen({super.key});

  @override
  State<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends State<AddPlaylistScreen>
    with WidgetsBindingObserver {
  PlaylistType? _type;

  final _xtName = TextEditingController();
  final _xtUser = TextEditingController();
  final _xtPass = TextEditingController();
  final _xtServer = TextEditingController();

  final _m3uName = TextEditingController();
  final _m3uUrl = TextEditingController();

  /// NVIDIA Shield / TV explicit chain (Back + fields + Add).
  late final FocusNode backFocusNode = FocusNode(debugLabel: 'add_back');
  late final FocusNode addButtonFocusNode = FocusNode(debugLabel: 'add_submit');
  late final FocusNode serverFocusNode = FocusNode(debugLabel: 'xt_server');
  late final FocusNode usernameFocusNode = FocusNode(debugLabel: 'xt_user');
  late final FocusNode passwordFocusNode = FocusNode(debugLabel: 'xt_pass');
  late final FocusNode nameFocusNode = FocusNode(debugLabel: 'xt_name');
  late final FocusNode typeXtreamFocusNode =
      FocusNode(debugLabel: 'pick_xtream');
  late final FocusNode typeM3uFocusNode = FocusNode(debugLabel: 'pick_m3u');
  late final FocusNode m3uNameFocusNode = FocusNode(debugLabel: 'm3u_name');
  late final FocusNode m3uUrlFocusNode = FocusNode(debugLabel: 'm3u_url');

  final ScrollController _formScrollController = ScrollController();

  List<FocusNode> _verticalChain() {
    if (_type == null) {
      return [
        backFocusNode,
        typeXtreamFocusNode,
        typeM3uFocusNode,
      ];
    }
    if (_type == PlaylistType.xtream) {
      return [
        backFocusNode,
        serverFocusNode,
        usernameFocusNode,
        passwordFocusNode,
        nameFocusNode,
        addButtonFocusNode,
      ];
    }
    return [
      backFocusNode,
      m3uNameFocusNode,
      m3uUrlFocusNode,
      addButtonFocusNode,
    ];
  }

  /// Last text rows (Name / M3U URL) sit above the IME — pin them near the top of
  /// the scroll viewport so the keyboard does not cover the typed text.
  bool _isBottomTextField(FocusNode node) =>
      node == nameFocusNode || node == m3uUrlFocusNode;

  /// Scrolls as far down as allowed so the last rows (Name / M3U URL) sit above the TV IME.
  void _scrollFormToEndForKeyboard() {
    void go() {
      if (!mounted || !_formScrollController.hasClients) return;
      final pos = _formScrollController.position;
      final target = pos.maxScrollExtent;
      if (target <= pos.pixels) return;
      unawaited(
        pos.animateTo(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => go());
    Future<void>.delayed(const Duration(milliseconds: 60), go);
    Future<void>.delayed(const Duration(milliseconds: 180), go);
    Future<void>.delayed(const Duration(milliseconds: 400), go);
  }

  void _scrollFocusIntoView(FocusNode node) {
    void ensure({required double alignment, int pass = 0}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = node.context;
        if (ctx == null || !ctx.mounted) return;
        if (!_formScrollController.hasClients) return;
        unawaited(
          Scrollable.ensureVisible(
            ctx,
            duration: Duration(milliseconds: pass == 0 ? 240 : 180),
            curve: Curves.easeOutCubic,
            alignment: alignment,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
        );
        if (pass == 0 && _isBottomTextField(node)) {
          Future<void>.delayed(const Duration(milliseconds: 140), () {
            if (!mounted || !node.hasFocus) return;
            ensure(alignment: alignment, pass: 1);
          });
          Future<void>.delayed(const Duration(milliseconds: 320), () {
            if (!mounted || !node.hasFocus) return;
            ensure(alignment: alignment, pass: 2);
          });
        }
      });
    }

    final pinTop = _isBottomTextField(node);
    ensure(alignment: pinTop ? 0.0 : 0.14, pass: 0);
    if (_isBottomTextField(node)) {
      _scrollFormToEndForKeyboard();
    }
  }

  void _onPlaylistTypePicked(PlaylistType t) {
    setState(() => _type = t);
    final first = t == PlaylistType.xtream ? serverFocusNode : m3uNameFocusNode;
    scheduleSteadyChannelTileFocus(() => mounted, first);
  }

  KeyEventResult? interceptNav(FocusNode node, KeyEvent event) {
    if (_type == null) {
      if (tvRemoteIsDpadLeft(event) && node == typeM3uFocusNode) {
        typeXtreamFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (tvRemoteIsDpadRight(event) && node == typeXtreamFocusNode) {
        typeM3uFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return interceptVerticalNav(node, event);
  }

  /// TV buttons ([TvFocusable]) use this so D-pad matches the same order as text fields.
  KeyEventResult? interceptVerticalNav(FocusNode node, KeyEvent event) {
    if (!tvRemoteIsDpadDown(event) && !tvRemoteIsDpadUp(event)) {
      return null;
    }
    final chain = _verticalChain();
    final i = chain.indexOf(node);
    if (i < 0) return null;
    if (tvRemoteIsDpadDown(event) && i < chain.length - 1) {
      chain[i + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (tvRemoteIsDpadUp(event) && i > 0) {
      chain[i - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    unawaited(DeviceMemoryChannel.prepareForTextInput());
    WidgetsBinding.instance.addObserver(this);
    for (final n in [
      serverFocusNode,
      usernameFocusNode,
      passwordFocusNode,
      nameFocusNode,
      m3uNameFocusNode,
      m3uUrlFocusNode,
    ]) {
      n.addListener(() {
        if (n.hasFocus) _scrollFocusIntoView(n);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleSteadyChannelTileFocus(() => mounted, typeXtreamFocusNode);
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_type == null) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    final nodes = <FocusNode>[
      serverFocusNode,
      usernameFocusNode,
      passwordFocusNode,
      nameFocusNode,
      m3uNameFocusNode,
      m3uUrlFocusNode,
    ];
    for (final n in nodes) {
      if (primary == n) {
        _scrollFocusIntoView(n);
        if (_isBottomTextField(n)) {
          _scrollFormToEndForKeyboard();
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _formScrollController.dispose();
    _xtName.dispose();
    _xtUser.dispose();
    _xtPass.dispose();
    _xtServer.dispose();
    _m3uName.dispose();
    _m3uUrl.dispose();
    backFocusNode.dispose();
    addButtonFocusNode.dispose();
    serverFocusNode.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    nameFocusNode.dispose();
    typeXtreamFocusNode.dispose();
    typeM3uFocusNode.dispose();
    m3uNameFocusNode.dispose();
    m3uUrlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == null) return;

    final draft = switch (_type!) {
      PlaylistType.xtream => PlaylistDraft.xtream(
          name: _xtName.text,
          username: _xtUser.text,
          password: _xtPass.text,
          serverUrl: _xtServer.text,
        ),
      PlaylistType.m3u => PlaylistDraft.m3u(
          name: _m3uName.text,
          m3uUrl: _m3uUrl.text,
        ),
    };

    if (!_validate(draft)) return;

    final ok = await pushSettingsRoute<bool>(
      context,
      (_) => PlaylistLoadingScreen(draft: draft),
    );

    if (ok == true && mounted) {
      ShellNavigationHub.instance.goTo(ShellDestination.liveTv);
      Navigator.of(context).pop();
    }
  }

  bool _validate(PlaylistDraft draft) {
    String? error;
    if (draft.name.trim().isEmpty) error = 'Enter a playlist name.';
    if (error == null && draft.type == PlaylistType.xtream) {
      if (draft.username == null || draft.username!.trim().isEmpty) {
        error = 'Enter username.';
      } else if (draft.password == null || draft.password!.isEmpty) {
        error = 'Enter password.';
      } else if (draft.serverUrl == null || draft.serverUrl!.trim().isEmpty) {
        error = 'Enter server URL.';
      }
    }
    if (error == null && draft.type == PlaylistType.m3u) {
      if (draft.m3uUrl == null || draft.m3uUrl!.trim().isEmpty) {
        error = 'Enter M3U URL.';
      }
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return false;
    }
    return true;
  }

  void _popScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final kb = viewInsets.bottom;
    // TV often under-reports insets — ensure enough scroll slack when IME is up.
    final bottomPad = kb > 0 ? kb + 520.0 : 0.0;
    final formScale = kb > 0 ? 0.88 : 1.0;
    // Type picker stays centered; Xtream/M3U form is left-aligned (~10% narrower) so
    // the TV IME (bottom-center) does not cover the fields.
    final onFormPage = _type != null;
    final maxContentWidth = onFormPage ? 468.0 : 520.0;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TvFocusable(
              focusNode: backFocusNode,
              focusPadding: const EdgeInsets.all(4),
              onActivate: _popScreen,
              onKeyIntercept: interceptNav,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Add Playlist',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Xtream Codes or M3U URL',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: Colors.white.withOpacity(0.72),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _type == null
              ? _TypePicker(
                  typeXtreamFocusNode: typeXtreamFocusNode,
                  typeM3uFocusNode: typeM3uFocusNode,
                  onKeyIntercept: interceptNav,
                  onPick: _onPlaylistTypePicked,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _formScrollController,
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomPad),
                          child: Transform.scale(
                            alignment: Alignment.topCenter,
                            scale: formScale,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_type == PlaylistType.xtream)
                                  _XtreamForm(
                                    name: _xtName,
                                    user: _xtUser,
                                    pass: _xtPass,
                                    server: _xtServer,
                                    backFocusNode: backFocusNode,
                                    serverFocusNode: serverFocusNode,
                                    usernameFocusNode: usernameFocusNode,
                                    passwordFocusNode: passwordFocusNode,
                                    nameFocusNode: nameFocusNode,
                                    addButtonFocusNode: addButtonFocusNode,
                                  )
                                else
                                  _M3uForm(
                                    name: _m3uName,
                                    url: _m3uUrl,
                                    backFocusNode: backFocusNode,
                                    m3uNameFocusNode: m3uNameFocusNode,
                                    m3uUrlFocusNode: m3uUrlFocusNode,
                                    addButtonFocusNode: addButtonFocusNode,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TvFocusable(
                      focusNode: addButtonFocusNode,
                      focusPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      onActivate: _submit,
                      onKeyIntercept: interceptNav,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.focusBorderRadius,
                          ),
                          color: context.teamPalette.accent
                              .withOpacity(0.18),
                          border: Border.all(
                            color: context.teamPalette.accent
                                .withOpacity(0.65),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Add',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.teamPalette.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );

    final paddedMain = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: mainColumn,
    );

    final laidOutMain = onFormPage
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: paddedMain,
                  ),
                ),
              ),
            ],
          )
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: paddedMain,
            ),
          );

    return PopScope(
      canPop: Navigator.canPop(context),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            playerSettingsRouteBackdrop(context),
            SafeArea(
              child: FocusScope(
                child: laidOutMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.onPick,
    required this.typeXtreamFocusNode,
    required this.typeM3uFocusNode,
    required this.onKeyIntercept,
  });

  final ValueChanged<PlaylistType> onPick;
  final FocusNode typeXtreamFocusNode;
  final FocusNode typeM3uFocusNode;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TvFocusable(
              focusNode: typeXtreamFocusNode,
              autofocus: true,
              focusPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              onActivate: () => onPick(PlaylistType.xtream),
              onKeyIntercept: onKeyIntercept,
              child: _IconTypeTile(
                title: 'Xtream',
                subtitle: 'Login',
                icon: Icons.dns_rounded,
              ),
            ),
            const SizedBox(width: 20),
            TvFocusable(
              focusNode: typeM3uFocusNode,
              focusPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              onActivate: () => onPick(PlaylistType.m3u),
              onKeyIntercept: onKeyIntercept,
              child: _IconTypeTile(
                title: 'M3U',
                subtitle: 'URL',
                icon: Icons.link_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact square tiles — icon-first, for side-by-side source pick.
class _IconTypeTile extends StatelessWidget {
  const _IconTypeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 118,
      height: 118,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.03),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 44, color: context.teamPalette.accent.withOpacity(0.95)),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: Colors.white.withOpacity(0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XtreamForm extends StatelessWidget {
  const _XtreamForm({
    required this.name,
    required this.user,
    required this.pass,
    required this.server,
    required this.backFocusNode,
    required this.serverFocusNode,
    required this.usernameFocusNode,
    required this.passwordFocusNode,
    required this.nameFocusNode,
    required this.addButtonFocusNode,
  });

  final TextEditingController name;
  final TextEditingController user;
  final TextEditingController pass;
  final TextEditingController server;
  final FocusNode backFocusNode;
  final FocusNode serverFocusNode;
  final FocusNode usernameFocusNode;
  final FocusNode passwordFocusNode;
  final FocusNode nameFocusNode;
  final FocusNode addButtonFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShieldTvTextField(
          label: 'Server URL',
          controller: server,
          focusNode: serverFocusNode,
          previousFieldFocus: backFocusNode,
          nextFieldFocus: usernameFocusNode,
          textInputAction: TextInputAction.next,
          dense: true,
          keyboardType: TextInputType.url,
          showTvRemotePad: true,
        ),
        const SizedBox(height: 6),
        ShieldTvTextField(
          label: 'Username',
          controller: user,
          focusNode: usernameFocusNode,
          previousFieldFocus: serverFocusNode,
          nextFieldFocus: passwordFocusNode,
          textInputAction: TextInputAction.next,
          dense: true,
          keyboardType: TextInputType.text,
          showTvRemotePad: true,
        ),
        const SizedBox(height: 6),
        ShieldTvTextField(
          label: 'Password',
          controller: pass,
          focusNode: passwordFocusNode,
          previousFieldFocus: usernameFocusNode,
          nextFieldFocus: nameFocusNode,
          obscure: true,
          textInputAction: TextInputAction.next,
          dense: true,
          keyboardType: TextInputType.text,
          showTvRemotePad: true,
        ),
        const SizedBox(height: 6),
        ShieldTvTextField(
          label: 'Name',
          controller: name,
          focusNode: nameFocusNode,
          previousFieldFocus: passwordFocusNode,
          nextFieldFocus: addButtonFocusNode,
          textInputAction: TextInputAction.done,
          dense: true,
          keyboardType: TextInputType.text,
          showTvRemotePad: true,
        ),
      ],
    );
  }
}

class _M3uForm extends StatelessWidget {
  const _M3uForm({
    required this.name,
    required this.url,
    required this.backFocusNode,
    required this.m3uNameFocusNode,
    required this.m3uUrlFocusNode,
    required this.addButtonFocusNode,
  });

  final TextEditingController name;
  final TextEditingController url;
  final FocusNode backFocusNode;
  final FocusNode m3uNameFocusNode;
  final FocusNode m3uUrlFocusNode;
  final FocusNode addButtonFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShieldTvTextField(
          label: 'Name',
          controller: name,
          focusNode: m3uNameFocusNode,
          previousFieldFocus: backFocusNode,
          nextFieldFocus: m3uUrlFocusNode,
          textInputAction: TextInputAction.next,
          dense: true,
          keyboardType: TextInputType.text,
          showTvRemotePad: true,
        ),
        const SizedBox(height: 6),
        ShieldTvTextField(
          label: 'M3U URL',
          controller: url,
          focusNode: m3uUrlFocusNode,
          previousFieldFocus: m3uNameFocusNode,
          nextFieldFocus: addButtonFocusNode,
          textInputAction: TextInputAction.done,
          dense: true,
          keyboardType: TextInputType.url,
          showTvRemotePad: true,
        ),
      ],
    );
  }
}
