/// Simulated preview state: the editor's twin of the plugin's
/// `PreviewStateContext` plus `PreviewStateAdapters`.
///
/// A live context samples a Bukkit block, entity or inventory once per refresh
/// and hands the document a flat map of plain values. The editor has no server,
/// so [PreviewSim] plays the same role from canned state: one simulated
/// category (a chest, a smelting furnace, an active brewing stand, ...) whose
/// counters [tick] forward so an author sees the same motion the plugin draws.
///
/// The variable names, their types and the resolution order are the contract,
/// not a convenience: `web/assets/catalog/preview-variables.json` is the
/// plugin's own catalog file copied verbatim, and `preview_sim_test.dart`
/// resolves every name in it against the matching simulated category. A
/// variable the plugin adds therefore fails the editor's suite until it is
/// simulated here.
///
/// Resolution order, matching `PreviewStateContext.variable`:
///   1. `vars.<name>` reads the active document/variant variables, and nothing
///      else does — a document variable can never shadow a built-in.
///   2. everything else reads the simulated sample, with [overrides] pinning
///      any published name to a value the simulation panel set by hand.
///
/// Category defaults reproduce the plugin's own golden fixtures
/// (`GoldenFakes`), so a document that renders "Smelting Iron Ore 50%" here
/// renders it there too.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import 'dart:convert';

import 'preview_expr.dart';
import 'preview_expr_functions.dart';

/// Every simulated category, in the order a picker should list them.
///
/// These are editor-facing names. The plugin has one `inventory` category for
/// any plain container; the editor splits it into the targets an author picks
/// between (a chest, an ender chest, a minecart entity), which all publish the
/// same variables.
const List<String> previewSimCategories = <String>[
  'chest',
  'furnace',
  'brewing',
  'beehive',
  'cauldron',
  'jukebox',
  'enderChest',
  'entity',
  'statics',
];

/// The catalog groups each simulated category publishes, mirroring
/// `PreviewStateAdapters.sample`: the universal group always, the inventory
/// group whenever the target has an inventory, and the group named by the
/// category itself.
const Map<String, List<String>> previewSimCategoryGroups =
    <String, List<String>>{
      'chest': <String>['universal', 'inventory'],
      'furnace': <String>['universal', 'inventory', 'furnace'],
      'brewing': <String>['universal', 'inventory', 'brewing'],
      'beehive': <String>['universal', 'beehive'],
      'cauldron': <String>['universal', 'cauldron'],
      'jukebox': <String>['universal', 'inventory', 'jukebox'],
      'enderChest': <String>['universal', 'inventory'],
      'entity': <String>['universal', 'inventory'],
      'statics': <String>['universal'],
    };

/// The variable names each catalog group carries, in catalog order. Pinned
/// against the shipped catalog file by the sync gate; this is the sim's own
/// declaration of what it publishes, so an extra or missing name fails there.
const Map<String, List<String>> previewSimGroupVariables =
    <String, List<String>>{
      'universal': <String>['time', 'blockType', 'customName'],
      'inventory': <String>['inventory.size', 'inventory.occupied'],
      'furnace': <String>[
        'cookTime',
        'cookTimeTotal',
        'burnTime',
        'fuelSeconds',
        'bankedXp',
        'lit',
        'surge.active',
        'surge.gain',
      ],
      'brewing': <String>[
        'brewTime',
        'brewTotal',
        'fuelLevel',
        'maxFuel',
        'surge.active',
        'surge.gain',
      ],
      'beehive': <String>['bees', 'maxBees', 'honey', 'maxHoney'],
      'cauldron': <String>['level', 'maxLevel', 'fluid'],
      'jukebox': <String>['playing', 'record'],
    };

/// [PreviewSim.variableNames] without needing a live instance: which names a
/// category publishes never depends on any simulated state, only on the
/// category name itself, so this is a pure function of [category] rather than
/// a getter that requires constructing a whole [PreviewSim] (which allocates
/// its default sample state — slot item lists included — just to answer a
/// question the category string alone already answers). Callers that only
/// need this list, such as the inspector's per-field "not published by this
/// category" hint, should call this directly instead of allocating an
/// instance solely to read it off.
List<String> previewCategoryVariableNames(String category) => <String>[
  for (final String group
      in previewSimCategoryGroups[category] ?? const <String>['universal'])
    ...previewSimGroupVariables[group] ?? const <String>[],
];

