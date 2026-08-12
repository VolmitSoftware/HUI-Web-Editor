/// The editor-side sync gate for the preview variable contract, plus the
/// behaviour of the simulated state context every preview surface renders
/// against.
///
/// `web/assets/catalog/preview-variables.json` is
/// `HoloUi/src/test/resources/preview-variables.json` copied verbatim — the
/// plugin's own `VariableCatalogSyncTest` pins that file against
/// `PreviewStateAdapters.catalog()`, so pinning [PreviewSim] against the same
/// file makes any plugin-side variable change fail here too.
library;

import 'dart:convert';
import 'dart:io';

import 'package:holoui_editor/logic/preview_expr.dart';
import 'package:holoui_editor/logic/preview_sim.dart';
import 'package:holoui_editor/services/catalogs.dart';
import 'package:test/test.dart';

/// The shipped assets, read straight from the bundle the editor serves.
const String variablesAssetPath = 'web/assets/catalog/preview-variables.json';
const String langAssetPath = 'web/assets/catalog/preview-lang-en.json';

/// `holoui.preview.*` key count at the time the snapshot was generated; a
/// truncated or unresolved asset must fail loudly rather than pass with
/// nothing to check.
const int minimumLangMessages = 50;

/// Sample arguments for every function the catalog documents, so the
/// `functions` section is pinned the same way the variables are.
const Map<String, List<Object?>> functionSampleArgs = <String, List<Object?>>{
  'lang': <Object?>['holoui.preview.state.idle'],
  'count': <Object?>[0.0],
  'occupied': <Object?>[0.0],
  'item': <Object?>[0.0],
  'plain': <Object?>['&aHi'],
  'readable': <Object?>['IRON_ORE'],
};

String readAsset(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing shipped asset: $path');
  }
  return file.readAsStringSync();
}

/// Evaluates [source] against [sim] the way a compiled document field does.
Object eval(String source, PreviewSim sim) =>
    evalPreviewExpr(parsePreviewExpr(source), sim);

