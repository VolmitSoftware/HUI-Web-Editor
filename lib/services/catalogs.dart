/// Static Minecraft material and sound catalogs plus the placeholder cheat
/// sheet, loaded from `web/assets/catalog/` at boot.
///
/// The URLs are relative on purpose so the bundle works from any origin
/// (the hosted site today, local static serving during development) — nothing
/// may hard-code an origin or a leading slash.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/gloss_text.dart' show GlossEmojiEntry;
import '../logic/preview_sim.dart';
import 'storage_service.dart';

/// One material registry entry.
///
/// [key] is the lowercase registry key the plugin's `Material.matchMaterial`
/// accepts. [texture] is a 16x16 PNG data URI when the shipped sprite atlas
/// covers the key, and null for keys harvested from the server API enum alone
/// (newer blocks, technical states, and non-item materials have no sprite).
class MaterialEntry {
  const MaterialEntry(this.key, this.texture);

  final String key;
  final String? texture;

  @override
  String toString() => 'MaterialEntry($key)';
}

/// One item exported by a custom-item plugin through `/holoui item export`.
///
/// [id] is kept exactly as the provider spelled it — several providers look ids
/// up in case-sensitive maps, and MMOItems ids are conventionally uppercase.
class CustomItemEntry {
  const CustomItemEntry({
    required this.provider,
    required this.id,
    this.name,
    this.material,
  });

  final String provider;
  final String id;

  /// The provider's display name, when it offers one.
  final String? name;

  /// Lowercase vanilla key of the resolved stack's base material, used to draw
  /// an approximate sprite. Null when the export could not resolve one.
  final String? material;

  String get label => name ?? id;

  @override
  String toString() => 'CustomItemEntry($provider, $id)';
}

/// The catalog `/holoui item export` writes to
/// `plugins/holoui/custom-items.json`.
///
/// Entirely optional: the editor is a static offline page, so a missing catalog
/// is silent and every id stays hand-typable. Its only jobs are autocomplete,
/// an approximate canvas sprite, and an informational "not in your export"
/// hint.
class HuiCustomItemCatalog {
  HuiCustomItemCatalog._({
    required List<CustomItemEntry> items,
    required Map<String, List<CustomItemEntry>> byId,
    required Map<String, int> countByProvider,
    required List<String> providers,
    required this.generated,
  }) : _items = items,
       _byId = byId,
       _countByProvider = countByProvider,
       _providers = providers;

  final List<CustomItemEntry> _items;
  final Map<String, List<CustomItemEntry>> _byId;

  /// Precomputed because the inspector reads it on every keystroke.
  final Map<String, int> _countByProvider;
  final List<String> _providers;

  /// Epoch milliseconds the export was written, or 0 when the file omits it.
  final int generated;

  /// `localStorage` slot for a hand-imported catalog, kept as the raw body so a
  /// future parser change re-reads it rather than a stale decoded shape.
  static const String storageKey = 'gloss.custom-items';

  static final HuiCustomItemCatalog _empty = HuiCustomItemCatalog._(
    items: const <CustomItemEntry>[],
    byId: const <String, List<CustomItemEntry>>{},
    countByProvider: const <String, int>{},
    providers: const <String>[],
    generated: 0,
  );

  factory HuiCustomItemCatalog.empty() => _empty;

  List<CustomItemEntry> get items => _items;

  /// Provider ids present in the export, in file order.
  List<String> get providers => _providers;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  /// Entries one provider contributes; the whole catalog for `auto` or blank.
  int countFor(String provider) {
    final String wanted = provider.trim().toLowerCase();
    if (wanted.isEmpty || wanted == 'auto') return _items.length;
    return _countByProvider[wanted] ?? 0;
  }

