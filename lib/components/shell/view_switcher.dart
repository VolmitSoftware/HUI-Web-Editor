/// Visual / Code / Split segmented control.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../state/editor_store.dart';

class ViewSwitcher extends StatelessWidget {
  const ViewSwitcher({required this.view, required this.onChanged, super.key});

  final EditorView view;
  final void Function(EditorView view) onChanged;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-view-switcher',
        attributes: const <String, String>{'aria-label': 'Editor view'},
        <Widget>[
          ArcaneToggleGroup(
            id: 'hui-view-switcher',
            value: view.name,
            variant: ToggleGroupVariant.outline,
            size: ToggleGroupSize.sm,
            onChanged: _onChanged,
            items: <ToggleGroupItem>[
              _item(EditorView.visual, 'Visual', ArcaneIcon.eye(size: IconSize.sm)),
              _item(EditorView.code, 'Code', ArcaneIcon.code(size: IconSize.sm)),
              _item(
                EditorView.split,
                'Split',
                ArcaneIcon.columns2(size: IconSize.sm),
              ),
            ],
          ),
        ],
      );

  void _onChanged(String? value) {
    for (final EditorView candidate in EditorView.values) {
      if (candidate.name == value) {
        onChanged(candidate);
        return;
      }
    }
  }

  ToggleGroupItem _item(EditorView value, String label, Widget icon) =>
      ToggleGroupItem(
        value: value.name,
        child: dom.span(
          classes: 'hui-view-switcher-item',
          <Widget>[
            icon,
            dom.span(classes: 'hui-view-label', <Widget>[Text(label)]),
          ],
        ),
      );
}
