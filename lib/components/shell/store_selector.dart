/// Rebuild-narrowing listener.
///
/// The store notifies on every pointer move of a canvas drag. Rebuilding the
/// whole top bar or status bar at that rate is wasted work, so chrome widgets
/// subscribe through a selector and only rebuild when the value they actually
/// render changes. [T] must have value equality (records, strings, enums).
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/jaspr.dart' show Listenable;

class StoreSelector<T> extends StatefulWidget {
  const StoreSelector({
    required this.listenable,
    required this.selector,
    required this.builder,
    super.key,
  });

  final Listenable listenable;
  final T Function() selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<StoreSelector<T>> createState() => _StoreSelectorState<T>();
}

class _StoreSelectorState<T> extends State<StoreSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = component.selector();
    component.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateComponent(covariant StoreSelector<T> oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.listenable, component.listenable)) {
      oldComponent.listenable.removeListener(_onChanged);
      component.listenable.addListener(_onChanged);
    }
    _value = component.selector();
  }

  @override
  void dispose() {
    component.listenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final T next = component.selector();
    if (next == _value) return;
    setState(() {
      _value = next;
    });
  }

  @override
  Widget build(BuildContext context) => component.builder(context, _value);
}