  /// Exact, case-sensitive id match. [provider] may be `auto`, blank, or a
  /// provider id; the first two match any provider.
  CustomItemEntry? entry(String provider, String id) {
    final List<CustomItemEntry>? candidates = _byId[id];
    if (candidates == null) return null;
    final String wanted = provider.trim().toLowerCase();
    if (wanted.isEmpty || wanted == 'auto') return candidates.first;
    for (final CustomItemEntry candidate in candidates) {
      if (candidate.provider == wanted) return candidate;
    }
    return null;
  }

  bool contains(String provider, String id) => entry(provider, id) != null;

  /// Substring match over id and display name, ranked prefix-first, optionally
  /// narrowed to one provider. The needle is folded; the entries are not.
  List<CustomItemEntry> search(
    String query, {
    String? provider,
    int limit = 60,
  }) {
    final String wanted = (provider ?? '').trim().toLowerCase();
    final bool anyProvider = wanted.isEmpty || wanted == 'auto';
    final String needle = query.trim().toLowerCase();
    final List<CustomItemEntry> prefix = <CustomItemEntry>[];
    final List<CustomItemEntry> partial = <CustomItemEntry>[];
    for (final CustomItemEntry entry in _items) {
      if (!anyProvider && entry.provider != wanted) continue;
      if (needle.isEmpty) {
        prefix.add(entry);
      } else {
        final String id = entry.id.toLowerCase();
        if (id.startsWith(needle)) {
          prefix.add(entry);
        } else if (id.contains(needle) ||
            (entry.name?.toLowerCase().contains(needle) ?? false)) {
          partial.add(entry);
        }
      }
      if (prefix.length >= limit) break;
    }
    final List<CustomItemEntry> out = <CustomItemEntry>[...prefix, ...partial];
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  /// Decodes an export. Returns null when [body] is not a catalog at all, so
  /// the import action can tell "wrong file" from "empty export".
  static HuiCustomItemCatalog? parse(String body) {
    final Object? decoded = _decode(body);
    if (decoded is! Map<String, Object?>) return null;
    final Object? raw = decoded['items'];
    if (raw is! List<Object?>) return null;

    final List<CustomItemEntry> items = <CustomItemEntry>[];
    final Map<String, List<CustomItemEntry>> byId =
        <String, List<CustomItemEntry>>{};
    final Map<String, int> countByProvider = <String, int>{};
    for (final Object? item in raw) {
      if (item is! Map<String, Object?>) continue;
      final Object? provider = item['provider'];
      final Object? id = item['id'];
      if (provider is! String || id is! String) continue;
      final String normalizedProvider = provider.trim().toLowerCase();
      final String normalizedId = id.trim();
      if (normalizedProvider.isEmpty || normalizedId.isEmpty) continue;
      final Object? name = item['name'];
      final Object? material = item['material'];
      final CustomItemEntry entry = CustomItemEntry(
        provider: normalizedProvider,
        id: normalizedId,
        name: name is String && name.isNotEmpty ? name : null,
        material: material is String && material.isNotEmpty
            ? material.trim().toLowerCase()
            : null,
      );
      items.add(entry);
      (byId[entry.id] ??= <CustomItemEntry>[]).add(entry);
      countByProvider[entry.provider] =
          (countByProvider[entry.provider] ?? 0) + 1;
    }

    final Object? declared = decoded['providers'];
    final List<String> providers = <String>[];
    if (declared is List<Object?>) {
      for (final Object? provider in declared) {
        if (provider is! String) continue;
        final String normalized = provider.trim().toLowerCase();
        if (normalized.isNotEmpty && !providers.contains(normalized)) {
          providers.add(normalized);
        }
      }
    }
    if (providers.isEmpty) {
      for (final CustomItemEntry entry in items) {
        if (!providers.contains(entry.provider)) providers.add(entry.provider);
      }
    }

    final Object? generated = decoded['generated'];
    return HuiCustomItemCatalog._(
      items: List<CustomItemEntry>.unmodifiable(items),
      byId: byId,
      countByProvider: countByProvider,
      providers: List<String>.unmodifiable(providers),
      generated: generated is num ? generated.toInt() : 0,
    );
  }

  /// Persists a hand-imported export. False when storage refused the write.
  static bool store(String body) => StorageService.write(storageKey, body);

  static void forgetStored() => StorageService.remove(storageKey);

  /// The imported export, or null when none was imported or it no longer
  /// parses.
  static HuiCustomItemCatalog? loadStored() {
    final String? body = StorageService.read(storageKey);
    return body == null ? null : parse(body);
  }
}

/// One variable a preview document can read, as the plugin documents it.
class PreviewVariableEntry {
  const PreviewVariableEntry(this.name, this.type, this.description);

