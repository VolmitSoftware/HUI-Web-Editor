/// DOM-free keyboard model shared by the global binder, the top-bar tooltips
/// and the command palette.
///
/// Shortcut specs are written once in the platform-neutral `mod+Z` form and
/// rendered per platform, so a label and its binding can never drift apart.
library;

class ShellKey {
  const ShellKey({
    required this.key,
    this.ctrl = false,
    this.meta = false,
    this.shift = false,
    this.alt = false,
    this.editable = false,
    this.overlayOpen = false,
  });

  /// The `KeyboardEvent.key` value, verbatim.
  final String key;
  final bool ctrl;
  final bool meta;
  final bool shift;
  final bool alt;

  /// True when the event came from a text input, textarea, select or a
  /// contenteditable node. Plain-letter shortcuts stand down for these.
  final bool editable;

  /// True when an Arcane overlay (dialog, sheet, drawer) is open. The shell
  /// stands down entirely so Escape and focus stay with the overlay.
  final bool overlayOpen;

  /// Command on Apple, Control everywhere else — both are accepted so an
  /// external keyboard on either platform behaves.
  bool get mod => meta || ctrl;

  String get lower => key.toLowerCase();
}

typedef ShellKeyHandler = bool Function(ShellKey key);

/// Which overlay an Escape press belongs to while an Arcane surface is open.
enum HuiOverlayEscape { confirmDelete, appOverlay }

/// The shell's own delete confirm wins over the app's dialogs and sheet.
///
/// Its flag lives in the shell's state, which `app.dart` cannot see, so the
/// app-level close reported the key as handled and left the confirm on screen:
/// the one dialog in the editor that ignored Escape. Only one of the two can be
/// open at a time — arming the confirm is what closes the dialog the user came
/// from — so this is a precedence rule, not a cascade.
HuiOverlayEscape huiOverlayEscapeTarget({required bool confirmDeleteOpen}) =>
    confirmDeleteOpen
    ? HuiOverlayEscape.confirmDelete
    : HuiOverlayEscape.appOverlay;

const String _apple = 'apple';

/// Renders `mod+Shift+Z` as `['⌘', '⇧', 'Z']` or `['Ctrl', 'Shift', 'Z']`.
List<String> shortcutKeys(String spec, {required bool apple}) {
  final List<String> parts = <String>[];
  for (final String raw in spec.split('+')) {
    final String token = raw.trim();
    if (token.isEmpty) continue;
    parts.add(_renderToken(token, apple));
  }
  return parts;
}

String shortcutLabel(String spec, {required bool apple}) =>
    shortcutKeys(spec, apple: apple).join(apple ? '' : '+');

String _renderToken(String token, bool apple) {
  switch (token.toLowerCase()) {
    case 'mod':
      return apple ? '⌘' : 'Ctrl';
    case 'shift':
      return apple ? '⇧' : 'Shift';
    case 'alt':
      return apple ? '⌥' : 'Alt';
    case 'ctrl':
      return apple ? '⌃' : 'Ctrl';
    case 'enter':
      return apple ? '↩' : 'Enter';
    case 'esc':
    case 'escape':
      return 'Esc';
    case 'delete':
      return apple ? '⌫' : 'Del';
    case 'arrows':
      return '←↑↓→';
    case _apple:
      return '⌘';
    default:
      return token.length == 1 ? token.toUpperCase() : token;
  }
}
