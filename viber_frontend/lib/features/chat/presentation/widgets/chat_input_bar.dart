import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'emoji_picker_panel.dart';

/// Barra de entrada de chat reutilizable.
///
/// Soporta:
///   - Emoji picker (panel deslizante)
///   - Menciones (@) con overlay de sugerencias
///   - Multiline (máx. 5 líneas)
///   - Envío con botón o con Enter (configurable)
///
/// [mentionables] — lista de usernames disponibles para mencionar.
/// Pasa [] si no quieres soporte de menciones (DMs, por ejemplo).
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final List<String> mentionables;
  final bool isMuted;
  final Color accentColor;
  final Color? bgColor;
  final Color? inputFillColor;
  final Color? textColor;
  final Color? hintColor;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.mentionables = const [],
    this.isMuted      = false,
    this.accentColor  = appAccent,
    this.bgColor,
    this.inputFillColor,
    this.textColor,
    this.hintColor,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _emojiOpen    = false;
  List<String> _mentionSuggestions = [];
  int?  _mentionStart; // posición del '@' en el texto
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  // ── Detección de mención ──────────────────────────────────────────────────

  void _onTextChanged() {
    if (widget.mentionables.isEmpty) return;
    final text   = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0) return;

    // Buscar el último '@' antes del cursor
    final before    = text.substring(0, cursor);
    final atIndex   = before.lastIndexOf('@');

    if (atIndex == -1) {
      _clearMentions();
      return;
    }

    // El texto después del '@' no debe tener espacios (no ha terminado el @)
    final query = before.substring(atIndex + 1);
    if (query.contains(' ')) {
      _clearMentions();
      return;
    }

    final suggestions = widget.mentionables
        .where((u) => u.toLowerCase().startsWith(query.toLowerCase()))
        .take(5)
        .toList();

    setState(() {
      _mentionStart       = atIndex;
      _mentionSuggestions = suggestions;
    });
  }

  void _clearMentions() {
    if (_mentionSuggestions.isEmpty) return;
    setState(() {
      _mentionSuggestions = [];
      _mentionStart       = null;
    });
  }

  void _applyMention(String username) {
    if (_mentionStart == null) return;
    final text   = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final before = text.substring(0, _mentionStart);
    final after  = cursor < text.length ? text.substring(cursor) : '';
    final newText = '$before@$username $after';
    widget.controller.value = TextEditingValue(
      text:      newText,
      selection: TextSelection.collapsed(
          offset: before.length + username.length + 2),
    );
    _clearMentions();
  }

  // ── Envío ─────────────────────────────────────────────────────────────────

  void _handleSend() {
    if (widget.controller.text.trim().isEmpty) return;
    widget.onSend();
    setState(() {
      _emojiOpen          = false;
      _mentionSuggestions = [];
      _mentionStart       = null;
    });
  }

  // ── Emoji ─────────────────────────────────────────────────────────────────

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      _focus.unfocus();
    } else {
      _focus.requestFocus();
    }
  }

  void _onEmojiSelected(String emoji) {
    final ctrl   = widget.controller;
    final cursor = ctrl.selection.isValid
        ? ctrl.selection.baseOffset
        : ctrl.text.length;
    final text   = ctrl.text;
    final newText = text.substring(0, cursor) + emoji + text.substring(cursor);
    ctrl.value = TextEditingValue(
      text:      newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final bgColor   = widget.bgColor      ?? cs.surface;
    final textColor = widget.textColor    ?? cs.onSurface;
    final hintColor = widget.hintColor    ?? cs.onSurface.withValues(alpha: 0.6);
    final fillColor = widget.inputFillColor ?? cs.surfaceContainerHighest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Sugerencias de mención ──────────────────────────────────────
        if (_mentionSuggestions.isNotEmpty)
          _MentionSuggestions(
            suggestions: _mentionSuggestions,
            onSelected:  _applyMention,
            accentColor: widget.accentColor,
          ),

        // ── Barra principal ─────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            12, 8, 12,
            8 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: appDivider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón emoji
              _IconBtn(
                icon:    _emojiOpen
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                color:   _emojiOpen ? widget.accentColor : hintColor,
                onTap:   widget.isMuted ? null : _toggleEmoji,
              ),
              const SizedBox(width: 6),

              // Campo de texto
              Expanded(
                child: TextField(
                  focusNode:   _focus,
                  controller:  widget.controller,
                  style: TextStyle(
                      color: textColor, fontSize: 14),
                  maxLines:    5,
                  minLines:    1,
                  enabled:     !widget.isMuted,
                  textInputAction: TextInputAction.newline,
                  onTap: () {
                    if (_emojiOpen) setState(() => _emojiOpen = false);
                  },
                  decoration: InputDecoration(
                    hintText: widget.isMuted
                        ? 'room_chat.muted_hint'.tr()
                        : 'room_chat.input_hint'.tr(),
                    hintStyle: TextStyle(
                        color: hintColor.withOpacity(
                            widget.isMuted ? 0.3 : 0.55),
                        fontSize: 13),
                    filled:    true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:   BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                          color: widget.accentColor.withOpacity(0.4),
                          width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón enviar
              AnimatedOpacity(
                opacity: widget.isMuted ? 0.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(22),
                  elevation: 2,
                  shadowColor: widget.accentColor.withOpacity(0.4),
                  child: InkWell(
                    onTap: widget.isMuted ? null : _handleSend,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Panel de emojis (animado) ────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve:    Curves.easeInOut,
          child: _emojiOpen
              ? EmojiPickerPanel(onEmojiSelected: _onEmojiSelected)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Sugerencias de mención ────────────────────────────────────────────────────

class _MentionSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onSelected;
  final Color accentColor;

  const _MentionSuggestions({
    required this.suggestions,
    required this.onSelected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  Theme.of(context).colorScheme.surface,
        border: Border(
          top:    BorderSide(color: appDivider),
          bottom: BorderSide(color: appDivider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: suggestions.map((u) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(u),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: accentColor.withOpacity(0.2),
                    child: Text(
                      u[0].toUpperCase(),
                      style: TextStyle(
                          color:      accentColor,
                          fontSize:   12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@$u',
                    style: TextStyle(
                        color:      accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize:   13),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Botón icono compacto ──────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