  /// Dotted name exactly as an expression writes it: `inventory.size`.
  final String name;

  /// `number`, `string` or `boolean` — the three runtime types the expression
  /// language has.
  final String type;

  final String description;

  @override
  String toString() => 'PreviewVariableEntry($name: $type)';
}

/// One function a preview document can call.
class PreviewFunctionEntry {
  const PreviewFunctionEntry({
    required this.name,
    required this.args,
    required this.returns,
    required this.description,
  });

  final String name;

  /// Signature fragments as written in the catalog: `slot: number`.
  final List<String> args;

  final String returns;
  final String description;

  @override
  String toString() => 'PreviewFunctionEntry($name)';
}

/// The preview variable contract, decoded from `preview-variables.json`.
///
/// The asset is `HoloUi/src/test/resources/preview-variables.json` copied
/// verbatim; the plugin pins it against `PreviewStateAdapters.catalog()` and
/// the editor pins `PreviewSim` against it in turn, so the three cannot drift
/// apart silently. Consumers get variable pickers and inline documentation out
/// of it, and must keep working when it is missing.
class HuiPreviewVariableCatalog {
  const HuiPreviewVariableCatalog._(this._categories, this.functions);

  final Map<String, List<PreviewVariableEntry>> _categories;

  /// Documented functions, in file order.
  final List<PreviewFunctionEntry> functions;

  static const HuiPreviewVariableCatalog empty = HuiPreviewVariableCatalog._(
    <String, List<PreviewVariableEntry>>{},
    <PreviewFunctionEntry>[],
  );

  bool get isEmpty => _categories.isEmpty && functions.isEmpty;

  /// Group names in file order: `universal`, `inventory`, then one per
  /// container category.
  List<String> get categoryNames => _categories.keys.toList();

  List<PreviewVariableEntry> variables(String category) =>
      _categories[category] ?? const <PreviewVariableEntry>[];

  PreviewVariableEntry? variable(String category, String name) {
    for (final PreviewVariableEntry entry in variables(category)) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  /// Decodes the contract file. Never throws; a malformed or missing asset
  /// degrades to [empty] and every picker falls back to free text.
  static HuiPreviewVariableCatalog parse(String body) {
    final Object? decoded = _decode(body);
    if (decoded is! Map<String, Object?>) return empty;
    final Map<String, List<PreviewVariableEntry>> categories =
        <String, List<PreviewVariableEntry>>{};
    final Object? rawCategories = decoded['categories'];
    if (rawCategories is Map<String, Object?>) {
      for (final MapEntry<String, Object?> group in rawCategories.entries) {
        final Object? members = group.value;
        if (members is! Map<String, Object?>) continue;
        final List<PreviewVariableEntry> entries = <PreviewVariableEntry>[];
        for (final MapEntry<String, Object?> member in members.entries) {
          final Object? fields = member.value;
          if (fields is! Map<String, Object?>) continue;
          final Object? type = fields['type'];
          if (type is! String || type.isEmpty) continue;
          final Object? description = fields['description'];
          entries.add(
            PreviewVariableEntry(
              member.key,
              type,
              description is String ? description : '',
            ),
          );
        }
        if (entries.isNotEmpty) categories[group.key] = entries;
      }
    }

    final List<PreviewFunctionEntry> functions = <PreviewFunctionEntry>[];
    final Object? rawFunctions = decoded['functions'];
    if (rawFunctions is Map<String, Object?>) {
      for (final MapEntry<String, Object?> function in rawFunctions.entries) {
        final Object? fields = function.value;
        if (fields is! Map<String, Object?>) continue;
        final Object? args = fields['args'];
        final Object? returns = fields['returns'];
        final Object? description = fields['description'];
        functions.add(
          PreviewFunctionEntry(
            name: function.key,
            args: <String>[
              if (args is List<Object?>)
                for (final Object? arg in args)
                  if (arg is String) arg,
            ],
            returns: returns is String ? returns : '',
            description: description is String ? description : '',
          ),
        );
      }
    }
    return HuiPreviewVariableCatalog._(categories, functions);
  }
}

/// Immutable snapshot of both catalogs.
class HuiCatalogs {
  const HuiCatalogs._({
    required List<MaterialEntry> materials,
    required Map<String, MaterialEntry> materialIndex,
    required Set<String> materialKeys,
    required List<String> sounds,
    required Set<String> soundKeys,
    required this.customItems,
    required this.previewVariables,
    required this.previewLang,
    required this.emoji,
    required this.loaded,
  }) : _materials = materials,
       _materialIndex = materialIndex,
       _materialKeys = materialKeys,
       _sounds = sounds,
       _soundKeys = soundKeys;

