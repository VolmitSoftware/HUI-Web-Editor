/// Ambient access to the [EditorStore] plus the rebuild helper every panel uses.
///
/// The scope itself only carries the store instance; it never changes identity
/// during a session, so `updateShouldNotify` is effectively always false and
/// rebuilds come from listening to the store, not from the inherited component.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import 'editor_store.dart';

class EditorScope extends InheritedWidget {
  const EditorScope({required this.store, required super.child, super.key});

  final EditorStore store;

  /// Throws when used outside the editor tree — that is a wiring bug, not a
  /// runtime condition worth degrading for.
  static EditorStore of(BuildContext context) {
    final EditorStore? store = maybeOf(context);
    if (store == null) {
      throw StateError(
        'EditorScope.of() called outside an EditorScope. Wrap the editor tree '
        'in EditorScope(store: ..., child: ...).',
      );
    }
    return store;
  }

  static EditorStore? maybeOf(BuildContext context) => context
      .dependOnInheritedComponentOfExactType<EditorScope>()
      ?.store;

  @override
  bool updateShouldNotify(EditorScope oldComponent) =>
      !identical(oldComponent.store, store);
}

/// Rebuilds [builder] whenever the store notifies. Use this instead of reading
/// the store in a `StatelessWidget.build` without listening, which would render
/// stale state after a mutation.
class EditorBuilder extends StatelessWidget {
  const EditorBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, EditorStore store) builder;

  @override
  Widget build(BuildContext context) {
    final EditorStore store = EditorScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext inner) => builder(inner, store),
    );
  }
}
