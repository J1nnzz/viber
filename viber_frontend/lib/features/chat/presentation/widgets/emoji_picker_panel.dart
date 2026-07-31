import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Categorías y emojis
// ─────────────────────────────────────────────────────────────────────────────

class _EmojiCategory {
  final String label;
  final IconData icon;
  final List<String> emojis;
  const _EmojiCategory(this.label, this.icon, this.emojis);
}

// Getter y no `const`: los nombres de categoría se traducen con .tr(), que
// debe reevaluarse para que un cambio de idioma se refleje.
List<_EmojiCategory> get _categories => [
  _EmojiCategory('Caras', Icons.tag_faces_rounded, [
    '😀','😁','😂','🤣','😃','😄','😅','😆','😊','😇',
    '🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚',
    '😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫','🤔',
    '😐','😑','😶','😏','😒','🙄','😬','🤥','😔','😪',
    '🤤','😴','😷','🤒','🤕','🤢','🤮','🤧','🥵','🥶',
    '😵','🤯','😎','🤓','🧐','😕','😟','🙁','😮','😯',
    '😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭',
    '😱','😖','😣','😞','😓','😩','😫','🥱','😤','😡',
    '😠','🤬','😈','👿','💀','☠️','💩','🤡','👹','👺',
  ]),
  _EmojiCategory('Gestos', Icons.back_hand_rounded, [
    '👋','🤚','🖐️','✋','🖖','👌','🤌','🤏','✌️','🤞',
    '🤟','🤘','🤙','👈','👉','👆','🖕','👇','☝️','👍',
    '👎','✊','👊','🤛','🤜','👏','🙌','👐','🤲','🤝',
    '🙏','✍️','💅','🤳','💪','🦾','🦿','🦵','🦶','👂',
  ]),
  _EmojiCategory('Corazones', Icons.favorite_rounded, [
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❤️‍🔥','❤️‍🩹','💕','💞','💓','💗','💖','💘','💝','💟',
    '☮️','✝️','☪️','🕉️','✡️','🔯','🪯','☯️','☦️','🛐',
  ]),
  _EmojiCategory('common.music'.tr(), Icons.music_note_rounded, [
    '🎵','🎶','🎸','🎹','🥁','🎷','🎺','🎻','🪕','🎤',
    '🎧','📻','🎼','🎙️','🎚️','🎛️','📯','🪗','🪘','🎹',
    '🎭','🎬','🎤','🔊','🔉','🔈','🔇','📢','📣','🎉',
    '🎊','🎈','🎆','🎇','✨','💫','⭐','🌟','🌠','🎁',
  ]),
  _EmojiCategory('Popular', Icons.local_fire_department_rounded, [
    '🔥','💯','✅','❌','⚠️','💥','🌈','⚡','🌊','💧',
    '🌀','🎯','🏆','🥇','🎮','🕹️','💎','👑','🚀','🛸',
    '🌍','🌎','🌏','🌙','☀️','🌤️','⛅','🌧️','❄️','🌸',
    '🌺','🌻','🌹','🍀','🌴','🌵','🦋','🐶','🐱','🐼',
    '🦊','🐻','🐨','🦁','🐯','🦊','🍕','🍔','🍦','🎂',
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class EmojiPickerPanel extends StatefulWidget {
  /// Llamado al seleccionar un emoji
  final void Function(String emoji) onEmojiSelected;

  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel>
    with SingleTickerProviderStateMixin {
  int _catIndex = 0;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) {
        setState(() => _catIndex = _tabCtrl.index);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: appDivider)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Tab de categorías ────────────────────────────────────────
          TabBar(
            controller:         _tabCtrl,
            isScrollable:       false,
            indicatorColor:     appAccent,
            indicatorWeight:    2,
            indicatorSize:      TabBarIndicatorSize.tab,
            labelPadding:       EdgeInsets.zero,
            dividerColor:       Colors.transparent,
            tabs: _categories.map((c) => Tab(
              height: 40,
              child: Icon(
                c.icon,
                size: 20,
                color: _catIndex == _categories.indexOf(c)
                    ? appAccent
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )).toList(),
          ),
          Divider(height: 1, color: appDivider),
          // ── Grid de emojis ───────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _categories.map((cat) => GridView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                  childAspectRatio: 1,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount:   cat.emojis.length,
                itemBuilder: (_, i) => _EmojiButton(
                  emoji:    cat.emojis[i],
                  onTap:    () => widget.onEmojiSelected(cat.emojis[i]),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