  final List<MaterialEntry> _materials;
  final Map<String, MaterialEntry> _materialIndex;
  final Set<String> _materialKeys;
  final List<String> _sounds;
  final Set<String> _soundKeys;

  /// Empty unless the server exported one; see [HuiCustomItemCatalog].
  final HuiCustomItemCatalog customItems;

  /// The preview variable contract. Empty when the asset is missing, which
  /// costs the preview surfaces their pickers and documentation, nothing else.
  final HuiPreviewVariableCatalog previewVariables;

  /// English message templates for the simulated `lang()`. Empty renders every
  /// key as itself, exactly as the plugin does for an unknown id.
  final PreviewLangCatalog previewLang;

  /// The shipped emoji defaults (`tool/extract_emoji_catalog.dart` from
  /// `Gloss/src/main/resources/defaults/emoji/`), glyphs already resolved.
  /// Workspace emoji documents override these by id in
  /// `EditorStore.workspaceEmoji`; empty just means chat text keeps its
  /// `:tokens:` literal.
  final List<GlossEmojiEntry> emoji;

  /// False when either asset failed to fetch or parse. Consumers should keep
  /// working: validation degrades to "no catalog" (unknown keys are not
  /// flagged) and pickers fall back to free text.
  final bool loaded;

  static const String itemsAssetUrl = 'assets/catalog/items.json';
  static const String soundsAssetUrl = 'assets/catalog/sounds.json';
  static const String previewVariablesAssetUrl =
      'assets/catalog/preview-variables.json';
  static const String previewLangAssetUrl =
      'assets/catalog/preview-lang-en.json';
  static const String emojiAssetUrl = 'assets/catalog/emoji.json';

  /// One URL, and the build always ships a file there — an empty catalog when
  /// nobody has exported one. Probing a second, usually-absent URL would print
  /// a red 404 in every visitor's console on every load, which reads as a
  /// broken app. The hosted bundle ships an empty
  /// catalog; per-server ids arrive via manual import in the settings dialog.
  static const List<String> customItemUrlCandidates = <String>[
    'assets/catalog/custom-items.json',
  ];
  static const Duration _fetchTimeout = Duration(seconds: 20);

