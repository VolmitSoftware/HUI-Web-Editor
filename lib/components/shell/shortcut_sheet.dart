/// The one shortcut table, and the sheet that renders it.
///
/// Every global chord is *dispatched* from [huiShortcutGroups] by
/// `keyboard_shortcuts.dart`, *labelled* from the same rows by this sheet, and
/// *chipped* in the command palette by `shell_actions.dart` reading
/// [huiShortcutSpec]. One row is therefore the binding, its description and its
/// palette chip at once — the three cannot drift apart because there is only
/// one of each.
///
/// Rows with no [HuiShortcutRow.matches] are gestures another surface binds on
/// its own element (`canvas_interactions.dart`, `preview_stage.dart`, the
/// palette's own input). They are documented here and dispatched nowhere; each
/// carries a note naming the surface that owns it.
///
/// The sheet is hand-built for the reason the palette is: it has to survive
/// Escape and outside-click on Dart's terms, and it is unmounted by its caller
/// so it can also run an exit animation, which no Arcane surface can
/// (06-motion.css, foot of file).
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../config/editing.dart';
import '../../state/editor_store.dart';
import '../common/class_names.dart';
import 'shell_intents.dart';
import 'shell_keys.dart';

/// What a bound row is handed when it fires.
class HuiShortcutScope {
  const HuiShortcutScope({
    required this.intents,
    required this.key,
    this.togglePalette,
    this.toggleShortcuts,
  });

  final ShellIntents intents;

  /// The event that matched. Arrow rows need to know which arrow, and nothing
  /// else about the key survives the match.
  final ShellKey key;

  /// Shell-owned surfaces the intents layer has no handle on.
  final void Function()? togglePalette;
  final void Function()? toggleShortcuts;
}

class HuiShortcutRow {
  const HuiShortcutRow({
    required this.id,
    required this.spec,
    required this.label,
    this.matches,
    this.run,
    this.alwaysOn = false,
    this.note,
  });

  /// Stable key for [huiShortcutSpec]. Where a row mirrors a palette command
  /// the id is that command's id, so the chip lookup is `huiShortcutSpec(id)`.
  final String id;

  /// Platform-neutral spec, rendered through [shortcutKeys].
  final String spec;
  final String label;

  /// Null when another surface owns the binding.
  final bool Function(ShellKey key)? matches;

  /// Returns whether the event was consumed. A guard that declines — Delete
  /// with an empty selection — has to leave the browser default alone.
  final bool Function(HuiShortcutScope scope)? run;

  /// Fires even inside a text field and behind an open palette. Only for
  /// chords no editor could plausibly want to type.
  final bool alwaysOn;
  final String? note;
}

class HuiShortcutGroup {
  const HuiShortcutGroup({
    required this.title,
    required this.rows,
    this.note,
  });

  final String title;
  final List<HuiShortcutRow> rows;

  /// Where the group's rows are dispatched from, when it is not the document.
  final String? note;
}

/// `?` is Shift+/ on a US layout, but layouts that put `?` elsewhere still
/// report `key == '?'` — both spellings are accepted so the binding survives a
/// non-US keyboard.
bool huiIsShortcutHelpKey(ShellKey key) =>
    !key.mod && !key.alt && (key.key == '?' || (key.shift && key.key == '/'));

bool _isArrow(String key) =>
    key == 'ArrowLeft' ||
    key == 'ArrowRight' ||
    key == 'ArrowUp' ||
    key == 'ArrowDown';

bool _nudge(HuiShortcutScope scope, double step) {
  if (scope.intents.store.selectionIds.isEmpty) return false;
  switch (scope.key.key) {
    case 'ArrowLeft':
      scope.intents.nudgeSelected(-step, 0);
    case 'ArrowRight':
      scope.intents.nudgeSelected(step, 0);
    case 'ArrowUp':
      scope.intents.nudgeSelected(0, step);
    case 'ArrowDown':
      scope.intents.nudgeSelected(0, -step);
    default:
      return false;
  }
  return true;
}

bool _setView(HuiShortcutScope scope, EditorView view) {
  scope.intents.setView(view);
  return true;
}

/// A plain letter or symbol: no modifier of any kind. Shift is excluded because
/// the binder treats a shifted letter as a different key entirely.
bool _plain(ShellKey key, String lower) =>
    !key.mod && !key.alt && !key.shift && key.lower == lower;

