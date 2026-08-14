/// The centre-pane view segmented control.
///
/// The items are whichever views the active document kind actually has a
/// surface for ([EditorStore.availableViews]), not the whole enum: a menu has
/// no card surface and a container-preview document has neither a component
/// canvas nor a 3D preview, so offering either would be offering a dead end.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../state/editor_store.dart';

class ViewSwitcher extends StatelessWidget {
  const ViewSwitcher({
    required this.view,
    required this.views,
    required this.onChanged,
    super.key,
  });

  final EditorView view;

  /// In switcher order; the store decides which kind gets which.
  final List<EditorView> views;

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
          for (final EditorView value in views)
            _item(value, _labelOf(value), _iconOf(value)),
        ],
      ),
    ],
  );

  static String _labelOf(EditorView value) => switch (value) {
    EditorView.visual => 'Visual',
    EditorView.preview => 'Preview',
    EditorView.code => 'Code',
    EditorView.split => 'Split',
    EditorView.previewCard => 'Card',
    EditorView.board => 'Flow map',
  };

  static Widget _iconOf(EditorView value) => switch (value) {
    EditorView.visual => ArcaneIcon.eye(size: IconSize.sm),
    EditorView.preview => ArcaneIcon.rotate3d(size: IconSize.sm),
    EditorView.code => ArcaneIcon.code(size: IconSize.sm),
    EditorView.split => ArcaneIcon.columns2(size: IconSize.sm),
    EditorView.previewCard => ArcaneIcon.layoutGrid(size: IconSize.sm),
    EditorView.board => ArcaneIcon.workflow(size: IconSize.sm),
  };

  void _onChanged(String? value) {
    for (final EditorView candidate in views) {
      if (candidate.name == value) {
        onChanged(candidate);
        return;
      }
    }
  }

  ToggleGroupItem _item(EditorView value, String label, Widget icon) =>
      ToggleGroupItem(
        value: value.name,
        child: dom.span(classes: 'hui-view-switcher-item', <Widget>[
          icon,
          dom.span(classes: 'hui-view-label', <Widget>[Text(label)]),
        ]),
      );
}
