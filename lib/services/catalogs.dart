/// Static Minecraft material and sound catalogs plus the placeholder cheat
/// sheet, loaded from `web/assets/catalog/` at boot.
///
/// The URLs are relative on purpose: the bundle is served both from Undertow at
/// `/` (the plugin's self-hosted builder) and from `https://holoui.volmit.com/`,
/// so nothing may hard-code an origin or a leading slash.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

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

/// Immutable snapshot of both catalogs.
class HuiCatalogs {
  const HuiCatalogs._({
    required List<MaterialEntry> materials,
    required Map<String, MaterialEntry> materialIndex,
    required Set<String> materialKeys,
    required List<String> sounds,
    required Set<String> soundKeys,
    required this.loaded,
  })  : _materials = materials,
        _materialIndex = materialIndex,
        _materialKeys = materialKeys,
        _sounds = sounds,
        _soundKeys = soundKeys;

  final List<MaterialEntry> _materials;
  final Map<String, MaterialEntry> _materialIndex;
  final Set<String> _materialKeys;
  final List<String> _sounds;
  final Set<String> _soundKeys;

  /// False when either asset failed to fetch or parse. Consumers should keep
  /// working: validation degrades to "no catalog" (unknown keys are not
  /// flagged) and pickers fall back to free text.
  final bool loaded;

  static const String itemsAssetUrl = 'assets/catalog/items.json';
  static const String soundsAssetUrl = 'assets/catalog/sounds.json';
  static const Duration _fetchTimeout = Duration(seconds: 20);

  /// Fetches both catalog assets. Never throws; on failure the corresponding
  /// list is empty and [loaded] is false.
  static Future<HuiCatalogs> load({
    String itemsUrl = itemsAssetUrl,
    String soundsUrl = soundsAssetUrl,
  }) async {
    final List<String?> bodies = await Future.wait<String?>(<Future<String?>>[
      _fetch(itemsUrl),
      _fetch(soundsUrl),
    ]);
    final String? itemsBody = bodies[0];
    final String? soundsBody = bodies[1];
    final List<MaterialEntry> materials =
        itemsBody == null ? const <MaterialEntry>[] : parseMaterials(itemsBody);
    final List<String> sounds =
        soundsBody == null ? const <String>[] : parseSounds(soundsBody);
    final bool ok = materials.isNotEmpty && sounds.isNotEmpty;
    return build(materials: materials, sounds: sounds, loaded: ok);
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
      loaded: loaded,
    );
  }

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
      final http.Response response =
          await http.get(Uri.parse(url)).timeout(_fetchTimeout);
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
      out.add(MaterialEntry(
        normalized,
        texture is String && texture.isNotEmpty ? texture : null,
      ));
    }
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

  static Object? _decode(String body) {
    try {
      return jsonDecode(body) as Object?;
    } catch (_) {
      return null;
    }
  }
}

/// HoloUI's own three PlaceholderAPI keys followed by common expansions people
/// already have installed. Expansion happens once, at menu open, and only in
/// text icon lines and the toggle `condition` - never in commands, image paths,
/// or ids.
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
  ('%player_gamemode%', 'PlaceholderAPI: SURVIVAL, CREATIVE, ADVENTURE, or SPECTATOR.'),
  ('%server_online%', 'PlaceholderAPI: players currently connected.'),
  ('%server_max_players%', 'PlaceholderAPI: the configured player cap.'),
  ('%server_tps_1%', 'PlaceholderAPI: one-minute average TPS.'),
  ('%vault_eco_balance_formatted%', 'Vault expansion: the player balance, formatted.'),
  ('%luckperms_prefix%', 'LuckPerms expansion: the player prefix.'),
];