  /// Fetches every catalog asset. Never throws; on failure the corresponding
  /// list is empty and [loaded] is false. [loaded] tracks the material and
  /// sound catalogs only: custom items are an optional server export.
  static Future<HuiCatalogs> load({
    String itemsUrl = itemsAssetUrl,
    String soundsUrl = soundsAssetUrl,
    String previewVariablesUrl = previewVariablesAssetUrl,
    String previewLangUrl = previewLangAssetUrl,
    String emojiUrl = emojiAssetUrl,
    List<String> customItemUrls = customItemUrlCandidates,
  }) async {
    final List<String?> bodies = await Future.wait<String?>(<Future<String?>>[
      _fetch(itemsUrl),
      _fetch(soundsUrl),
      _fetch(previewVariablesUrl),
      _fetch(previewLangUrl),
      _fetch(emojiUrl),
    ]);
    final String? itemsBody = bodies[0];
    final String? soundsBody = bodies[1];
    final String? previewVariablesBody = bodies[2];
    final String? previewLangBody = bodies[3];
    final String? emojiBody = bodies[4];
    final List<MaterialEntry> materials = itemsBody == null
        ? const <MaterialEntry>[]
        : parseMaterials(itemsBody);
    final List<String> sounds = soundsBody == null
        ? const <String>[]
        : parseSounds(soundsBody);
    final bool ok = materials.isNotEmpty && sounds.isNotEmpty;
    return build(
      materials: materials,
      sounds: sounds,
      customItems: await loadCustomItems(customItemUrls),
      previewVariables: previewVariablesBody == null
          ? HuiPreviewVariableCatalog.empty
          : HuiPreviewVariableCatalog.parse(previewVariablesBody),
      previewLang: previewLangBody == null
          ? PreviewLangCatalog.empty
          : PreviewLangCatalog.parse(previewLangBody),
      emoji: emojiBody == null
          ? const <GlossEmojiEntry>[]
          : parseEmoji(emojiBody),
      loaded: ok,
    );
  }

  /// A hand-imported catalog wins: it is an explicit user action, and on the
  /// public site it is the only source there is.
  static Future<HuiCustomItemCatalog> loadCustomItems([
    List<String> urls = customItemUrlCandidates,
  ]) async {
    final HuiCustomItemCatalog? stored = HuiCustomItemCatalog.loadStored();
    if (stored != null) return stored;
    for (final String url in urls) {
      final String? body = await _fetch(url);
      if (body == null) continue;
      final HuiCustomItemCatalog? parsed = HuiCustomItemCatalog.parse(body);
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }
    return HuiCustomItemCatalog.empty();
  }

  /// Empty catalogs, used before [load] completes and when it fails outright.
  factory HuiCatalogs.empty() => build(
    materials: const <MaterialEntry>[],
    sounds: const <String>[],
    loaded: false,
  );

  /// Assembles the lookup indexes. Exposed for tests and for callers that
  /// already hold decoded catalog data.
  static HuiCatalogs build({
    required List<MaterialEntry> materials,
    required List<String> sounds,
    required bool loaded,
    HuiCustomItemCatalog? customItems,
    HuiPreviewVariableCatalog previewVariables =
        HuiPreviewVariableCatalog.empty,
    PreviewLangCatalog previewLang = PreviewLangCatalog.empty,
    List<GlossEmojiEntry> emoji = const <GlossEmojiEntry>[],
  }) {
    final Map<String, MaterialEntry> index = <String, MaterialEntry>{};
    for (final MaterialEntry entry in materials) {
      index[entry.key] = entry;
    }
    return HuiCatalogs._(
      materials: List<MaterialEntry>.unmodifiable(materials),
      materialIndex: index,
      materialKeys: Set<String>.unmodifiable(index.keys),
      sounds: List<String>.unmodifiable(sounds),
      soundKeys: Set<String>.unmodifiable(sounds),
      customItems: customItems ?? HuiCustomItemCatalog.empty(),
      previewVariables: previewVariables,
      previewLang: previewLang,
      emoji: List<GlossEmojiEntry>.unmodifiable(emoji),
      loaded: loaded,
    );
  }