/// Every published variable whose value [PreviewSim.tick] moves.
///
/// The editor's clock is gated on whether a document reads one of these: a card
/// built only from `inventory.size` and `blockType` is the same picture every
/// tick, and repainting it twenty times a second is pure waste. Declared beside
/// [PreviewSim.tick] rather than beside the surface that reads it so the two
/// cannot drift; `preview_sim_test.dart` ticks every category and asserts that
/// nothing outside this set moved.
const Set<String> previewTickVaryingVariables = <String>{
  'time',
  // furnace: `advance`d by tick, plus the two values derived from `burnTime`.
  'cookTime',
  'burnTime',
  'fuelSeconds',
  'lit',
  // brewing.
  'brewTime',
  'fuelLevel',
  // beehive.
  'honey',
};

/// Seconds of gained progress a surge reports when the panel toggles one on
/// without naming a value. `TimeFlowTracker` produces fractional seconds, and
/// the shipped furnace document formats anything non-integral through
/// `fixed(surge.gain, 1)`, so the default exercises that branch.
const double previewSimDefaultSurgeGain = 1.5;

/// Ticks between two honey-level steps in a simulated hive. Vanilla fills a
/// hive far more slowly; this is fast enough to watch in the editor.
const int previewSimHoneyPeriod = 600;

const int _ticksPerSecond = 20;
const String _varsPrefix = 'vars.';
const String _langArgPrefix = 'arg';

/// One sample stack in a simulated inventory, sparse by slot.
class SimSlotItem {
  const SimSlotItem(this.slot, this.material, this.count);

  final int slot;

  /// Enum-style material id, exactly what `item(slot)` returns: `IRON_ORE`.
  final String material;

  final int count;

  /// The plugin's `PreviewStateAdapters.empty` rule.
  bool get isEmpty => count < 1 || material.isEmpty || material == 'AIR';

  @override
  String toString() => 'SimSlotItem($slot, $material x$count)';
}

/// The English message templates `lang()` renders against.
///
/// `web/assets/catalog/preview-lang-en.json` is generated from the plugin's
/// `HoloMessages.java` by `tool/extract_preview_lang.dart`; only the templates'
/// placeholder names and order matter, which is why the snapshot has to come
/// from the Java constants rather than a locale file.
class PreviewLangCatalog {
  const PreviewLangCatalog(this.messages);

  /// Message id to English template.
  final Map<String, String> messages;

  static const PreviewLangCatalog empty = PreviewLangCatalog(
    <String, String>{},
  );

  bool get isEmpty => messages.isEmpty;

  String? template(String key) => messages[key];

