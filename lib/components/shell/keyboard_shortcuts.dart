/// Global keyboard bindings.
///
/// One document-level listener, installed on mount and removed on dispose. It
/// stands down entirely while focus is inside an input, textarea, select or
/// contenteditable node, apart from the two chords that must always work
/// (palette and export), so typing a command name never nudges a component.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../state/editor_store.dart';
import 'key_listener.dart';
import 'shell_intents.dart';
import 'shell_keys.dart';

/// Nudge distance in blocks; Shift multiplies it.
const double huiNudgeStep = 0.05;
const double huiNudgeStepLarge = 0.25;

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({
    required this.intents,
    required this.child,
    this.paletteOpen = false,
    this.onTogglePalette,
    this.onCloseOverlay,
    super.key,
  });

  final ShellIntents intents;
  final Widget child;

  /// While the palette is open it owns arrows, Enter and Escape.
  final bool paletteOpen;
  final void Function()? onTogglePalette;

  /// Closes whichever dialog or sheet the app currently has open.
  ///
  /// Arcane dismisses overlays in its JS runtime without telling Dart, so a
  /// controlled surface re-opens itself on the next rebuild. Escape has to be
  /// routed back through the owner's state to stick.
  final void Function()? onCloseOverlay;

  @override
  State<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends State<KeyboardShortcuts> {
  void Function()? _uninstall;

  @override
  void initState() {
    super.initState();
    _uninstall = installShellKeyListener(_onKey);
  }

  @override
  void dispose() {
    _uninstall?.call();
    _uninstall = null;
    super.dispose();
  }

  bool _onKey(ShellKey key) {
    final ShellIntents intents = component.intents;
    // An open dialog or sheet owns the keyboard (arrows, Delete); firing
    // editor shortcuts behind it would act on a hidden surface. Escape is the
    // exception: Dart owns `isOpen`, so it has to do the closing.
    if (key.overlayOpen) {
      if (key.key == 'Escape' && !key.mod && !key.alt) {
        component.onCloseOverlay?.call();
        return true;
      }
      return false;
    }
    if (key.mod && !key.alt && key.lower == 'k') {
      component.onTogglePalette?.call();
      return true;
    }
    if (key.mod && !key.alt && !key.shift && key.lower == 's') {
      intents.exportMenu();
      return true;
    }
    if (component.paletteOpen || key.editable || key.alt) return false;
    if (key.mod) return _modChord(intents, key);
    return _plainKey(intents, key);
  }

  bool _modChord(ShellIntents intents, ShellKey key) {
    switch (key.lower) {
      case 'z':
        if (key.shift) {
          intents.redo();
        } else {
          intents.undo();
        }
        return true;
      case 'y':
        intents.redo();
        return true;
      case 'd':
        intents.duplicateSelected();
        return true;
      default:
        return false;
    }
  }

  bool _plainKey(ShellIntents intents, ShellKey key) {
    final EditorStore store = intents.store;
    final double step = key.shift ? huiNudgeStepLarge : huiNudgeStep;
    switch (key.key) {
      case 'Delete':
      case 'Backspace':
        if (store.selectedId == null) return false;
        intents.deleteSelected();
        return true;
      case 'Escape':
        if (store.selectedId == null) return false;
        intents.deselect();
        return true;
      case 'ArrowLeft':
        return _nudge(intents, -step, 0);
      case 'ArrowRight':
        return _nudge(intents, step, 0);
      case 'ArrowUp':
        return _nudge(intents, 0, step);
      case 'ArrowDown':
        return _nudge(intents, 0, -step);
    }
    if (key.shift) return false;
    switch (key.lower) {
      case 'v':
        intents.setView(EditorView.visual);
        return true;
      case 'c':
        intents.setView(EditorView.code);
        return true;
      case 's':
        intents.setView(EditorView.split);
        return true;
      default:
        return false;
    }
  }

  bool _nudge(ShellIntents intents, double dx, double dy) {
    if (intents.store.selectedId == null) return false;
    intents.nudgeSelected(dx, dy);
    return true;
  }

  @override
  Widget build(BuildContext context) => component.child;
}
