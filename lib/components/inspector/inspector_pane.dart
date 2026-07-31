/// The right-hand inspector.
///
/// Two modes: menu properties when nothing is selected, component properties
/// when something is. The pane listens to the store and the image library
/// itself, so it stays correct no matter how the shell composes it.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import 'component_inspector.dart';
import 'inspector_session.dart';
import 'menu_inspector.dart';

class InspectorPane extends StatefulWidget {
  const InspectorPane({
    required this.store,
    required this.images,
    this.catalogs,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;

  /// Boot snapshot from the shell. `store.catalogs` wins whenever it holds
  /// more, which is how an imported custom item catalog reaches the inspector:
  /// it is swapped into the store, not back into the shell.
  final HuiCatalogs? catalogs;

  @override
  State<InspectorPane> createState() => _InspectorPaneState();
}

class _InspectorPaneState extends State<InspectorPane> {
  /// Survives selection changes and type switches for the whole session.
  final InspectorSession _session = InspectorSession();

  @override
  void initState() {
    super.initState();
    component.store.addListener(_onChanged);
    component.images.addListener(_onChanged);
  }

  @override
  void didUpdateComponent(InspectorPane oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onChanged);
      component.store.addListener(_onChanged);
    }
    if (!identical(oldComponent.images, component.images)) {
      oldComponent.images.removeListener(_onChanged);
      component.images.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    component.store.removeListener(_onChanged);
    component.images.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final EditorStore store = component.store;
    final HuiCatalogs catalogs =
        huiFreshestCatalogs(store.catalogs, component.catalogs);
    final HuiComponent? selected = store.selected;
    // The shell already renders the scrolling `<aside class="hui-pane
    // hui-inspector">` cell around this slot, so the pane root is a plain
    // filler div: no second scroll container, no second border.
    return dom.div(
      classes: 'hui-inspector-pane',
      <Widget>[
        if (selected == null)
          MenuInspector(store: store)
        else
          ComponentInspector(
            // Keyed by id so switching selection rebuilds the id draft state
            // instead of carrying the previous component's text across.
            key: ValueKey<String>('inspector-${selected.id}'),
            store: store,
            images: component.images,
            catalogs: catalogs,
            session: _session,
            target: selected,
          ),
      ],
    );
  }
}