  /// Decodes `{"messages":{"<id>":"<template>"}}`. Never throws: a missing or
  /// malformed snapshot degrades to [empty], and every key then renders as
  /// itself — which is also what the plugin does for an id its catalog does not
  /// know.
  static PreviewLangCatalog parse(String body) {
    final Object? decoded = _decodeJson(body);
    if (decoded is! Map<String, Object?>) return empty;
    final Object? raw = decoded['messages'];
    if (raw is! Map<String, Object?>) return empty;
    final Map<String, String> out = <String, String>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      final Object? template = entry.value;
      if (template is String) out[entry.key] = template;
    }
    return PreviewLangCatalog(out);
  }

  /// Renders [key] with [args] bound positionally onto the template's own
  /// placeholder names: argument 1 fills the first `{name}`, argument 2 the
  /// second, and so on. That is what lets a document write
  /// `lang("holoui.preview.state.smelting_item", item, percent)` and get
  /// `Smelting Iron Ore 42%` out of `Smelting {item} {percent}%`.
  ///
  /// An unknown id renders as itself, arguments past the last placeholder go
  /// unused, and a placeholder no argument reached stays literal — the lenient
  /// rendering `HoloLocalization.renderTemplate` performs, which is also the
  /// path the plugin's own golden snapshots were captured through.
  String render(String key, List<Object?> args) {
    final String template = messages[key] ?? key;
    if (args.isEmpty) return template;
    final List<String> names = orderedPlaceholders(template);
    final Map<String, String> bound = <String, String>{};
    for (int index = 0; index < args.length; index++) {
      final String name = index < names.length
          ? names[index]
          : '$_langArgPrefix$index';
      // Values are inserted as untrusted text, so a container name can never
      // smuggle in colour codes.
      bound[name] = _sanitizeUntrusted(previewStringify(args[index]));
    }
    return _fill(template, bound);
  }

  /// Placeholder names in first-appearance order, deduped, honouring the `{{`
  /// escape. Port of `PreviewStateContext.orderedPlaceholders`.
  static List<String> orderedPlaceholders(String template) {
    final List<String> names = <String>[];
    int cursor = 0;
    while (cursor < template.length) {
      final int open = template.indexOf('{', cursor);
      if (open < 0) break;
      if (open + 1 < template.length && template[open + 1] == '{') {
        cursor = open + 2;
        continue;
      }
      final int close = template.indexOf('}', open + 1);
      if (close < 0) break;
      final String name = template.substring(open + 1, close);
      if (!names.contains(name)) names.add(name);
      cursor = close + 1;
    }
    return names;
  }

  /// Substitutes the bound names in one pass, so an inserted value can never
  /// be rescanned as a placeholder. `{{` stays literal, matching
  /// `renderTemplate`, which only ever replaces whole `{name}` tokens.
  static String _fill(String template, Map<String, String> values) {
    final StringBuffer out = StringBuffer();
    int cursor = 0;
    while (cursor < template.length) {
      final String c = template[cursor];
      if (c != '{') {
        out.write(c);
        cursor++;
        continue;
      }
      if (cursor + 1 < template.length && template[cursor + 1] == '{') {
        out.write('{{');
        cursor += 2;
        continue;
      }
      final int close = template.indexOf('}', cursor + 1);
      if (close < 0) {
        out.write(template.substring(cursor));
        break;
      }
      final String? value = values[template.substring(cursor + 1, close)];
      out.write(value ?? template.substring(cursor, close + 1));
      cursor = close + 1;
    }
    return out.toString();
  }
}

/// Bukkit's `ChatColor.stripColor` pattern.
final RegExp _sectionCode = RegExp('§[0-9A-FK-ORa-fk-or]');

String _sanitizeUntrusted(String value) =>
    value.replaceAll(_sectionCode, '').replaceAll('§', '');

Object? _decodeJson(String body) {
  try {
    return jsonDecode(body) as Object?;
  } catch (_) {
    return null;
  }
}

/// One simulated preview target, resolving the same names and functions a live
/// `PreviewStateContext` does.
class PreviewSim implements PExprScope {
  PreviewSim(this.category, {PreviewLangCatalog? lang})
    : lang = lang ?? PreviewLangCatalog.empty {
    reset();
  }

  /// One of [previewSimCategories]. An unknown name behaves like `statics`:
  /// the universal group and nothing else.
  final String category;

  /// The English snapshot `lang()` renders against; [PreviewLangCatalog.empty]
  /// renders every key as itself.
  PreviewLangCatalog lang;

  /// Values the simulation panel pinned by hand. A pinned name keeps its value
  /// through [tick]; removing it hands the name back to the simulation. Only
  /// names the category publishes are readable, so an override can never invent
  /// a variable the plugin would not resolve.
  final Map<String, Object> overrides = <String, Object>{};

  /// The active document/variant variables, colour literals already parsed —
  /// see [parseVars]. Reachable only under the `vars.` prefix.
  Map<String, Object> vars = <String, Object>{};

  /// Sample stacks, sparse by slot; `count`, `occupied` and `item` read them.
  List<SimSlotItem> slotItems = const <SimSlotItem>[];

  /// Slot count of the simulated inventory, or 0 when the target has none. The
  /// inventory variables are published only when this is positive, exactly as
  /// the plugin publishes them only for a non-null inventory.
  int inventorySize = 0;

  double time = 0;
  String blockType = '';
  String customName = '';

  double cookTime = 0;
  double cookTimeTotal = 0;
  double burnTime = 0;
  double bankedXp = 0;

  double brewTime = 0;
  double brewTotal = 0;
  double fuelLevel = 0;
  double maxFuel = 0;

  double bees = 0;
  double maxBees = 0;
  double honey = 0;
  double maxHoney = 0;