void main() {
  final HuiPreviewVariableCatalog catalog = HuiPreviewVariableCatalog.parse(
    readAsset(variablesAssetPath),
  );
  final PreviewLangCatalog lang = PreviewLangCatalog.parse(
    readAsset(langAssetPath),
  );

  group('variable catalog sync gate', () {
    test('the shipped catalog carries the plugin groups', () {
      expect(catalog.isEmpty, isFalse);
      expect(
        catalog.categoryNames,
        containsAll(<String>[
          'universal',
          'inventory',
          'furnace',
          'brewing',
          'beehive',
          'cauldron',
          'jukebox',
        ]),
      );
    });

    test(
      'every catalog group is claimed by at least one simulated category',
      () {
        final Set<String> claimed = <String>{
          for (final List<String> groups in previewSimCategoryGroups.values)
            ...groups,
        };
        expect(claimed, containsAll(catalog.categoryNames));
        // And nothing is claimed that the catalog does not define.
        expect(catalog.categoryNames.toSet(), containsAll(claimed));
      },
    );

    test('every simulated category is one of the contract categories', () {
      expect(
        previewSimCategoryGroups.keys,
        unorderedEquals(previewSimCategories),
      );
    });

    for (final String category in previewSimCategories) {
      test(
        '$category resolves every cataloged variable with the right type',
        () {
          final PreviewSim sim = PreviewSim(category, lang: lang);
          for (final String group in previewSimCategoryGroups[category]!) {
            for (final PreviewVariableEntry entry in catalog.variables(group)) {
              final Object? value = sim.variable(entry.name);
              expect(
                value,
                isNotNull,
                reason: '$category does not publish ${entry.name}',
              );
              switch (entry.type) {
                case 'number':
                  expect(
                    value,
                    isA<double>(),
                    reason: '${entry.name} in $category',
                  );
                case 'string':
                  expect(
                    value,
                    isA<String>(),
                    reason: '${entry.name} in $category',
                  );
                case 'boolean':
                  expect(
                    value,
                    isA<bool>(),
                    reason: '${entry.name} in $category',
                  );
                default:
                  fail(
                    'unhandled catalog type ${entry.type} for ${entry.name}',
                  );
              }
            }
          }
        },
      );

      test('$category publishes nothing the catalog does not define', () {
        final PreviewSim sim = PreviewSim(category, lang: lang);
        final Set<String> cataloged = <String>{
          for (final String group in previewSimCategoryGroups[category]!)
            for (final PreviewVariableEntry entry in catalog.variables(group))
              entry.name,
        };
        expect(sim.variableNames.toSet(), unorderedEquals(cataloged));
        expect(sim.snapshot().keys.toSet(), unorderedEquals(cataloged));
      });
    }

    test('every cataloged function resolves through the sim', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      for (final PreviewFunctionEntry entry in catalog.functions) {
        final List<Object?>? args = functionSampleArgs[entry.name];
        expect(
          args,
          isNotNull,
          reason: 'no sample arguments for ${entry.name}',
        );
        expect(
          sim.call(entry.name, args!),
          isNotNull,
          reason: '${entry.name} did not resolve',
        );
      }
    });
  });

  group('furnace preset', () {
    test('reproduces the plugin golden state (GoldenFakes.smelting)', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      expect(sim.variable('time'), 1234.0);
      expect(sim.variable('blockType'), 'FURNACE');
      expect(sim.variable('customName'), '');
      expect(sim.variable('cookTime'), 100.0);
      expect(sim.variable('cookTimeTotal'), 200.0);
      expect(sim.variable('burnTime'), 300.0);
      expect(sim.variable('fuelSeconds'), 15.0);
      expect(sim.variable('bankedXp'), 1.5);
      expect(sim.variable('lit'), isTrue);
      expect(sim.variable('surge.active'), isFalse);
      expect(sim.variable('surge.gain'), 0.0);
      expect(sim.variable('inventory.size'), 3.0);
      expect(sim.variable('inventory.occupied'), 3.0);
      expect(sim.call('item', <Object?>[0.0]), 'IRON_ORE');
      expect(sim.call('count', <Object?>[0.0]), 1.0);
      expect(sim.call('item', <Object?>[1.0]), 'COAL');
      expect(sim.call('count', <Object?>[1.0]), 8.0);
      expect(sim.call('item', <Object?>[2.0]), 'IRON_INGOT');
      expect(sim.call('count', <Object?>[2.0]), 2.0);
    });

    test('renders the shipped furnace state line', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..vars = PreviewSim.parseVars(<String, Object?>{
          'activeItemKey': 'holoui.preview.state.smelting_item',
          'activeKey': 'holoui.preview.state.smelting',
        });
      const String source =
          'lang(occupied(0) ? vars.activeItemKey : vars.activeKey, '
          'occupied(0) ? readable(item(0)) : round(cookTime * 100 / cookTimeTotal), '
          'round(cookTime * 100 / cookTimeTotal))';
      expect(eval(source, sim), 'Smelting Iron Ore 50%');
    });
  });

  group('category presets', () {
    test('carry the state their plugin fixture was captured from', () {
      final PreviewSim brewing = PreviewSim('brewing', lang: lang);
      expect(brewing.variable('blockType'), 'BREWING_STAND');
      expect(brewing.variable('brewTotal'), 400.0);
      expect(brewing.variable('fuelLevel'), 10.0);
      expect(brewing.variable('maxFuel'), 20.0);
      expect(brewing.variable('inventory.size'), 5.0);
      expect(brewing.variable('inventory.occupied'), 4.0);

      final PreviewSim beehive = PreviewSim('beehive', lang: lang);
      expect(beehive.variable('bees'), 2.0);
      expect(beehive.variable('maxBees'), 3.0);
      expect(beehive.variable('honey'), 3.0);
      expect(beehive.variable('maxHoney'), 5.0);

      final PreviewSim cauldron = PreviewSim('cauldron', lang: lang);
      expect(cauldron.variable('blockType'), 'WATER_CAULDRON');
      expect(cauldron.variable('level'), 2.0);
      expect(cauldron.variable('maxLevel'), 3.0);
      expect(cauldron.variable('fluid'), 'water');

      final PreviewSim jukebox = PreviewSim('jukebox', lang: lang);
      expect(jukebox.variable('playing'), isTrue);
      // `record` is already display text, exactly as the plugin publishes it.
      expect(jukebox.variable('record'), 'Music Disc Cat');

      final PreviewSim entity = PreviewSim('entity', lang: lang);
      expect(entity.variable('blockType'), 'HOPPER_MINECART');
      expect(entity.variable('inventory.size'), 5.0);
      expect(entity.variable('inventory.occupied'), 2.0);

      final PreviewSim statics = PreviewSim('statics', lang: lang);
      expect(statics.variable('blockType'), '');
      expect(statics.variable('inventory.size'), isNull);
    });

    test('an unknown category behaves like a target-less one', () {
      final PreviewSim sim = PreviewSim('nonsense', lang: lang);
      expect(sim.variableNames, <String>['time', 'blockType', 'customName']);
      expect(sim.variable('blockType'), '');
      sim.tick(20);
      expect(sim.variable('time'), 1254.0);
    });

    test('reset restores the canned state but keeps vars', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..vars = PreviewSim.parseVars(<String, Object?>{'accent': '#F2A535'})
        ..setSurge(true)
        ..tick(60);
      expect(sim.variable('cookTime'), isNot(100.0));
      sim.reset();
      expect(sim.variable('time'), 1234.0);
      expect(sim.variable('cookTime'), 100.0);
      expect(sim.variable('surge.active'), isFalse);
      expect(sim.variable('vars.accent'), 0xFFF2A535.toDouble());
    });
  });

  group('lang', () {
    final PreviewSim sim = PreviewSim('furnace', lang: lang);

    test('binds positional arguments onto the template placeholders', () {
      expect(
        sim.call('lang', <Object?>[
          'holoui.preview.state.smelting_item',
          'Iron Ore',
          42.0,
        ]),
        'Smelting Iron Ore 42%',
      );
    });

    test('renders numbers through the integral-string rule', () {
      expect(
        sim.call('lang', <Object?>['holoui.preview.stat.fuel_seconds', 15.0]),
        'Fuel 15s',
      );
      expect(
        sim.call('lang', <Object?>['holoui.preview.state.surge_suffix', 1.5]),
        '  +1.5s',
      );
    });

    test('a key with no placeholders ignores extra arguments', () {
      expect(
        sim.call('lang', <Object?>['holoui.preview.state.idle', 'unused']),
        'Idle',
      );
    });

    test('an unknown key renders as itself', () {
      expect(
        sim.call('lang', <Object?>['holoui.nope.missing']),
        'holoui.nope.missing',
      );
    });

    test('an unbound placeholder stays literal', () {
      expect(
        sim.call('lang', <Object?>[
          'holoui.preview.state.smelting_item',
          'Iron Ore',
        ]),
        'Smelting Iron Ore {percent}%',
      );
    });

    test('inserted values are untrusted: section codes are stripped', () {
      expect(
        sim.call('lang', <Object?>[
          'holoui.preview.theme.title.mobile',
          '§cRed§r Cart',
        ]),
        '&7&lRed Cart',
      );
    });

    test('rejects a missing or non-string key', () {
      expect(
        () => sim.call('lang', <Object?>[]),
        throwsA(isA<PExprException>()),
      );
      expect(
        () => sim.call('lang', <Object?>[1.0]),
        throwsA(isA<PExprException>()),
      );
    });

    test('placeholder scanning dedupes and honours the {{ escape', () {
      expect(
        PreviewLangCatalog.orderedPlaceholders('a {x} b {y} c {x}'),
        <String>['x', 'y'],
      );
      expect(
        PreviewLangCatalog.orderedPlaceholders('{{item} {percent}%'),
        <String>['percent'],
      );
      expect(
        PreviewLangCatalog.orderedPlaceholders('no placeholders'),
        <String>[],
      );
    });

    test('a repeated placeholder takes one argument and fills every slot', () {
      const PreviewLangCatalog twice = PreviewLangCatalog(<String, String>{
        'k': '{x} and {x}',
      });
      expect(twice.render('k', <Object?>['one']), 'one and one');
    });

    test('the {{ escape renders as a literal brace', () {
      const PreviewLangCatalog escaped = PreviewLangCatalog(<String, String>{
        'k': '{{x} {y}',
      });
      expect(escaped.render('k', <Object?>['v']), '{{x} v');
    });
  });

  group('tick', () {
    test('advances the clock in every category', () {
      for (final String category in previewSimCategories) {
        final PreviewSim sim = PreviewSim(category, lang: lang);
        final double before = sim.variable('time')! as double;
        sim.tick(20);
        expect(sim.variable('time'), before + 20.0, reason: category);
      }
    });

    test('advances furnace cook time and wraps it at the total', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      sim.tick(20);
      expect(sim.variable('cookTime'), 120.0);
      expect(sim.variable('burnTime'), 280.0);
      expect(sim.variable('fuelSeconds'), 14.0);
      sim.tick(100);
      expect(sim.variable('cookTime'), 20.0);
    });

    test('burns fuel down and refuels rather than sticking at zero', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      sim.tick(300);
      expect(sim.variable('burnTime') as double, greaterThan(0.0));
      expect(sim.variable('lit'), isTrue);
    });

    test('counts brewing time down and wraps it at the total', () {
      final PreviewSim sim = PreviewSim('brewing', lang: lang);
      expect(sim.variable('brewTime'), 200.0);
      sim.tick(20);
      expect(sim.variable('brewTime'), 180.0);
      sim.tick(200);
      expect(sim.variable('brewTime'), 380.0);
      expect(sim.variable('fuelLevel'), 9.0);
    });

    test('fills the hive over time and wraps at the maximum', () {
      final PreviewSim sim = PreviewSim('beehive', lang: lang);
      expect(sim.variable('honey'), 3.0);
      sim.tick(previewSimHoneyPeriod);
      expect(sim.variable('honey'), 4.0);
      sim.tick(previewSimHoneyPeriod * 2);
      expect(sim.variable('honey'), 0.0);
    });

    test('leaves a plain container alone apart from the clock', () {
      final PreviewSim sim = PreviewSim('chest', lang: lang);
      sim.tick(100);
      expect(sim.variable('inventory.size'), 27.0);
      expect(sim.variable('inventory.occupied'), 3.0);
    });

    test('a non-positive tick changes nothing', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      sim.tick(0);
      sim.tick(-40);
      expect(sim.variable('time'), 1234.0);
      expect(sim.variable('cookTime'), 100.0);
    });
  });

  group('surge', () {
    test('the toggle publishes surge.active and surge.gain', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      expect(sim.variable('surge.active'), isFalse);
      sim.setSurge(true);
      expect(sim.variable('surge.active'), isTrue);
      expect(sim.variable('surge.gain'), previewSimDefaultSurgeGain);
      sim.setSurge(true, gain: 2.5);
      expect(sim.variable('surge.gain'), 2.5);
      sim.setSurge(false);
      expect(sim.variable('surge.active'), isFalse);
      expect(sim.variable('surge.gain'), 0.0);
    });

    test('a surging furnace gains its extra seconds of cook progress', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..setSurge(true, gain: 1.0);
      sim.tick(20);
      // 20 real ticks plus one second of gained progress.
      expect(sim.variable('cookTime'), 140.0);
    });

    test('a surging brew loses its extra seconds off the countdown', () {
      final PreviewSim sim = PreviewSim('brewing', lang: lang)
        ..setSurge(true, gain: 1.0);
      sim.tick(20);
      expect(sim.variable('brewTime'), 160.0);
    });

    test('renders the surge suffix the shipped document draws', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..setSurge(true, gain: 1.5);
      const String source =
          "surge.active ? lang('holoui.preview.state.surge_suffix', "
          'surge.gain == floor(surge.gain) ? str(surge.gain) : fixed(surge.gain, 1)) : \'\'';
      expect(eval(source, sim), '  +1.5s');
    });
  });

  group('slot functions', () {
    test('read the sample items', () {
      final PreviewSim sim = PreviewSim('chest', lang: lang);
      expect(sim.call('count', <Object?>[1.0]), 32.0);
      expect(sim.call('occupied', <Object?>[1.0]), isTrue);
      expect(sim.call('item', <Object?>[1.0]), 'STONE');
    });

    test('an empty slot reads as empty rather than missing', () {
      final PreviewSim sim = PreviewSim('chest', lang: lang);
      expect(sim.call('count', <Object?>[9.0]), 0.0);
      expect(sim.call('occupied', <Object?>[9.0]), isFalse);
      expect(sim.call('item', <Object?>[9.0]), '');
    });

    test('an out-of-range slot reads as empty', () {
      final PreviewSim sim = PreviewSim('chest', lang: lang);
      expect(sim.call('count', <Object?>[99.0]), 0.0);
      expect(sim.call('occupied', <Object?>[-1.0]), isFalse);
      expect(sim.call('item', <Object?>[99.0]), '');
    });

    test('a target with no inventory reads as empty', () {
      final PreviewSim sim = PreviewSim('statics', lang: lang);
      expect(sim.call('count', <Object?>[0.0]), 0.0);
      expect(sim.call('occupied', <Object?>[0.0]), isFalse);
      expect(sim.call('item', <Object?>[0.0]), '');
    });

    test('reject a wrong argument count or type', () {
      final PreviewSim sim = PreviewSim('chest', lang: lang);
      expect(
        () => sim.call('count', <Object?>[]),
        throwsA(isA<PExprException>()),
      );
      expect(
        () => sim.call('item', <Object?>['0']),
        throwsA(isA<PExprException>()),
      );
      expect(
        () => sim.call('occupied', <Object?>[0.0, 1.0]),
        throwsA(isA<PExprException>()),
      );
    });

    test('the occupied count follows the sample items', () {
      final PreviewSim sim = PreviewSim('enderChest', lang: lang);
      expect(sim.variable('inventory.size'), 27.0);
      expect(sim.variable('inventory.occupied'), 2.0);
      sim.slotItems = const <SimSlotItem>[SimSlotItem(0, 'DIAMOND', 1)];
      expect(sim.variable('inventory.occupied'), 1.0);
    });
  });

  group('vars', () {
    test(
      'colour literals arrive as the numbers an inline literal compiles to',
      () {
        final Map<String, Object> vars = PreviewSim.parseVars(<String, Object?>{
          'accent': '#F2A535',
          'short': '#ABC',
          'well': '#FF15151B',
          'tag': '<#F2A535>',
          'style': 'furnace',
          'segments': 8,
          'framed': true,
        });
        expect(vars['accent'], 0xFFF2A535.toDouble());
        expect(vars['short'], 0xFFAABBCC.toDouble());
        expect(vars['well'], 0xFF15151B.toDouble());
        expect(vars['tag'], '<#F2A535>');
        expect(vars['style'], 'furnace');
        expect(vars['segments'], 8.0);
        expect(vars['framed'], true);
      },
    );

    test('a malformed colour literal stays the raw string', () {
      final Map<String, Object> vars = PreviewSim.parseVars(<String, Object?>{
        'broken': '#GG',
      });
      expect(vars['broken'], '#GG');
    });

    test('non-primitive entries are dropped', () {
      final Map<String, Object> vars = PreviewSim.parseVars(<String, Object?>{
        'list': <Object?>[1, 2],
        'nothing': null,
        'kept': 'yes',
      });
      expect(vars.keys, <String>['kept']);
    });

    test('resolve under the vars prefix only', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..vars = PreviewSim.parseVars(<String, Object?>{'accent': '#F2A535'});
      expect(sim.variable('vars.accent'), 0xFFF2A535.toDouble());
      expect(sim.variable('accent'), isNull);
      expect(sim.variable('vars.missing'), isNull);
      expect(() => eval('vars.missing', sim), throwsA(isA<PExprException>()));
    });

    test('a document variable can never shadow a built-in', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang)
        ..vars = PreviewSim.parseVars(<String, Object?>{'cookTime': 7});
      expect(sim.variable('cookTime'), 100.0);
      expect(sim.variable('vars.cookTime'), 7.0);
    });
  });

  group('overrides', () {
    test('pin a variable over the simulated value', () {
      final PreviewSim sim = PreviewSim('furnace', lang: lang);
      sim.overrides['cookTime'] = 180.0;
      sim.overrides['customName'] = 'Ore Line';
      expect(sim.variable('cookTime'), 180.0);
      expect(sim.variable('customName'), 'Ore Line');
      sim.tick(20);
      expect(
        sim.variable('cookTime'),
        180.0,
        reason: 'a pinned value does not tick',
      );
      sim.overrides.remove('cookTime');
      expect(sim.variable('cookTime'), 120.0);
    });
  });

  group('shipped lang snapshot', () {
    test('carries the whole holoui.preview namespace', () {
      expect(lang.messages.length, greaterThanOrEqualTo(minimumLangMessages));
      for (final String id in lang.messages.keys) {
        expect(id, startsWith('holoui.preview.'), reason: id);
      }
    });

    test('matches HoloMessages.java entry for entry', () {
      expect(
        lang.template('holoui.preview.state.smelting_item'),
        'Smelting {item} {percent}%',
      );
      expect(
        lang.template('holoui.preview.stat.bees_and_honey'),
        'Bees {bees}/{maximumBees}   Honey {honey}/{maximumHoney}',
      );
      expect(
        lang.template('holoui.preview.state.surge_suffix'),
        '  +{seconds}s',
      );
      expect(
        lang.template('holoui.preview.theme.title.shulker'),
        '&l{color} Shulker',
      );
      expect(lang.template('holoui.preview.stat.xp_gain'), 'XP +{experience}');
    });

    test('holds no chat or command keys', () {
      expect(lang.template('holoui.message.preview_scale.size'), isNull);
      expect(lang.template('holoui.command.previews.list'), isNull);
    });
  });

  group('catalog assets', () {
    test('the variable catalog decodes its descriptions and types', () {
      final PreviewVariableEntry? cookTime = catalog.variable(
        'furnace',
        'cookTime',
      );
      expect(cookTime, isNotNull);
      expect(cookTime!.type, 'number');
      expect(cookTime.description, isNotEmpty);
      final List<PreviewFunctionEntry> langFn = catalog.functions
          .where((PreviewFunctionEntry f) => f.name == 'lang')
          .toList();
      expect(langFn, hasLength(1));
      expect(langFn.first.returns, 'string');
      expect(langFn.first.args, isNotEmpty);
    });

    test('both parsers degrade to empty rather than throwing', () {
      expect(HuiPreviewVariableCatalog.parse('not json').isEmpty, isTrue);
      expect(
        HuiPreviewVariableCatalog.parse('{"categories": 7}').isEmpty,
        isTrue,
      );
      expect(PreviewLangCatalog.parse('not json').isEmpty, isTrue);
      expect(PreviewLangCatalog.parse('{"messages": []}').isEmpty, isTrue);
      expect(
        PreviewLangCatalog.parse('{"messages": {"a.b": 7}}').isEmpty,
        isTrue,
      );
    });

    test('a sim with no snapshot still renders keys as themselves', () {
      final PreviewSim sim = PreviewSim('chest');
      expect(
        sim.call('lang', <Object?>['holoui.preview.state.idle']),
        'holoui.preview.state.idle',
      );
    });

    test('the empty catalogs carry empty preview assets', () {
      final HuiCatalogs empty = HuiCatalogs.empty();
      expect(empty.previewVariables.isEmpty, isTrue);
      expect(empty.previewLang.isEmpty, isTrue);
    });

    test('build keeps the preview assets it is handed', () {
      final HuiCatalogs built = HuiCatalogs.build(
        materials: const <MaterialEntry>[],
        sounds: const <String>[],
        loaded: false,
        previewVariables: catalog,
        previewLang: lang,
      );
      expect(built.previewVariables.isEmpty, isFalse);
      expect(built.previewLang.isEmpty, isFalse);
    });

    test('the shipped variable catalog keeps the contract shape', () {
      final Object? decoded = jsonDecode(readAsset(variablesAssetPath));
      expect(decoded, isA<Map<String, Object?>>());
      expect(
        (decoded! as Map<String, Object?>).keys,
        containsAll(<String>['categories', 'functions']),
      );
    });
  });

  /// The card surface only runs its 50 ms clock for a document that reads one
  /// of [previewTickVaryingVariables]. A variable that starts moving without
  /// being declared there would silently freeze on screen, so the declaration
  /// is pinned against what `tick` actually does rather than trusted.
  group('the declared tick-varying variables', () {
    test('are the only published values a tick moves, in every category', () {
      for (final String category in previewSimCategories) {
        final PreviewSim sim = PreviewSim(category);
        final Map<String, Object> before = sim.snapshot();
        // Long enough to cross the honey period, which is the slowest counter.
        sim.tick(previewSimHoneyPeriod + 1);
        final Map<String, Object> after = sim.snapshot();
        final Set<String> moved = <String>{
          for (final String name in before.keys)
            if (before[name] != after[name]) name,
        };
        expect(
          moved.difference(previewTickVaryingVariables),
          isEmpty,
          reason:
              '$category moved a variable that '
              'previewTickVaryingVariables does not declare',
        );
      }
    });

    test('every declared name is one some category actually publishes', () {
      final Set<String> published = <String>{
        for (final String category in previewSimCategories)
          ...PreviewSim(category).variableNames,
      };
      expect(published, containsAll(previewTickVaryingVariables));
    });

    test('a running furnace really does move the ones it publishes', () {
      final PreviewSim sim = PreviewSim('furnace');
      final Map<String, Object> before = sim.snapshot();
      sim.tick(40);
      final Map<String, Object> after = sim.snapshot();
      expect(before['cookTime'], isNot(after['cookTime']));
      expect(before['burnTime'], isNot(after['burnTime']));
      expect(before['time'], isNot(after['time']));
      expect(before['cookTimeTotal'], after['cookTimeTotal']);
    });
  });

  group('previewCategoryVariableNames', () {
    test('matches PreviewSim(category).variableNames for every category', () {
      for (final String category in previewSimCategories) {
        expect(
          previewCategoryVariableNames(category),
          PreviewSim(category).variableNames,
          reason: category,
        );
      }
    });

    test('an unknown category name falls back to the universal group', () {
      expect(
        previewCategoryVariableNames('not-a-real-category'),
        previewSimGroupVariables['universal'],
      );
    });
  });
}
