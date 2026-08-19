/// PlaceholderAPI helper for the toggle condition field.
///
/// The catalogue ships Gloss's own three placeholders plus a handful of common
/// PAPI examples. Picking one replaces the condition outright, because the
/// condition is compared whole with `equalsIgnoreCase` — there is no expression
/// language to append to.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../services/catalogs.dart';
import '../common/common.dart';

class PlaceholderPicker extends StatefulWidget {
  const PlaceholderPicker({
    required this.catalogs,
    required this.onPicked,
    this.label = 'Placeholders',
    super.key,
  });

  final HuiCatalogs catalogs;

  /// Receives the raw placeholder token, e.g. `%gloss_available%`.
  final void Function(String placeholder) onPicked;
  final String label;

  @override
  State<PlaceholderPicker> createState() => _PlaceholderPickerState();
}

class _PlaceholderPickerState extends State<PlaceholderPicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> entries = component.catalogs.placeholders;
    return ArcanePopover(
      isOpen: _open,
      onOpenChange: (bool open) => setState(() => _open = open),
      position: FloatingPosition.bottom,
      trigger: Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.hash(size: IconSize.sm),
        attributes: <String, String>{
          'aria-label': component.label,
          'aria-expanded': _open ? 'true' : 'false',
          // Inside a floating container the trigger's next sibling IS the
          // popup, so the legacy accordion binder would write `display` onto
          // it and fight the popover script. `data-arcane-interactive` is that
          // binder's opt-out (accordion_scripts.dart:8); the popover script
          // keys on `arcanePopoverInteractive` and is unaffected.
          'data-arcane-interactive': 'true',
        },
        child: Text(component.label),
      ),
      content: dom.div(classes: 'hui-placeholder-list', <Widget>[
        const HuiEyebrow('Placeholders'),
        if (entries.isEmpty)
          const dom.p(classes: 'hui-placeholder-empty', <Widget>[
            Text(
              'The placeholder catalogue could not be loaded. Type the '
              'placeholder by hand, including the surrounding % signs.',
            ),
          ])
        else
          for (final (String, String) entry in entries) _row(entry),
        const dom.p(classes: 'hui-placeholder-foot', <Widget>[
          Text(
            'Anything outside Gloss needs PlaceholderAPI installed on the '
            'server. Without it the condition string is compared literally.',
          ),
        ]),
      ]),
    );
  }

  Widget _row((String, String) entry) => dom.button(
    classes: 'hui-placeholder-row',
    attributes: <String, String>{
      'type': 'button',
      'aria-label': 'Use ${entry.$1}',
    },
    events: <String, EventCallback>{
      'click': (_) {
        setState(() => _open = false);
        component.onPicked(entry.$1);
      },
    },
    <Widget>[
      dom.span(classes: 'hui-placeholder-key', <Widget>[Text(entry.$1)]),
      dom.span(classes: 'hui-placeholder-desc', <Widget>[Text(entry.$2)]),
    ],
  );
}