final List<HuiShortcutGroup> huiShortcutGroups = <HuiShortcutGroup>[
  HuiShortcutGroup(
    title: 'Global',
    note: 'Bound on the document, so they work wherever the pointer is. '
        'Everything except the first two stands down while a text field has '
        'focus.',
    rows: <HuiShortcutRow>[
      HuiShortcutRow(
        id: 'shell.palette',
        spec: 'mod+K',
        label: 'Open the command palette',
        alwaysOn: true,
        matches: (ShellKey key) => key.mod && !key.alt && key.lower == 'k',
        run: (HuiShortcutScope scope) {
          scope.togglePalette?.call();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'file.export',
        spec: 'mod+S',
        label: 'Export the menu JSON',
        alwaysOn: true,
        matches: (ShellKey key) =>
            key.mod && !key.alt && !key.shift && key.lower == 's',
        run: (HuiShortcutScope scope) {
          scope.intents.exportMenu();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'help.shortcuts',
        spec: '?',
        label: 'Show this sheet',
        note: 'Shift and /. Stands down while you are typing.',
        matches: huiIsShortcutHelpKey,
        run: (HuiShortcutScope scope) {
          scope.toggleShortcuts?.call();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.undo',
        spec: 'mod+Z',
        label: 'Undo',
        matches: (ShellKey key) =>
            key.mod && !key.alt && !key.shift && key.lower == 'z',
        run: (HuiShortcutScope scope) {
          scope.intents.undo();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.redo',
        spec: 'mod+Shift+Z',
        label: 'Redo',
        note: 'Ctrl+Y works too.',
        matches: (ShellKey key) =>
            key.mod &&
            !key.alt &&
            ((key.shift && key.lower == 'z') || key.lower == 'y'),
        run: (HuiShortcutScope scope) {
          scope.intents.redo();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.duplicate',
        spec: 'mod+D',
        label: 'Duplicate the selection',
        matches: (ShellKey key) => key.mod && !key.alt && key.lower == 'd',
        run: (HuiShortcutScope scope) {
          scope.intents.duplicateSelected();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'selection.all',
        spec: 'mod+A',
        label: 'Select every component',
        matches: (ShellKey key) =>
            key.mod && !key.alt && !key.shift && key.lower == 'a',
        run: (HuiShortcutScope scope) {
          scope.intents.selectAll();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.delete',
        spec: 'Delete',
        label: 'Delete the selection',
        note: 'Backspace too. Asks first — the artboard does not.',
        matches: (ShellKey key) =>
            !key.mod &&
            !key.alt &&
            (key.key == 'Delete' || key.key == 'Backspace'),
        run: (HuiShortcutScope scope) {
          if (scope.intents.store.selectionIds.isEmpty) return false;
          scope.intents.deleteSelected();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.deselect',
        spec: 'Escape',
        label: 'Deselect everything',
        matches: (ShellKey key) =>
            !key.mod && !key.alt && key.key == 'Escape',
        run: (HuiShortcutScope scope) {
          if (scope.intents.store.selectionIds.isEmpty) return false;
          scope.intents.deselect();
          return true;
        },
      ),
      HuiShortcutRow(
        id: 'edit.nudge',
        spec: 'arrows',
        label: 'Nudge the selection by $huiNudgeStep blocks',
        matches: (ShellKey key) =>
            !key.mod && !key.alt && !key.shift && _isArrow(key.key),
        run: (HuiShortcutScope scope) => _nudge(scope, huiNudgeStep),
      ),
      HuiShortcutRow(
        id: 'edit.nudge.large',
        spec: 'Shift+arrows',
        label: 'Nudge by $huiNudgeStepLarge blocks',
        note: 'The primary is snapped and its step applied to the rest, so a '
            'group keeps its spacing.',
        matches: (ShellKey key) =>
            !key.mod && !key.alt && key.shift && _isArrow(key.key),
        run: (HuiShortcutScope scope) => _nudge(scope, huiNudgeStepLarge),
      ),
      HuiShortcutRow(
        id: 'view.visual',
        spec: 'V',
        label: 'Visual editor',
        matches: (ShellKey key) => _plain(key, 'v'),
        run: (HuiShortcutScope scope) => _setView(scope, EditorView.visual),
      ),
      HuiShortcutRow(
        id: 'view.preview',
        spec: 'P',
        label: 'Preview in 3D',
        matches: (ShellKey key) => _plain(key, 'p'),
        run: (HuiShortcutScope scope) => _setView(scope, EditorView.preview),
      ),
      HuiShortcutRow(
        id: 'view.code',
        spec: 'C',
        label: 'Code editor',
        matches: (ShellKey key) => _plain(key, 'c'),
        run: (HuiShortcutScope scope) => _setView(scope, EditorView.code),
      ),
      HuiShortcutRow(
        id: 'view.split',
        spec: 'S',
        label: 'Split view',
        matches: (ShellKey key) => _plain(key, 's'),
        run: (HuiShortcutScope scope) => _setView(scope, EditorView.split),
      ),
    ],
  ),
  const HuiShortcutGroup(
    title: 'Artboard',
    note: 'Bound on the canvas element, so click it once first. It consumes '
        'the event, which is what stops the global bindings firing twice.',
    rows: <HuiShortcutRow>[
      HuiShortcutRow(
        id: 'canvas.marquee',
        spec: 'Drag',
        label: 'Marquee-select from empty space',
      ),
      HuiShortcutRow(
        id: 'canvas.add',
        spec: 'Shift+Click',
        label: 'Add or remove one component',
      ),
      HuiShortcutRow(
        id: 'canvas.duplicate',
        spec: 'Alt+Drag',
        label: 'Duplicate the selection and drag the copies',
        note: 'The copy is made on the first move, so Alt-click leaves '
            'nothing behind.',
      ),
      HuiShortcutRow(
        id: 'canvas.pan',
        spec: 'Space+Drag',
        label: 'Pan',
        note: 'The middle mouse button pans without Space.',
      ),
      HuiShortcutRow(
        id: 'canvas.zoom',
        spec: 'Scroll',
        label: 'Zoom around the pointer',
      ),
      HuiShortcutRow(
        id: 'canvas.reset',
        spec: '0',
        label: 'Reset zoom and pan',
      ),
      HuiShortcutRow(
        id: 'canvas.fit',
        spec: 'F',
        label: 'Fit the menu to the viewport',
      ),
      HuiShortcutRow(
        id: 'canvas.delete',
        spec: 'Delete',
        label: 'Delete the selection immediately',
        note: 'No confirmation here: the gesture is local and undo is one '
            'keystroke away.',
      ),
    ],
  ),
  const HuiShortcutGroup(
    title: 'Preview stage',
    note: 'Bound on the 3D stage; click it once first.',
    rows: <HuiShortcutRow>[
      HuiShortcutRow(
        id: 'preview.orbit',
        spec: 'Drag',
        label: 'Orbit the camera',
      ),
      HuiShortcutRow(
        id: 'preview.pan',
        spec: 'Space+Drag',
        label: 'Pan the camera target',
        note: 'Middle-drag does the same.',
      ),
      HuiShortcutRow(
        id: 'preview.dolly',
        spec: 'Scroll',
        label: 'Dolly in and out',
      ),
      HuiShortcutRow(
        id: 'preview.reset',
        spec: '0',
        label: 'Reset the camera to the open position',
      ),
    ],
  ),
  const HuiShortcutGroup(
    title: 'Command palette',
    note: 'The palette lists only commands that can run right now, so a '
        'command missing from it is one this document has nothing to apply '
        'it to. This sheet is the complete list.',
    rows: <HuiShortcutRow>[
      HuiShortcutRow(
        id: 'palette.move',
        spec: '↑↓',
        label: 'Browse the results',
      ),
      HuiShortcutRow(
        id: 'palette.run',
        spec: 'Enter',
        label: 'Run the highlighted command',
      ),
      HuiShortcutRow(
        id: 'palette.close',
        spec: 'Esc',
        label: 'Close the palette',
      ),
    ],
  ),
];

/// Every row the document-level binder dispatches, flattened once.
final List<HuiShortcutRow> huiBoundShortcuts = <HuiShortcutRow>[
  for (final HuiShortcutGroup group in huiShortcutGroups)
    for (final HuiShortcutRow row in group.rows)
      if (row.matches != null) row,
];

final Map<String, HuiShortcutRow> _byId = <String, HuiShortcutRow>{
  for (final HuiShortcutGroup group in huiShortcutGroups)
    for (final HuiShortcutRow row in group.rows) row.id: row,
};

/// The platform-neutral spec for a row id, or null when the id is unknown —
/// a mistyped id costs a missing chip, never a wrong one.
String? huiShortcutSpec(String id) => _byId[id]?.spec;

class ShortcutSheet extends StatelessWidget {
  const ShortcutSheet({
    required this.onClose,
    this.apple = false,
    this.leaving = false,
    super.key,
  });

  final void Function() onClose;

  /// Renders the chips with Apple glyphs.
  final bool apple;

  /// The caller has started the dismissal and will unmount after the exit
  /// animation; see `_closeShortcuts` in editor_shell.dart.
  final bool leaving;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: classNames(<String?>[
          'hui-keys-scrim',
          leaving ? 'hui-anim-fade-out' : null,
        ]),
        events: dom.events<Null>(onClick: onClose),
        <Widget>[
          dom.div(
            classes: classNames(<String?>[
              'hui-keys-dialog',
              leaving ? 'hui-anim-out' : null,
            ]),
            attributes: const <String, String>{
              'role': 'dialog',
              'aria-modal': 'true',
              'aria-label': 'Keyboard shortcuts',
            },
            events: <String, EventCallback>{
              'click': (Object? event) => domStopPropagation(event),
            },
            <Widget>[_head(), _body(), _foot()],
          ),
        ],
      );

  Widget _head() => dom.header(
        classes: 'hui-keys-head',
        <Widget>[
          ArcaneIcon.keyboard(size: IconSize.sm),
          const dom.h2(
            classes: 'hui-keys-title',
            <Widget>[Text('Keyboard shortcuts')],
          ),
          const dom.span(classes: 'hui-keys-spacer', <Widget>[]),
          ArcaneKbd.combo(
            shortcutKeys('Esc', apple: apple),
            size: ComponentSize.sm,
          ),
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.iconSm,
            onPressed: onClose,
            attributes: const <String, String>{
              'aria-label': 'Close the shortcut sheet',
            },
            child: ArcaneIcon.x(size: IconSize.sm),
          ),
        ],
      );

  /// One column per group on a wide sheet, reflowing to one on a narrow one.
  /// The stagger is `pop`, not `rise`: this is a scroll box (06-motion.css
  /// rule 3).
  Widget _body() => dom.div(
        classes: 'hui-keys-body',
        <Widget>[
          dom.div(
            classes: 'hui-keys-columns hui-stagger',
            <Widget>[
              for (final HuiShortcutGroup group in huiShortcutGroups)
                _group(group),
            ],
          ),
        ],
      );

  Widget _group(HuiShortcutGroup group) => dom.section(
        classes: 'hui-keys-group',
        <Widget>[
          dom.h3(
            classes: 'hui-keys-group-title',
            <Widget>[Text(group.title)],
          ),
          if (group.note != null)
            dom.p(
              classes: 'hui-keys-group-note',
              <Widget>[Text(group.note!)],
            ),
          dom.ul(
            classes: 'hui-keys-list',
            <Widget>[
              for (final HuiShortcutRow row in group.rows) _row(row),
            ],
          ),
        ],
      );

  Widget _row(HuiShortcutRow row) => dom.li(
        classes: 'hui-keys-row',
        <Widget>[
          dom.span(
            classes: 'hui-keys-text',
            <Widget>[
              dom.span(classes: 'hui-keys-label', <Widget>[Text(row.label)]),
              if (row.note != null)
                dom.span(classes: 'hui-keys-note', <Widget>[Text(row.note!)]),
            ],
          ),
          ArcaneKbd.combo(
            shortcutKeys(row.spec, apple: apple),
            size: ComponentSize.sm,
          ),
        ],
      );

  Widget _foot() => dom.footer(
        classes: 'hui-keys-foot',
        <Widget>[
          dom.span(<Widget>[
            Text('Press ? any time. '
                '${shortcutLabel('mod+K', apple: apple)} runs any command by '
                'name.'),
          ]),
        ],
      );
}
