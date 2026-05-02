/// Manage Channels — per-category list. 1:1 port of
/// `renderChannelsListPage()` + `renderChannelOverride()` in
/// settings.html (lines 6663 + 6681).
///
/// Grid of channel override cards (`.ch-override`) with:
///   * 36×36 logo box (gradient bg + initials, or custom image).
///   * Display name + `Originally: …` when renamed.
///   * Badges: HIDDEN (warn), CUSTOM LOGO (accent), RENAMED (accent).
///   * Action chips: Rename / Logo / Hide-Show / Reset.
///   * Inline edit panels for rename and logo URL.
/// Head exposes a Show-all bulk action.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_chips.dart';
import '../widgets/ns_sub_page_head.dart';

class NsChannelsListPage extends StatefulWidget {
  const NsChannelsListPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.categoryId,
    required this.onBack,
  });

  final NewSettingsState state;
  final String playlistId;
  final String categoryId;
  final VoidCallback onBack;

  @override
  State<NsChannelsListPage> createState() => _NsChannelsListPageState();
}

class _NsChannelsListPageState extends State<NsChannelsListPage> {
  // One controller + focus node per (channel × editor-kind). Only the
  // currently-open inline edit is rendered; the rest just sit idle.
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _nodes = {};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _nodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _keyName(String chId) =>
      'chname:${widget.playlistId}:${widget.categoryId}:$chId';
  String _keyLogo(String chId) =>
      'chlogo:${widget.playlistId}:${widget.categoryId}:$chId';

  Widget _buildChannelCard(NsPlaylistChannel c) {
    return _ChannelOverride(
      channel: c,
      editingName: widget.state.inlineEdit == _keyName(c.id),
      editingLogo: widget.state.inlineEdit == _keyLogo(c.id),
      nameCtrl: _ctrl(_keyName(c.id)),
      logoCtrl: _ctrl(_keyLogo(c.id)),
      nameFocus: _focus(_keyName(c.id)),
      logoFocus: _focus(_keyLogo(c.id)),
      onEditName: () => _toggleInline(
        _keyName(c.id),
        initial: c.alias ?? '',
      ),
      onEditLogo: () => _toggleInline(
        _keyLogo(c.id),
        initial: c.logo ?? '',
      ),
      onToggleHidden: () => widget.state.toggleChannelHidden(
        widget.playlistId,
        widget.categoryId,
        c.id,
      ),
      onReset: () => widget.state.resetChannel(
        widget.playlistId,
        widget.categoryId,
        c.id,
      ),
      onSaveName: () {
        widget.state.setChannelAlias(
          widget.playlistId,
          widget.categoryId,
          c.id,
          _ctrl(_keyName(c.id)).text,
        );
        widget.state.inlineEdit = null;
      },
      onSaveLogo: () {
        widget.state.setChannelLogo(
          widget.playlistId,
          widget.categoryId,
          c.id,
          _ctrl(_keyLogo(c.id)).text,
        );
        widget.state.inlineEdit = null;
      },
      onCancelEdit: () => widget.state.inlineEdit = null,
    );
  }