  double level = 0;
  double maxLevel = 0;
  String fluid = '';

  bool playing = false;
  String record = '';

  bool surgeActive = false;
  double surgeGain = 0;

  /// Ticks accumulated towards the next honey step.
  int _honeyProgress = 0;

  /// Every name this category publishes, in catalog order.
  List<String> get variableNames => previewCategoryVariableNames(category);

  /// The whole published sample, for the simulation panel's variable list. The
  /// expression evaluator goes through [variable] instead and allocates
  /// nothing.
  Map<String, Object> snapshot() => <String, Object>{
    for (final String name in variableNames) name: variable(name)!,
  };

  /// Restores the category's canned state, dropping any surge but keeping
  /// [vars] and [overrides].
  void reset() {
    time = _goldenGameTime;
    customName = '';
    surgeActive = false;
    surgeGain = 0;
    _honeyProgress = 0;
    _applyCategoryDefaults();
  }

  /// Advances the simulation by [gameTicks] game ticks: the clock always, and
  /// whichever counters the category owns. A non-positive step is a no-op, so a
  /// paused panel can call this unconditionally.
  void tick(int gameTicks) {
    if (gameTicks <= 0) return;
    time += gameTicks;
    // A surge is progress beyond the real elapsed ticks, which is exactly what
    // `surge.gain` reports; adding it here keeps the number the label renders
    // and the motion on screen telling the same story.
    final double advance =
        gameTicks + (surgeActive ? surgeGain * _ticksPerSecond : 0);
    switch (category) {
      case 'furnace':
        if (cookTimeTotal > 0) {
          cookTime = (cookTime + advance) % cookTimeTotal;
        }
        burnTime = _wrapDown(burnTime - gameTicks, _furnaceBurnTicks);
      case 'brewing':
        final double next = brewTime - advance;
        if (next <= 0) {
          fuelLevel = fuelLevel > 0 ? fuelLevel - 1 : maxFuel;
        }
        brewTime = _wrapDown(next, brewTotal);
      case 'beehive':
        _advanceHoney(gameTicks);
    }
  }

  /// Turns the simulated surge on or off. Only the furnace and brewing
  /// categories publish `surge.*`, matching
  /// `PreviewStateAdapters.tracksTimeFlow`.
  void setSurge(bool active, {double gain = previewSimDefaultSurgeGain}) {
    surgeActive = active;
    surgeGain = active ? gain : 0;
  }

  // ---------------------------------------------------------------------
  // PExprScope
  // ---------------------------------------------------------------------

  @override
  Object? variable(String dottedName) {
    if (dottedName.startsWith(_varsPrefix)) {
      return vars[dottedName.substring(_varsPrefix.length)];
    }
    final Object? sampled = _sample(dottedName);
    if (sampled == null) return null;
    return overrides[dottedName] ?? sampled;
  }

  @override
  Object? call(String name, List<Object?> args) {
    switch (name) {
      case 'lang':
        return _lang(args);
      case 'count':
        final SimSlotItem? item = _slotItem(name, args);
        return item == null ? 0.0 : item.count.toDouble();
      case 'occupied':
        return _slotItem(name, args) != null;
      case 'item':
        return _slotItem(name, args)?.material ?? '';
      default:
        return previewStdFunction(name, args);
    }
  }

  // ---------------------------------------------------------------------
  // Sampling
  // ---------------------------------------------------------------------

