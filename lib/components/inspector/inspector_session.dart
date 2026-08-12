/// Per-session memory for type switches.
///
/// Switching an icon from `text` to `item`, or an action from `command` to
/// `sound`, throws away fields the other shape does not have. The old editor
/// simply lost them. Here the outgoing value is parked under its own type key
/// and handed back if the user switches away and back, so a mis-click is free.
///
/// This is deliberately session-only: nothing is persisted and nothing is
/// exported. Slot keys are `<componentId>:<slot>` so two components never share
/// a cache entry.
library;

import '../../config/defaults.dart';
import '../../model/model.dart';

class InspectorSession {
  final Map<String, Map<String, HuiIcon>> _icons =
      <String, Map<String, HuiIcon>>{};
  final Map<String, Map<String, HuiAction>> _actions =
      <String, Map<String, HuiAction>>{};

  static String iconSlot(String componentId, String slot) =>
      '$componentId:$slot';

  static String actionSlot(String componentId, String list, int index) =>
      '$componentId:$list:$index';

  /// Parks [icon] under its own type for [slot].
  void rememberIcon(String slot, HuiIcon? icon) {
    if (icon == null) return;
    (_icons[slot] ??= <String, HuiIcon>{})[icon.type] = icon.copy();
  }

  /// The icon [slot] last held for [type], or null when it never held one.
  HuiIcon? recallIcon(String slot, String type) => _icons[slot]?[type]?.copy();

  /// Remembers the outgoing icon and returns the incoming one: a cached value
  /// when there is one, otherwise a fresh default seeded from the outgoing
  /// icon's paths where the two shapes overlap.
  HuiIcon switchIcon(String slot, HuiIcon? current, String nextType) {
    rememberIcon(slot, current);
    final HuiIcon? cached = recallIcon(slot, nextType);
    if (cached != null) return cached;
    return _seedIcon(current, nextType);
  }

  /// `textImage` and `animatedTextImage` both address the same image library,
  /// so a switch between them carries the paths over rather than starting empty.
  HuiIcon _seedIcon(HuiIcon? current, String nextType) {
    if (current is HuiTextImageIcon &&
        nextType == 'animatedTextImage' &&
        current.path.isNotEmpty) {
      return HuiAnimatedImageIcon(
        <String>[current.path],
        huiDefaultAnimationSpeed,
        current.style?.copy(),
      );
    }
    if (current is HuiAnimatedImageIcon &&
        nextType == 'textImage' &&
        current.source.isNotEmpty) {
      return HuiTextImageIcon(current.source.first, current.style?.copy());
    }
    final HuiIcon next = createDefaultIcon(nextType);
    if (next is! HuiEntityIcon) {
      next.style = current?.style?.copy();
    }
    return next;
  }

  void rememberAction(String slot, HuiAction? action) {
    if (action == null) return;
    (_actions[slot] ??= <String, HuiAction>{})[action.type] = action.copy();
  }

  HuiAction? recallAction(String slot, String type) =>
      _actions[slot]?[type]?.copy();

  HuiAction switchAction(String slot, HuiAction? current, String nextType) {
    rememberAction(slot, current);
    final HuiAction? cached = recallAction(slot, nextType);
    if (cached != null) {
      cached.trigger = current?.trigger ?? cached.trigger;
      return cached;
    }
    final HuiAction next = createDefaultAction(nextType);
    next.trigger = current?.trigger ?? 'any';
    return next;
  }

  /// Called when a component is renamed so its cached values follow the new id.
  void renameComponent(String oldId, String newId) {
    _rekey(_icons, oldId, newId);
    _rekey(_actions, oldId, newId);
  }

  static void _rekey<T>(
    Map<String, Map<String, T>> store,
    String oldId,
    String newId,
  ) {
    final String oldPrefix = '$oldId:';
    final List<String> keys = store.keys
        .where((String key) => key.startsWith(oldPrefix))
        .toList();
    for (final String key in keys) {
      final Map<String, T>? value = store.remove(key);
      if (value != null) {
        store['$newId:${key.substring(oldPrefix.length)}'] = value;
      }
    }
  }
}