  /// Lazy-create a controller. Does **not** touch `.text` on reads —
  /// only the edit-open path ([_toggleInline]) explicitly seeds the
  /// value, so the user's typing is never wiped on an unrelated
  /// rebuild.
  TextEditingController _ctrl(String key) {
    return _ctrls.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  FocusNode _focus(String key) {
    return _nodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'ns:chEdit:$key'),
    );
  }

  void _toggleInline(String key, {required String initial}) {
    if (widget.state.inlineEdit == key) {
      widget.state.inlineEdit = null;
      return;
    }
    widget.state.inlineEdit = key;
    _ctrl(key).text = initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = _focus(key);
      if (n.canRequestFocus) n.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final p = widget.state.playlistById(widget.playlistId);
        if (p == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              d.listBottomPadding,
            ),
            children: [
              NsSubPageHead(
                title: 'Playlist not found',
                onBack: widget.onBack,
              ),
            ],
          );
        }
        final cat = (p.groups['live'] ?? const <NsPlaylistGroup>[])
            .cast<NsPlaylistGroup?>()
            .firstWhere(
              (g) => g?.id == widget.categoryId,
              orElse: () => null,
            );
        final channels = p.channelsMap[widget.categoryId] ??
            const <NsPlaylistChannel>[];
        final hidden = channels.where((c) => c.hidden).length;
        final renamed = channels.where((c) => c.alias != null).length;
        final subParts = <String>['${channels.length} channels'];
        if (renamed > 0) subParts.add('$renamed renamed');
        if (hidden > 0) subParts.add('$hidden hidden');

        final header = SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              0,
            ),
            child: NsSubPageHead(
              title: cat != null ? (cat.alias ?? cat.name) : 'Channels',
              subtitle: subParts.join(' · '),
              onBack: widget.onBack,
              actions: channels.isEmpty
                  ? const []
                  : [
                      NsButton(
                        label: 'Show all',
                        icon: Icons.visibility_rounded,
                        onPressed: () => widget.state.showAllChannels(
                          widget.playlistId,
                          widget.categoryId,
                        ),
                      ),
                    ],
            ),
          ),
        );

        if (channels.isEmpty) {
          return CustomScrollView(
            slivers: [
              header,
              const SliverToBoxAdapter(child: _EmptyChannels()),
              SliverPadding(
                padding: EdgeInsets.only(bottom: d.listBottomPadding),
              ),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const minW = 240.0;
            const gap = 8.0;
            final availW =
                constraints.maxWidth - d.listHorizontalPadding * 2;
            final cols =
                ((availW + gap) / (minW + gap)).floor().clamp(1, 4);
            final cardW = (availW - gap * (cols - 1)) / cols;
            final rowCount = (channels.length + cols - 1) ~/ cols;

            return CustomScrollView(
              slivers: [
                header,
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    d.listHorizontalPadding,
                    0,
                    d.listHorizontalPadding,
                    d.listBottomPadding,
                  ),
                  sliver: SliverList.builder(
                    itemCount: rowCount,
                    itemBuilder: (context, rowIdx) {
                      final start = rowIdx * cols;
                      final end = (start + cols).clamp(0, channels.length);
                      return Padding(
                        padding: EdgeInsets.only(
                          top: rowIdx == 0 ? 0 : gap,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = start; i < end; i++) ...[
                              if (i > start) SizedBox(width: gap),
                              SizedBox(
                                width: cardW,
                                child: _buildChannelCard(channels[i]),
                              ),
                            ],
                            if (end - start < cols)
                              Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.ch-override` — 12/14 padding, 12 radius, col-flex with 8 gap.
// Tightened for TV.
// ═══════════════════════════════════════════════════════════════════════

class _ChannelOverride extends StatelessWidget {
  const _ChannelOverride({
    required this.channel,
    required this.editingName,
    required this.editingLogo,
    required this.nameCtrl,
    required this.logoCtrl,
    required this.nameFocus,
    required this.logoFocus,
    required this.onEditName,
    required this.onEditLogo,
    required this.onToggleHidden,
    required this.onReset,
    required this.onSaveName,
    required this.onSaveLogo,
    required this.onCancelEdit,
  });

  final NsPlaylistChannel channel;
  final bool editingName;
  final bool editingLogo;
  final TextEditingController nameCtrl;
  final TextEditingController logoCtrl;
  final FocusNode nameFocus;
  final FocusNode logoFocus;
  final VoidCallback onEditName;
  final VoidCallback onEditLogo;
  final VoidCallback onToggleHidden;
  final VoidCallback onReset;
  final VoidCallback onSaveName;
  final VoidCallback onSaveLogo;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final display = channel.alias ?? channel.name;
    final renamed = channel.alias != null;
    final hasLogo = channel.logo != null;
    final canReset = renamed || hasLogo;

    return Opacity(
      opacity: channel.hidden ? 0.65 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: channel.hidden ? NsColors.bg2 : NsColors.surface,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Logo(channel: channel, display: display),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        display,
                        style: const TextStyle(
                          color: NsColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (renamed) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Originally: ${channel.name}',
                          style: const TextStyle(
                            color: NsColors.text4,
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (channel.hidden || hasLogo || renamed) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (channel.hidden) const NsHiddenTag(),
                            if (hasLogo)
                              const NsTag(label: 'CUSTOM LOGO'),
                            if (renamed) const NsTag(label: 'RENAMED'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                NsChipBtn(
                  icon: Icons.edit_rounded,
                  label: 'Rename',
                  variant: editingName
                      ? NsChipVariant.accent
                      : NsChipVariant.defaultVariant,
                  onPressed: onEditName,
                ),
                NsChipBtn(
                  icon: Icons.image_rounded,
                  label: 'Logo',
                  variant: editingLogo
                      ? NsChipVariant.accent
                      : NsChipVariant.defaultVariant,
                  onPressed: onEditLogo,
                ),
                NsChipBtn(
                  icon: channel.hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  label: channel.hidden ? 'Show' : 'Hide',
                  variant: channel.hidden
                      ? NsChipVariant.accent
                      : NsChipVariant.defaultVariant,
                  onPressed: onToggleHidden,
                ),
                if (canReset)
                  NsChipBtn(
                    icon: Icons.restart_alt_rounded,
                    label: 'Reset',
                    variant: NsChipVariant.danger,
                    onPressed: onReset,
                  ),
              ],
            ),
            if (editingName)
              NsInlineEdit(
                label: 'Display name',
                controller: nameCtrl,
                focusNode: nameFocus,
                placeholder: channel.name,
                helpText:
                    "Empty value uses the original name from the playlist.",
                onSave: onSaveName,
                onCancel: onCancelEdit,
              ),
            if (editingLogo)
              NsInlineEdit(
                label: 'Logo URL',
                controller: logoCtrl,
                focusNode: logoFocus,
                placeholder: 'https://example.com/logo.png',
                helpText:
                    "Paste a square image URL. Leave empty to use the "
                    "source's logo.",
                keyboardType: TextInputType.url,
                onSave: onSaveLogo,
                onCancel: onCancelEdit,
              ),
          ],
        ),
      ),
    );
  }
}

/// `.ch-override .logo` — 36×36 gradient box. Shows initials derived
/// from the display name when no custom URL; paints the URL as a bg
/// image when provided.
class _Logo extends StatelessWidget {
  const _Logo({required this.channel, required this.display});
  final NsPlaylistChannel channel;
  final String display;

  String get _initials {
    final parts = display
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
    final clipped = parts.length > 3 ? parts.substring(0, 3) : parts;
    return clipped.isEmpty ? '·' : clipped;
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = channel.logo != null && channel.logo!.isNotEmpty;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: hasLogo
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
        color: hasLogo ? NsColors.surface2 : null,
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(channel.logo!),
                fit: BoxFit.cover,
              )
            : null,
        borderRadius: BorderRadius.circular(7),
      ),
      child: hasLogo
          ? null
          : Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No channels',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'This category is empty.',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
