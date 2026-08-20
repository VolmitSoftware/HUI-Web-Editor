/// The centre-pane mode segmented control.
///
/// Four modes, the same four for every document kind: the kind's editing
/// surface, its in-game rendering, the JSON, and the two side by side. A kind
/// that cannot serve one of them keeps its place in the strip and says why on
/// hover — a switcher whose shape changed with the open document taught the
/// user that modes come and go, which is exactly the confusion this replaced.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../state/editor_store.dart';
import '../common/class_names.dart';

class ViewSwitcher extends StatelessWidget {
  const ViewSwitcher({
    required this.view,
    required this.surfaceLabel,
    required this.unavailableReason,
    required this.onChanged,
    super.key,
  });

  final EditorView view;

  /// What the visual mode is called for the open kind ('Canvas', 'Sidebar').
  final String surfaceLabel;

  /// Why the open kind cannot enter a mode, or null when it can.
  final String? Function(EditorView view) unavailableReason;

  final void Function(EditorView view) onChanged;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-view-switcher',
    attributes: const <String, String>{'aria-label': 'Editor mode'},
    <Widget>[
      ArcaneToggleGroup(
        id: 'hui-view-switcher',
        value: view.name,
        variant: ToggleGroupVariant.outline,
        size: ToggleGroupSize.sm,
        onChanged: _onChanged,
        items: <ToggleGroupItem>[
          for (final EditorView value in EditorView.values) _item(value),
        ],
      ),
    ],
  );

  static String labelOf(EditorView value) => switch (value) {
    EditorView.visual => 'Visual',
    EditorView.preview => 'Preview',
    EditorView.code => 'Code',
    EditorView.split => 'Split',
  };

  static Widget iconOf(EditorView value) => switch (value) {
    EditorView.visual => ArcaneIcon.eye(size: IconSize.sm),
    EditorView.preview => ArcaneIcon.rotate3d(size: IconSize.sm),
    EditorView.code => ArcaneIcon.code(size: IconSize.sm),
    EditorView.split => ArcaneIcon.columns2(size: IconSize.sm),
  };

  String _titleOf(EditorView value, String? reason) {
    if (reason != null) return reason;
    return switch (value) {
      EditorView.visual => 'Visual — the $surfaceLabel surface',
      EditorView.preview => 'Preview — rendered the way the server renders it',
      EditorView.code => 'Code — the document JSON',
      EditorView.split => 'Split — $surfaceLabel and JSON side by side',
    };
  }

  /// A mode the kind cannot serve stays clickable on purpose: the click is
  /// what surfaces the reason as a message, and a disabled button in this
  /// runtime swallows the pointer before its own tooltip can fire.
  void _onChanged(String? value) {
    for (final EditorView candidate in EditorView.values) {
      if (candidate.name == value) {
        onChanged(candidate);
        return;
      }
    }
  }

  ToggleGroupItem _item(EditorView value) {
    final String? reason = unavailableReason(value);
    return ToggleGroupItem(
      value: value.name,
      child: dom.span(
        classes: classNames(<String?>[
          'hui-view-switcher-item',
          reason == null ? null : 'is-unavailable',
        ]),
        attributes: <String, String>{
          'title': _titleOf(value, reason),
          if (reason != null) 'aria-disabled': 'true',
        },
        <Widget>[
          iconOf(value),
          dom.span(classes: 'hui-view-label', <Widget>[Text(labelOf(value))]),
        ],
      ),
    );
  }
}
