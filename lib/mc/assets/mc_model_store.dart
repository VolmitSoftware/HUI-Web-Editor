/// Where the resolver reads raw model JSON from.
///
/// The pack ships one `models.json` with three maps keyed by id; the resolver
/// never touches the network or the file system itself, so the VM tests build
/// the same store over the fixture folder.
library;

import 'mc_model_json.dart';

abstract interface class McModelStore {
  /// `block/stone`, `item/apple`, `builtin/generated` (returns null for the
  /// builtin sentinels; the resolver special-cases them by name).
  McModelJson? model(String id);

  /// The root node of `items/<id>.json`.
  McItemDefinitionNode? item(String id);

  McBlockstateJson? blockstate(String id);
}

final class McJsonModelStore implements McModelStore {
  McJsonModelStore._(this._models, this._items, this._blockstates);

  /// `{"models": {id: raw}, "items": {id: rawFile}, "blockstates": {id: raw}}`.
  factory McJsonModelStore.fromJson(Map<String, Object?> json) {
    Map<String, Object?> section(String key) =>
        (json[key] as Map<String, Object?>?) ?? const <String, Object?>{};
    return McJsonModelStore._(
      section('models'),
      section('items'),
      section('blockstates'),
    );
  }

  final Map<String, Object?> _models;
  final Map<String, Object?> _items;
  final Map<String, Object?> _blockstates;
  final Map<String, McModelJson> _modelCache = <String, McModelJson>{};
  final Map<String, McItemDefinitionNode> _itemCache =
      <String, McItemDefinitionNode>{};
  final Map<String, McBlockstateJson> _blockstateCache =
      <String, McBlockstateJson>{};

  int get modelCount => _models.length;
  int get itemCount => _items.length;
  int get blockstateCount => _blockstates.length;
  Iterable<String> get itemIds => _items.keys;

  @override
  McModelJson? model(String id) {
    final McModelJson? cached = _modelCache[id];
    if (cached != null) return cached;
    final Object? raw = _models[id];
    if (raw is! Map<String, Object?>) return null;
    return _modelCache[id] = McModelJson.fromJson(raw);
  }

  @override
  McItemDefinitionNode? item(String id) {
    final McItemDefinitionNode? cached = _itemCache[id];
    if (cached != null) return cached;
    final Object? raw = _items[id];
    if (raw is! Map<String, Object?>) return null;
    final Object? model = raw['model'];
    if (model is! Map<String, Object?>) return null;
    return _itemCache[id] = McItemDefinitionNode.fromJson(model);
  }

  @override
  McBlockstateJson? blockstate(String id) {
    final McBlockstateJson? cached = _blockstateCache[id];
    if (cached != null) return cached;
    final Object? raw = _blockstates[id];
    if (raw is! Map<String, Object?>) return null;
    return _blockstateCache[id] = McBlockstateJson.fromJson(raw);
  }
}