  /// Same material and sound data with a different custom item catalog, for the
  /// import action.
  HuiCatalogs withCustomItems(HuiCustomItemCatalog catalog) => HuiCatalogs._(
    materials: _materials,
    materialIndex: _materialIndex,
    materialKeys: _materialKeys,
    sounds: _sounds,
    soundKeys: _soundKeys,
    customItems: catalog,
    previewVariables: previewVariables,
    previewLang: previewLang,
    emoji: emoji,
    loaded: loaded,
  );

  /// Registry keys sorted alphabetically; textured entries and key-only entries
  /// are interleaved.
  List<MaterialEntry> get materials => _materials;

  Set<String> get materialKeys => _materialKeys;

  /// Curated UI/feedback sounds first, then every remaining key sorted.
  List<String> get sounds => _sounds;

  Set<String> get soundKeys => _soundKeys;

  /// `(placeholder, description)` pairs for the condition/text pickers.
  List<(String, String)> get placeholders => _placeholders;

  MaterialEntry? material(String key) => _materialIndex[key.toLowerCase()];

  String? textureFor(String key) => _materialIndex[key.toLowerCase()]?.texture;

  /// Substring match ranked prefix-first, for the material combobox.
  List<MaterialEntry> searchMaterials(String query, {int limit = 60}) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return _materials.length <= limit
          ? _materials
          : _materials.sublist(0, limit);
    }
    final List<MaterialEntry> prefix = <MaterialEntry>[];
    final List<MaterialEntry> contains = <MaterialEntry>[];
    for (final MaterialEntry entry in _materials) {
      if (entry.key.startsWith(needle)) {
        prefix.add(entry);
      } else if (entry.key.contains(needle)) {
        contains.add(entry);
      }
      if (prefix.length >= limit) break;
    }
    final List<MaterialEntry> out = <MaterialEntry>[...prefix, ...contains];
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  /// Substring match ranked prefix-first, for the sound combobox. Curated head
  /// entries keep their priority because [sounds] is already ordered.
  List<String> searchSounds(String query, {int limit = 60}) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return _sounds.length <= limit ? _sounds : _sounds.sublist(0, limit);
    }
    final List<String> prefix = <String>[];
    final List<String> contains = <String>[];
    for (final String key in _sounds) {
      if (key.startsWith(needle)) {
        prefix.add(key);
      } else if (key.contains(needle)) {
        contains.add(key);
      }
      if (prefix.length >= limit) break;
    }
    final List<String> out = <String>[...prefix, ...contains];
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  static Future<String?> _fetch(String url) async {
    try {
      final http.Response response = await http
          .get(Uri.parse(url))
          .timeout(_fetchTimeout);
      if (response.statusCode != 200) return null;
      return response.body;
    } catch (_) {
      // Offline, blocked, or served without the asset: degrade to no catalog.
      return null;
    }
  }

  /// Decodes `{"materials":[{"key":..,"texture":..}]}`. Entries without a
  /// usable key are dropped; a missing or empty `texture` becomes null.
  static List<MaterialEntry> parseMaterials(String body) {
    final Object? decoded = _decode(body);
    if (decoded is! Map<String, Object?>) return const <MaterialEntry>[];
    final Object? raw = decoded['materials'];
    if (raw is! List<Object?>) return const <MaterialEntry>[];
    final List<MaterialEntry> out = <MaterialEntry>[];
    for (final Object? item in raw) {
      if (item is! Map<String, Object?>) continue;
      final Object? key = item['key'];
      if (key is! String) continue;
      final String normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final Object? texture = item['texture'];
      out.add(
        MaterialEntry(
          normalized,
          texture is String && texture.isNotEmpty ? texture : null,
        ),
      );
    }
    return out;
  }