  Object? _sample(String name) {
    switch (name) {
      case 'time':
        return time;
      case 'blockType':
        return blockType;
      case 'customName':
        return customName;
    }
    if (inventorySize > 0) {
      switch (name) {
        case 'inventory.size':
          return inventorySize.toDouble();
        case 'inventory.occupied':
          return _occupiedSlots().toDouble();
      }
    }
    switch (category) {
      case 'furnace':
        switch (name) {
          case 'cookTime':
            return cookTime;
          case 'cookTimeTotal':
            return cookTimeTotal;
          case 'burnTime':
            return burnTime;
          case 'fuelSeconds':
            // Whole seconds, matching the plugin's integer division.
            return (burnTime / _ticksPerSecond).floorToDouble();
          case 'bankedXp':
            return bankedXp;
          case 'lit':
            return burnTime > 0;
          case 'surge.active':
            return surgeActive;
          case 'surge.gain':
            return surgeGain;
        }
      case 'brewing':
        switch (name) {
          case 'brewTime':
            return brewTime;
          case 'brewTotal':
            return brewTotal;
          case 'fuelLevel':
            return fuelLevel;
          case 'maxFuel':
            return maxFuel;
          case 'surge.active':
            return surgeActive;
          case 'surge.gain':
            return surgeGain;
        }
      case 'beehive':
        switch (name) {
          case 'bees':
            return bees;
          case 'maxBees':
            return maxBees;
          case 'honey':
            return honey;
          case 'maxHoney':
            return maxHoney;
        }
      case 'cauldron':
        switch (name) {
          case 'level':
            return level;
          case 'maxLevel':
            return maxLevel;
          case 'fluid':
            return fluid;
        }
      case 'jukebox':
        switch (name) {
          case 'playing':
            return playing;
          case 'record':
            return record;
        }
    }
    return null;
  }

  int _occupiedSlots() {
    int occupied = 0;
    for (final SimSlotItem item in slotItems) {
      if (!item.isEmpty && item.slot >= 0 && item.slot < inventorySize) {
        occupied++;
      }
    }
    return occupied;
  }

  // ---------------------------------------------------------------------
  // Functions
  // ---------------------------------------------------------------------

  String _lang(List<Object?> args) {
    if (args.isEmpty) {
      throw const PExprException(
        'lang expects at least 1 argument (the message key), got 0',
        previewNoPosition,
      );
    }
    final Object? key = args.first;
    if (key is! String) {
      throw const PExprException(
        'lang argument 1 (key) must be a string',
        previewNoPosition,
      );
    }
    return lang.render(key, args.sublist(1));
  }

