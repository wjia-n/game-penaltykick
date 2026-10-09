import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Renameable player seat.
///
/// - Saves on EVERY keystroke into the order-safe JSON key
///   (`penaltykick_player_names_json`) — never on keyboard-done only.
/// - Commits on focus loss: trims the name, and an empty field falls back
///   to the default seat name.
/// - Owns its TextEditingController so per-keystroke saves (which trigger
///   rebuilds via notifyListeners) never steal focus or move the cursor.
class PlayerNameField extends StatefulWidget {
  final KickSettings settings;
  final int index;
  final String label;
  final bool dark;
  const PlayerNameField({
    super.key,
    required this.settings,
    required this.index,
    required this.label,
    this.dark = false,
  });

  @override
  State<PlayerNameField> createState() => _PlayerNameFieldState();
}

class _PlayerNameFieldState extends State<PlayerNameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.settings.playerNames[widget.index]);
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
    widget.settings.addListener(_syncFromSettings);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      widget.settings.commitPlayerName(widget.index);
    }
  }

  /// Adopt externally changed names (e.g. edited on another screen) —
  /// but never while the user is typing here.
  void _syncFromSettings() {
    if (!mounted) return;
    final v = widget.settings.playerNames[widget.index];
    if (_c.text != v && !_focus.hasFocus) {
      _c.text = v;
      _c.selection =
          TextSelection.collapsed(offset: _c.text.length);
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncFromSettings);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return TextField(
      controller: _c,
      focusNode: _focus,
      maxLength: 16,
      style: TextStyle(color: dark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle:
            TextStyle(color: dark ? Colors.white54 : Colors.black45),
        counterText: '',
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (v) => widget.settings.setPlayerName(widget.index, v),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}
