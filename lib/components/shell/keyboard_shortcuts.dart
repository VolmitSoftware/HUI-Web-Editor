/// Global keyboard bindings.
///
/// One document-level listener, installed on mount and removed on dispose. It
/// dispatches nothing of its own: every chord is a row in `huiShortcutGroups`
/// (`shortcut_sheet.dart`), so the sheet that documents a binding and the code
/// that runs it are the same declaration. This file owns only the stand-down
/// rules — which surface currently owns the keyboard, and when a plain letter
/// must not fire because the user is typing it.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import 'key_listener.dart';
import 'shell_intents.dart';
import 'shell_keys.dart';
import 'shortcut_sheet.dart';

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({
    required this.intents,
    required this.child,
    this.paletteOpen = false,
    this.tourOpen = false,
    this.shortcutsOpen = false,
    this.mobilePaneOpen = false,
    this.onTogglePalette,
    this.onToggleShortcuts,
    this.onSkipTour,
    this.onCloseOverlay,
    this.onCloseMobilePane,
    super.key,
  });

  final ShellIntents intents;
  final Widget child;

  /// While the palette is open it owns arrows, Enter and Escape.
  final bool paletteOpen;

  /// The tour and the shortcut sheet are plain Dart surfaces, not Arcane ones,
  /// so [ShellKey.overlayOpen] never sees them — the shell has to say so.
  final bool tourOpen;
  final bool shortcutsOpen;
  final bool mobilePaneOpen;

  final void Function()? onTogglePalette;
  final void Function()? onToggleShortcuts;
  final void Function()? onSkipTour;

  /// Closes whichever dialog or sheet the app currently has open.
  ///
  /// Arcane dismisses overlays in its JS runtime without telling Dart, so a
  /// controlled surface re-opens itself on the next rebuild. Escape has to be
  /// routed back through the owner's state to stick.
  final void Function()? onCloseOverlay;
  final void Function()? onCloseMobilePane;

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
    // The tour deliberately answers nothing but Escape. Stacking the shortcut
    // sheet on top of a spotlight would highlight a region the sheet covers.
    if (component.tourOpen) {
      if (key.key == 'Escape' && !key.mod && !key.alt) {
        component.onSkipTour?.call();
        return true;
      }
      return false;
    }
    if (component.shortcutsOpen) {
      if ((key.key == 'Escape' && !key.mod && !key.alt) ||
          huiIsShortcutHelpKey(key)) {
        component.onToggleShortcuts?.call();
        return true;
      }
      return false;
    }
    if (huiClosesMobilePane(key, mobilePaneOpen: component.mobilePaneOpen)) {
      component.onCloseMobilePane?.call();
      return true;
    }

    final HuiShortcutScope scope = HuiShortcutScope(
      intents: component.intents,
      key: key,
      togglePalette: component.onTogglePalette,
      toggleShortcuts: component.onToggleShortcuts,
    );
    // Two passes over one table. The first carries the chords no editor could
    // plausibly want to type into a field; the second is everything the
    // stand-down below protects.
    final bool? always = _dispatch(scope, key, alwaysOn: true);
    if (always != null) return always;
    if (component.paletteOpen || key.editable || key.alt) return false;
    return _dispatch(scope, key, alwaysOn: false) ?? false;
  }

  /// Null when no row matched, so a miss is distinguishable from a row that
  /// matched and declined (Delete with an empty selection must leave the
  /// browser default alone).
  bool? _dispatch(
    HuiShortcutScope scope,
    ShellKey key, {
    required bool alwaysOn,
  }) {
    for (final HuiShortcutRow row in huiBoundShortcuts) {
      if (row.alwaysOn != alwaysOn) continue;
      if (!(row.matches?.call(key) ?? false)) continue;
      return row.run?.call(scope) ?? false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => component.child;
}
