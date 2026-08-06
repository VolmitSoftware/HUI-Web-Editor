/// The right-hand inspector.
///
/// Two modes: menu properties when nothing is selected, component properties
/// when something is. The pane listens to the store and the image library
/// itself, so it stays correct no matter how the shell composes it.
library;

import 'dart:js_interop';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../panels/preview_sim_panel.dart';
import 'component_inspector.dart';
import 'inspector_session.dart';
import 'menu_inspector.dart';
import 'preview_element_editor.dart';
import 'preview_match_editor.dart';

/// Dispatched by the canvas on a double click (`canvas_interactions.dart:274`).
const String huiInspectorFocusEvent = 'hui-inspector-focus';

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
  ///
  /// Null means the fetch has not settled yet — which is the only honest signal
  /// for a skeleton, because a failed fetch still resolves to a real (empty)
  /// catalogue and must not leave a placeholder up forever.
  final HuiCatalogs? catalogs;

  @override
  State<InspectorPane> createState() => _InspectorPaneState();
}

class _InspectorPaneState extends State<InspectorPane> {
  /// Survives selection changes and type switches for the whole session.
  final InspectorSession _session = InspectorSession();

  /// Kept as a [JSFunction] because `removeEventListener` only matches the
  /// identical JS callback; converting the same closure twice leaks the first.
  JSFunction? _focusListener;

  @override
  void initState() {
    super.initState();
    component.store.addListener(_onChanged);
    component.images.addListener(_onChanged);
    _installFocusListener();
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
    _removeFocusListener();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _installFocusListener() {
    final JSFunction listener = ((web.Event _) => _takeFocus()).toJS;
    _focusListener = listener;
    web.document.addEventListener(huiInspectorFocusEvent, listener);
  }

  void _removeFocusListener() {
    final JSFunction? listener = _focusListener;
    _focusListener = null;
    if (listener == null) return;
    web.document.removeEventListener(huiInspectorFocusEvent, listener);
  }

  /// The canvas selects first and dispatches second, so the component inspector
  /// this focuses may not have rendered yet. One retry after a frame covers the
  /// rebuild; more than that would be fighting something else.
  void _takeFocus([bool retry = true]) {
    web.document.querySelector('.hui-inspector')?.scrollTop = 0;
    final web.Element? field =
        web.document.getElementById(huiComponentIdFieldId);
    if (field == null) {
      if (retry) web.window.requestAnimationFrame(_retryFocus.toJS);
      return;
    }
    if (!field.isA<web.HTMLInputElement>()) return;
    final web.HTMLInputElement input = field as web.HTMLInputElement;
    input.focus();
    input.select();
  }

  void _retryFocus(double _) {
    if (mounted) _takeFocus(false);
  }

  @override
  Widget build(BuildContext context) {
    final EditorStore store = component.store;
    // The shell already renders the scrolling `<aside class="hui-pane
    // hui-inspector">` cell around this slot, so the pane root is a plain
    // filler div: no second scroll container, no second border.
    return dom.div(
      classes: 'hui-inspector-pane',
      <Widget>[if (store.isPreviewDoc) ..._previewBody(store) else ..._menuBody(store)],
    );
  }

  List<Widget> _previewBody(EditorStore store) {
    final List<Widget> body = <Widget>[
      // The simulation panel is the previewCard view's own HUD-ish chrome
      // (task E8): meaningless in the code view of the same document, where
      // there is nothing to animate.
      if (store.view == EditorView.previewCard)
        PreviewSimPanel(store: store, catalogs: component.catalogs),
    ];
    final int? index = store.previewSelectedIndex;
    final HuiPreviewElement? element = store.previewSelectedElement;
    if (index == null || element == null) {
      body.add(PreviewMatchEditor(store: store));
    } else {
      // Keyed by index so switching selection rebuilds local draft state
      // instead of carrying the previous element's text across.
      body.add(PreviewElementEditor(
        key: ValueKey<int>(index),
        store: store,
        index: index,
        element: element,
      ));
    }
    return body;
  }

  List<Widget> _menuBody(EditorStore store) {
    final HuiCatalogs catalogs =
        huiFreshestCatalogs(store.catalogs, component.catalogs);
    final HuiComponent? selected = store.selected;
    if (selected == null) return <Widget>[MenuInspector(store: store)];
    return <Widget>[
      ComponentInspector(
        // Keyed by id so switching selection rebuilds the id draft state
        // instead of carrying the previous component's text across.
        key: ValueKey<String>('inspector-${selected.id}'),
        store: store,
        images: component.images,
        catalogs: catalogs,
        catalogsLoading: component.catalogs == null && !catalogs.loaded,
        session: _session,
        target: selected,
      ),
    ];
  }
}
