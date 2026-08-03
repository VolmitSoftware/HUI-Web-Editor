/// Cmd/Ctrl+K command palette.
///
/// Hand-built rather than `ArcaneCommand`: that component's renderer wires no
/// Dart callbacks at all (items only get `data-arcane-action` strings for href
/// navigation and closing), so `CommandItem.onSelect` never fires and every
/// editor command would be dead. The shape below deliberately mirrors the
/// framework component — groups, headings, shortcut chips, keyword search — so
/// it can be swapped back if the renderer gains callback support.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:web/web.dart' as web;

import '../common/class_names.dart';
import 'shell_actions.dart';
import 'shell_keys.dart';

class ShellCommandPalette extends StatefulWidget {
  const ShellCommandPalette({
    required this.actions,
    required this.onClose,
    this.apple = false,
    super.key,
  });

  final List<ShellAction> actions;
  final void Function() onClose;

  /// Renders shortcut chips with Apple glyphs.
  final bool apple;

  @override
  State<ShellCommandPalette> createState() => _ShellCommandPaletteState();
}

class _ShellCommandPaletteState extends State<ShellCommandPalette> {
  static const String _inputId = 'hui-cmd-input';

  String _query = '';
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // The `autofocus` attribute is not enough. The palette is inserted long
    // after the document loaded, and whatever opened it — an Arcane button
    // whose feedback script `preventDefault`s mousedown, or the runtime's own
    // hidden ⌘K trigger — leaves focus on `body`. Measured with autofocus
    // alone: typing went nowhere, arrows did not move the selection and
    // Escape did not close, because every one of those is a keydown handler
    // on this input.
    context.binding.addPostFrameCallback(() {
      final web.Element? input = web.document.getElementById(_inputId);
      (input as web.HTMLElement?)?.focus();
    });
  }

  List<ShellAction> get _matches {
    final List<ShellAction> enabled = component.actions
        .where((ShellAction action) => action.enabled)
        .toList();
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return enabled;
    final List<String> terms = query.split(RegExp(r'\s+'));
    return enabled.where((ShellAction action) {
      final String haystack = action.haystack;
      return terms.every(haystack.contains);
    }).toList();
  }

  void _move(int delta) {
    final int count = _matches.length;
    if (count == 0) return;
    setState(() {
      _index = (_index + delta) % count;
      if (_index < 0) _index += count;
    });
  }

  void _run(ShellAction action) {
    component.onClose();
    action.run();
  }

  void _runSelected() {
    final List<ShellAction> matches = _matches;
    if (matches.isEmpty) return;
    _run(matches[_index.clamp(0, matches.length - 1)]);
  }

  void _onKeyDown(Object? event) {
    switch (domEventKey(event)) {
      case 'ArrowDown':
        domPreventDefault(event);
        domStopPropagation(event);
        _move(1);
      case 'ArrowUp':
        domPreventDefault(event);
        domStopPropagation(event);
        _move(-1);
      case 'Enter':
        domPreventDefault(event);
        domStopPropagation(event);
        _runSelected();
      case 'Escape':
        domPreventDefault(event);
        domStopPropagation(event);
        component.onClose();
      case 'Tab':
        domPreventDefault(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ShellAction> matches = _matches;
    final int selected =
        matches.isEmpty ? -1 : _index.clamp(0, matches.length - 1);
    return dom.div(
      classes: 'hui-cmd-scrim',
      events: dom.events<Null>(onClick: component.onClose),
      <Widget>[
        dom.div(
          classes: 'hui-cmd-dialog',
          attributes: const <String, String>{
            'role': 'dialog',
            'aria-modal': 'true',
            'aria-label': 'Command palette',
          },
          events: <String, EventCallback>{
            'click': (Object? event) => domStopPropagation(event),
          },
          <Widget>[
            _searchRow(),
            _list(matches, selected),
            _footer(),
          ],
        ),
      ],
    );
  }

  Widget _searchRow() => dom.div(
        classes: 'hui-cmd-search',
        <Widget>[
          ArcaneIcon.search(size: IconSize.sm),
          dom.input<String>(
            type: dom.InputType.text,
            id: _inputId,
            classes: 'hui-cmd-input',
            attributes: const <String, String>{
              'placeholder': 'Search commands',
              'aria-label': 'Search commands',
              'autofocus': '',
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
            onInput: (String value) => setState(() {
              _query = value;
              _index = 0;
            }),
            events: <String, EventCallback>{'keydown': _onKeyDown},
          ),
          ArcaneKbd.combo(shortcutKeys('Esc', apple: component.apple),
              size: ComponentSize.sm),
        ],
      );

  Widget _list(List<ShellAction> matches, int selected) {
    if (matches.isEmpty) {
      return dom.div(
        classes: 'hui-cmd-list',
        <Widget>[
          dom.p(
            classes: 'hui-cmd-empty',
            <Widget>[Text('No commands match "${_query.trim()}".')],
          ),
        ],
      );
    }
    final List<Widget> rows = <Widget>[];
    String? group;
    for (int i = 0; i < matches.length; i++) {
      final ShellAction action = matches[i];
      if (action.group != group) {
        group = action.group;
        rows.add(
          dom.div(classes: 'hui-cmd-heading', <Widget>[Text(group)]),
        );
      }
      rows.add(_row(action, i == selected));
    }
    return dom.div(
      classes: 'hui-cmd-list',
      attributes: const <String, String>{'role': 'listbox'},
      rows,
    );
  }

  Widget _row(ShellAction action, bool active) {
    final String? shortcut = action.shortcut;
    return dom.div(
      classes: classNames(<String?>['hui-cmd-item', active ? 'is-active' : null]),
      attributes: <String, String>{
        'role': 'option',
        'aria-selected': active ? 'true' : 'false',
        'tabindex': '-1',
      },
      events: dom.events<Null>(onClick: () => _run(action)),
      <Widget>[
        dom.span(
          classes: 'hui-cmd-icon',
          <Widget>[if (action.icon != null) action.icon!],
        ),
        dom.span(classes: 'hui-cmd-label', <Widget>[Text(action.label)]),
        if (shortcut != null)
          ArcaneKbd.combo(
            shortcutKeys(shortcut, apple: component.apple),
            size: ComponentSize.sm,
          ),
      ],
    );
  }

  Widget _footer() => const dom.div(
        classes: 'hui-cmd-footer',
        <Widget>[
          dom.span(<Widget>[Text('Up / Down to browse')]),
          dom.span(<Widget>[Text('Enter to run')]),
          dom.span(<Widget>[Text('Esc to close')]),
        ],
      );
}