  /// Null for a missing inventory, an out-of-range slot, or an empty stack.
  SimSlotItem? _slotItem(String name, List<Object?> args) {
    if (args.length != 1) {
      throw PExprException(
        '$name expects 1 argument(s), got ${args.length}',
        previewNoPosition,
      );
    }
    final Object? index = args.first;
    if (index is! double) {
      throw PExprException(
        '$name argument 1 must be a number',
        previewNoPosition,
      );
    }
    if (inventorySize <= 0 || !index.isFinite) return null;
    final double floored = index.floorToDouble();
    if (floored < 0 || floored >= inventorySize) return null;
    final int slot = floored.toInt();
    for (final SimSlotItem item in slotItems) {
      if (item.slot == slot) return item.isEmpty ? null : item;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Category defaults — the plugin's own `GoldenFakes` states
  // ---------------------------------------------------------------------

  void _applyCategoryDefaults() {
    switch (category) {
      case 'furnace':
        blockType = 'FURNACE';
        inventorySize = 3;
        cookTime = 100;
        cookTimeTotal = 200;
        burnTime = 300;
        // Recipe experience 0.5 used three times, exactly as GoldenFakes banks it.
        bankedXp = 1.5;
        slotItems = const <SimSlotItem>[
          SimSlotItem(0, 'IRON_ORE', 1),
          SimSlotItem(1, 'COAL', 8),
          SimSlotItem(2, 'IRON_INGOT', 2),
        ];
      case 'brewing':
        blockType = 'BREWING_STAND';
        inventorySize = 5;
        brewTime = 200;
        brewTotal = _brewTotalTicks;
        fuelLevel = 10;
        maxFuel = _maxFuelLevel;
        slotItems = const <SimSlotItem>[
          SimSlotItem(0, 'POTION', 1),
          SimSlotItem(1, 'POTION', 1),
          SimSlotItem(3, 'NETHER_WART', 1),
          SimSlotItem(4, 'BLAZE_POWDER', 4),
        ];
      case 'beehive':
        blockType = 'BEEHIVE';
        inventorySize = 0;
        bees = 2;
        maxBees = 3;
        honey = 3;
        maxHoney = 5;
        slotItems = const <SimSlotItem>[];
      case 'cauldron':
        blockType = 'WATER_CAULDRON';
        inventorySize = 0;
        level = 2;
        maxLevel = _cauldronMaxLevel;
        fluid = 'water';
        slotItems = const <SimSlotItem>[];
      case 'jukebox':
        blockType = 'JUKEBOX';
        inventorySize = 1;
        playing = true;
        record = previewReadable('MUSIC_DISC_CAT');
        slotItems = const <SimSlotItem>[SimSlotItem(0, 'MUSIC_DISC_CAT', 1)];
      case 'enderChest':
        blockType = 'ENDER_CHEST';
        inventorySize = 27;
        slotItems = const <SimSlotItem>[
          SimSlotItem(0, 'DIAMOND', 1),
          SimSlotItem(8, 'BOOK', 5),
        ];
      case 'entity':
        blockType = 'HOPPER_MINECART';
        inventorySize = 5;
        slotItems = const <SimSlotItem>[
          SimSlotItem(0, 'IRON_INGOT', 4),
          SimSlotItem(2, 'STONE', 1),
        ];
      case 'chest':
        blockType = 'CHEST';
        inventorySize = 27;
        slotItems = const <SimSlotItem>[
          SimSlotItem(0, 'DIAMOND', 1),
          SimSlotItem(1, 'STONE', 32),
          SimSlotItem(2, 'BOOK', 3),
        ];
      default:
        // A target-less context, the shape a locked preview builds against:
        // `blockType` is empty rather than absent so a document can branch on
        // `blockType != ''`.
        blockType = '';
        inventorySize = 0;
        slotItems = const <SimSlotItem>[];
    }
  }

  void _advanceHoney(int gameTicks) {
    if (maxHoney <= 0) return;
    _honeyProgress += gameTicks;
    final int steps = _honeyProgress ~/ previewSimHoneyPeriod;
    if (steps == 0) return;
    _honeyProgress -= steps * previewSimHoneyPeriod;
    honey = (honey + steps) % (maxHoney + 1);
  }

  /// Wraps a counter that runs down into `(0, period]`, so it refuels instead
  /// of sticking at zero.
  static double _wrapDown(double value, double period) {
    if (period <= 0) return value <= 0 ? 0 : value;
    // Dart's `%` is the floor variant, so a negative value lands inside the
    // period without a sign fixup.
    final double wrapped = value % period;
    return wrapped == 0 ? period : wrapped;
  }

  // ---------------------------------------------------------------------
  // Document variables
  // ---------------------------------------------------------------------

  /// Converts a document's raw `vars` map the way `PreviewDocumentParser` does:
  /// numbers become doubles, booleans stay booleans, and a string is a plain
  /// string — except one leading `#`, which selects the expression language's
  /// own colour-literal grammar so `"accent": "#FFB02E26"` arrives as the same
  /// unsigned ARGB number an inline `#FFB02E26` compiles to. A MiniMessage tag
  /// like `"<#F2A535>"` is text, because it does not lead with the hash.
  ///
  /// Unlike the plugin, a malformed colour literal is kept as its raw string
  /// rather than rejected: the plugin refuses to load the document, while the
  /// editor has to keep rendering something while the author is still typing —
  /// the validation pass is what flags it there.
  ///
  /// Entries that are not JSON primitives are dropped; the plugin rejects the
  /// document over them.
  static Map<String, Object> parseVars(Map<String, Object?> raw) {
    final Map<String, Object> out = <String, Object>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      final Object? value = entry.value;
      if (value is bool) {
        out[entry.key] = value;
      } else if (value is num) {
        out[entry.key] = value.toDouble();
      } else if (value is String) {
        out[entry.key] = parseVarString(value);
      }
    }
    return out;
  }

  /// One `vars` string: a colour literal becomes its number, anything else
  /// stays the string it was written as.
  static Object parseVarString(String value) {
    if (!value.startsWith('#')) return value;
    try {
      final PExpr parsed = parsePreviewExpr(value);
      if (parsed is PNum) return parsed.value;
    } on PExprException {
      return value;
    }
    return value;
  }
}

/// `GoldenFakes.GAME_TIME`: every plugin golden was captured at this tick.
const double _goldenGameTime = 1234;

/// Fuel a simulated furnace refills to, one coal's worth of burn.
const double _furnaceBurnTicks = 300;

/// The plugin's fixed brew length and fuel gauge.
const double _brewTotalTicks = 400;
const double _maxFuelLevel = 20;
const double _cauldronMaxLevel = 3;