  /// Decodes `{"emoji":[{"name":..,"trigger":..,"glyph":..,"enabled":..}]}`
  /// — the shape `tool/extract_emoji_catalog.dart` writes. Entries without a
  /// usable name or glyph are dropped; the result is sorted by id the way
  /// `EmojiService.rebuild` sorts its entries.
  static List<GlossEmojiEntry> parseEmoji(String body) {
    final Object? decoded = _decode(body);
    if (decoded is! Map<String, Object?>) return const <GlossEmojiEntry>[];
    final Object? raw = decoded['emoji'];
    if (raw is! List<Object?>) return const <GlossEmojiEntry>[];
    final List<GlossEmojiEntry> out = <GlossEmojiEntry>[];
    for (final Object? item in raw) {
      if (item is! Map<String, Object?>) continue;
      final Object? name = item['name'];
      final Object? glyph = item['glyph'];
      if (name is! String || name.isEmpty || glyph is! String) continue;
      final Object? trigger = item['trigger'];
      final Object? enabled = item['enabled'];
      out.add(
        GlossEmojiEntry(
          id: name,
          trigger: trigger is String ? trigger : '',
          glyph: glyph,
          enabled: enabled is! bool || enabled,
        ),
      );
    }
    out.sort(
      (GlossEmojiEntry a, GlossEmojiEntry b) => a.id.compareTo(b.id),
    );
    return out;
  }

  /// Decodes `{"sounds":[".."]}` preserving file order (curated head first).
  static List<String> parseSounds(String body) {
    final Object? decoded = _decode(body);
    if (decoded is! Map<String, Object?>) return const <String>[];
    final Object? raw = decoded['sounds'];
    if (raw is! List<Object?>) return const <String>[];
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final Object? item in raw) {
      if (item is! String) continue;
      final String normalized = item.trim().toLowerCase();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      out.add(normalized);
    }
    return out;
  }
}

/// Picks the live catalogs over a boot snapshot.
///
/// The shell hands its panes the catalogs it fetched once, at boot, and never
/// updates them; importing a custom item catalog swaps `EditorStore.catalogs`
/// instead. The store therefore only ever equals or leads the snapshot, and is
/// preferred as soon as it holds anything at all.
HuiCatalogs huiFreshestCatalogs(HuiCatalogs store, HuiCatalogs? snapshot) {
  if (snapshot == null) return store;
  return store.loaded || store.customItems.isNotEmpty ? store : snapshot;
}

Object? _decode(String body) {
  try {
    return jsonDecode(body) as Object?;
  } catch (_) {
    return null;
  }
}

/// HoloUI's own three PlaceholderAPI keys followed by common expansions people
/// already have installed. Text icon lines expand initially and then at their
/// `refreshTicks`; a toggle `condition` expands only at open. Commands, image
/// paths and ids are never expanded.
const List<(String, String)> _placeholders = <(String, String)>[
  (
    '%holoui_available%',
    'HoloUI: always true. Use it to confirm PlaceholderAPI resolved the HoloUI expansion.',
  ),
  (
    '%holoui_menu.open%',
    'HoloUI: true or false - whether this player has a HoloUI menu open.',
  ),
  (
    '%holoui_menu.id%',
    'HoloUI: the id of the open menu, or --- when none is open.',
  ),
  ('%player_name%', 'PlaceholderAPI: the player account name.'),
  ('%player_displayname%', 'PlaceholderAPI: the formatted display name.'),
  ('%player_world%', 'PlaceholderAPI: the world the player is standing in.'),
  ('%player_health%', 'PlaceholderAPI: current health points.'),
  ('%player_level%', 'PlaceholderAPI: current experience level.'),
  ('%player_ping%', 'PlaceholderAPI: connection latency in milliseconds.'),
  (
    '%player_gamemode%',
    'PlaceholderAPI: SURVIVAL, CREATIVE, ADVENTURE, or SPECTATOR.',
  ),
  ('%server_online%', 'PlaceholderAPI: players currently connected.'),
  ('%server_max_players%', 'PlaceholderAPI: the configured player cap.'),
  ('%server_tps_1%', 'PlaceholderAPI: one-minute average TPS.'),
  (
    '%vault_eco_balance_formatted%',
    'Vault expansion: the player balance, formatted.',
  ),
  ('%luckperms_prefix%', 'LuckPerms expansion: the player prefix.'),
];
