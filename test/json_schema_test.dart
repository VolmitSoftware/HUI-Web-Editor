/// The JSON-path model behind the code view's completion and hover.
///
/// The load-bearing test is [_walk]: it takes a fully-populated document of
/// every kind, walks the exact map the model's `toJson` produces, and fails on
/// any key the path model cannot resolve. That is what stops the completion
/// from drifting behind a format change — adding a key to a `toJson` without
/// declaring it here breaks this file, not a user's hover a month later.
library;

import 'dart:convert';

import 'package:gloss_editor/config/field_docs.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/config/gloss_menu_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/model/gloss_animation.dart';
import 'package:gloss_editor/model/gloss_bubble_style.dart';
import 'package:gloss_editor/model/gloss_damage_indicators.dart';
import 'package:gloss_editor/model/gloss_emoji.dart';
import 'package:gloss_editor/model/gloss_hologram.dart';
import 'package:gloss_editor/model/gloss_motd.dart';
import 'package:gloss_editor/model/gloss_real_drops.dart';
import 'package:gloss_editor/model/gloss_scoreboard.dart';
import 'package:gloss_editor/model/gloss_tablist.dart';
import 'package:gloss_editor/model/hui_actions.dart';
import 'package:gloss_editor/model/hui_component.dart';
import 'package:gloss_editor/model/hui_icons.dart';
import 'package:gloss_editor/model/hui_menu.dart';
import 'package:gloss_editor/model/vec3.dart';
import 'package:test/test.dart';

/// Every key in [value] that the model cannot resolve, as dotted paths.
List<String> _walk(GlossJsonNode? node, Object? value, String path) {
  final List<String> misses = <String>[];
  if (value is Map) {
    if (node is! GlossJsonObject) {
      misses.add('$path: the model has no object shape here');
      return misses;
    }
    final Object? raw = value['type'];
    final String? tag = raw is String ? raw : null;
    value.forEach((Object? key, Object? child) {
      final String name = key.toString();
      final GlossJsonField? field = node.field(name, tag: tag);
      if (field == null) {
        if (node.openKeyType != null) return;
        misses.add('$path.$name');
        return;
      }
      misses.addAll(_walk(field.node, child, '$path.$name'));
    });
    return misses;
  }
  if (value is List) {
    if (node is! GlossJsonArray) {
      if (value.isNotEmpty) {
        misses.add('$path: the model has no array shape here');
      }
      return misses;
    }
    for (int i = 0; i < value.length; i++) {
      misses.addAll(_walk(node.item, value[i], '$path[$i]'));
    }
  }
  return misses;
}

/// Every field in the graph under [root], each seen once even though nodes are
/// shared (one icon shape is reachable from six places).
List<(String, GlossJsonField)> _allFields(GlossJsonObject root) {
  final List<(String, GlossJsonField)> out = <(String, GlossJsonField)>[];
  final Set<GlossJsonNode> seen = Set<GlossJsonNode>.identity();
  void visit(GlossJsonNode node, String path) {
    if (!seen.add(node)) return;
    if (node is GlossJsonArray) {
      final GlossJsonNode? item = node.item;
      if (item != null) visit(item, '$path[]');
      return;
    }
    if (node is! GlossJsonObject) return;
    final List<GlossJsonField> fields = <GlossJsonField>[
      ...node.fields,
      for (final List<GlossJsonField> variant in node.variants.values)
        ...variant,
    ];
    for (final GlossJsonField field in fields) {
      out.add(('$path.${field.key}', field));
      final GlossJsonNode? child = field.node;
      if (child != null) visit(child, '$path.${field.key}');
    }
  }

  visit(root, r'$');
  return out;
}

HuiIconStyle _style() =>
    HuiIconStyle(blockLight: 7, skyLight: 3, glowColor: '#ff00ff');

/// A menu that writes every key the menu format has: all three component
/// types, all seven icon types, all six actions, and the optional blocks
/// (`hitbox`, `maxDistance`, brightness, glow) a default document leaves out.
HuiMenu _fullMenu() {
  final HuiButtonData button = HuiButtonData(
    0.1,
    <HuiAction>[
      HuiCommandAction('say hi', 'server', 'left_click'),
      HuiSoundAction('ui.button.click', 'block', 0.5, 1.5, 'right_click'),
      HuiMessageAction('<gold>hi</gold>', 'any'),
      HuiTeleportAction('world', 1, 2, 3, 4, 5, 'shift_left_click'),
      HuiConnectAction('lobby', 'shift_right_click'),
      HuiNavigateAction('shop', 'replace', 'any'),
    ],
    HuiTextIcon('hello', _style(), 20),
    HuiHitbox(2, 3, Vec3(1, 1, 1), HuiHitboxAnchor.menu),
    9,
    HuiHoverEasing.backOut,
  );
  final HuiToggleData toggle = HuiToggleData(
    0.2,
    '%vault_eco_balance%',
    '0',
    <HuiAction>[HuiMessageAction('on', 'any')],
    <HuiAction>[HuiMessageAction('off', 'any')],
    HuiItemIcon('minecraft:diamond', 3, 42, _style()),
    HuiBlockIcon('minecraft:stone', _style()),
    HuiHitbox(1, 1, Vec3(0, 1, 0), HuiHitboxAnchor.button),
    7,
    HuiHoverEasing.linear,
  );
  return HuiMenu(
    offset: Vec3(0, 1.7, 1),
    lockPosition: true,
    followPlayer: true,
    maxDistance: 16,
    closeOnDeath: true,
    closeOnTeleport: true,
    components: <HuiComponent>[
      HuiComponent('a', Vec3(0, 0, 0), button),
      HuiComponent('b', Vec3(1, 0, 0), toggle),
      HuiComponent(
        'c',
        Vec3(2, 0, 0),
        HuiDecorationData(HuiTextImageIcon('logo.png', _style())),
      ),
      HuiComponent(
        'd',
        Vec3(3, 0, 0),
        HuiDecorationData(
          HuiAnimatedImageIcon(<String>['a.png', 'b.png'], 2, _style()),
        ),
      ),
      HuiComponent(
        'e',
        Vec3(4, 0, 0),
        HuiDecorationData(HuiCustomItemIcon('oraxen', 'ruby', 2, _style())),
      ),
      HuiComponent(
        'f',
        Vec3(5, 0, 0),
        HuiDecorationData(HuiEntityIcon('minecraft:parrot', 1.5, 1.5)),
      ),
    ],
  );
}

const String _hologram =
    '{"schemaVersion":2,"revision":2,'
    '"anchor":{"world":"world","position":[1,2,3]},'
    '"lines":["a","b"],"seeThrough":false}';

const String _animation =
    '{"schemaVersion":1,"revision":2,"mode":"random",'
    '"frameIntervalMs":250,"frames":["a","b"]}';

const String _scoreboard =
    '{"schemaVersion":2,"revision":2,'
    '"select":{"priority":10,"when":"true"},'
    '"presentation":{"title":"t","lines":["a"],"hideNumbers":true},'
    '"variants":[{"id":"low","priority":20,"when":"viewer.health<5",'
    '"presentation":{"title":"low","lines":["b"],"hideNumbers":true}}]}';

const String _motd =
    '{"schemaVersion":1,"revision":2,"entries":[{"lines":["a","b"]}]}';

const String _emoji =
    '{"schemaVersion":1,"revision":2,"trigger":"<3","emoji":"U+2764;",'
    '"enabled":false}';

const String _bubble =
    '{"schemaVersion":4,"revision":2,"prefix":"&7","offset":[0,0.3,0],'
    '"wordWrapChars":32,"maxAliveMs":5000,'
    '"motion":{"translation":{"x":"0","y":"1","z":"0"},'
    '"scale":{"x":"1","y":"1","z":"1"},'
    '"rotation":{"x":"0","y":"0","z":"0"},"opacity":"1"},'
    '"shimmer":{"spawn":true,"flyAway":true,"color":"#ffffff","width":3,'
    '"durationMs":700,"spawnDelayMs":400,"flyAwayLeadMs":700},'
    '"followPlayer":true,"hideOwn":true,'
    '"select":{"priority":5,"when":"inGroup(\'viewer\', \'vip\')"}}';

const String _tablist =
    '{"schemaVersion":2,"revision":2,'
    '"headerFooter":{"enabled":true,"presentation":{"header":"h",'
    '"footer":"f"},"variants":[]},'
    r'"listNames":{"enabled":true,"presentation":{"format":"$player"},'
    r'"variants":[{"id":"op","priority":10,"when":"subject.op",'
    r'"presentation":{"format":"&6$player"}}]}}';

void main() {
  group('coverage', () {
    test('the menu model resolves every key the menu format writes', () {
      expect(_walk(glossMenuJsonSchema, _fullMenu().toJson(), r'$'), isEmpty);
    });

    test('the nine non-menu models resolve every key they write', () {
      final Map<String, Map<String, dynamic>> documents =
          <String, Map<String, dynamic>>{
            'hologram': decodeGlossHologramDoc(_hologram).toJson(),
            'animation': decodeGlossAnimationDoc(_animation).toJson(),
            'scoreboard': decodeGlossScoreboardDoc(_scoreboard).toJson(),
            'motd': decodeGlossMotdDoc(_motd).toJson(),
            'emoji': decodeGlossEmojiDoc(_emoji).toJson(),
            'bubbleStyle': decodeGlossBubbleStyleDoc(_bubble).toJson(),
            'tablist': decodeGlossTablistDoc(_tablist).toJson(),
            'realDrops': GlossRealDropSettingsDoc().toJson(),
            'damageIndicators': GlossDamageIndicatorsDoc().toJson(),
          };
      for (final MapEntry<String, Map<String, dynamic>> entry
          in documents.entries) {
        final GlossJsonObject? root = glossJsonSchemaFor(entry.key);
        expect(root, isNotNull, reason: entry.key);
        expect(
          _walk(root, entry.value, r'$'),
          isEmpty,
          reason: '${entry.key} writes keys the model does not know',
        );
      }
    });

    test('the walk reports a key the model does not declare', () {
      // Guards the guard: a coverage check that cannot fail proves nothing.
      final Map<String, dynamic> document = _fullMenu().toJson();
      document['notAKey'] = 1;
      (document['components'] as List<dynamic>).add(<String, dynamic>{
        'id': 'x',
        'offset': <double>[0, 0, 0],
        'data': <String, dynamic>{'type': 'button', 'alsoNotAKey': true},
      });
      expect(
        _walk(glossMenuJsonSchema, document, r'$'),
        unorderedEquals(<String>[
          r'$.notAKey',
          r'$.components[6].data.alsoNotAKey',
        ]),
      );
    });

    test('every editable kind has a model and the editor-only ones do not', () {
      expect(glossJsonSchemas.keys, hasLength(10));
      for (final String kind in <String>[
        'menu',
        'hologram',
        'animation',
        'scoreboard',
        'motd',
        'emoji',
        'bubbleStyle',
        'tablist',
        'realDrops',
        'damageIndicators',
      ]) {
        expect(glossJsonSchemaFor(kind), isNotNull, reason: kind);
      }
      expect(glossJsonSchemaFor('panel'), isNull);
      expect(glossJsonSchemaFor('containerPreview'), isNull);
    });
  });

  group('field declarations', () {
    test('every doc key resolves to a real field doc', () {
      final List<String> broken = <String>[];
      for (final GlossJsonObject root in glossJsonSchemas.values) {
        for (final (String path, GlossJsonField field) in _allFields(root)) {
          final String? key = field.docKey;
          if (key != null && huiFieldDoc(key) == null) {
            broken.add('$path -> $key');
          }
        }
      }
      expect(broken, isEmpty);
    });

    test('every field carries a title and a one-line summary', () {
      for (final GlossJsonObject root in glossJsonSchemas.values) {
        for (final (String path, GlossJsonField field) in _allFields(root)) {
          expect(field.title.trim(), isNotEmpty, reason: path);
          expect(field.summary.trim(), isNotEmpty, reason: path);
        }
      }
    });

    test('every default and accepted value is a JSON literal', () {
      for (final GlossJsonObject root in glossJsonSchemas.values) {
        for (final (String path, GlossJsonField field) in _allFields(root)) {
          final String? fallback = field.defaultLiteral;
          if (fallback != null) {
            expect(
              () => jsonDecode(fallback),
              returnsNormally,
              reason: '$path default',
            );
          }
          for (final GlossJsonValue value in field.values) {
            expect(
              () => jsonDecode(value.literal),
              returnsNormally,
              reason: '$path value ${value.literal}',
            );
          }
        }
      }
    });

    test('a discriminated object always offers its own type key', () {
      for (final GlossJsonObject root in glossJsonSchemas.values) {
        for (final (String path, GlossJsonField field) in _allFields(root)) {
          final GlossJsonNode? node = field.node;
          if (node is! GlossJsonObject || node.discriminator == null) continue;
          expect(
            node.field(node.discriminator!),
            isNotNull,
            reason: '$path has variants but no ${node.discriminator} field',
          );
        }
      }
    });
  });

  group('path resolution', () {
    List<JsonPathStep> path(List<Object> raw, {String? tagAt}) =>
        <JsonPathStep>[
          for (final Object step in raw)
            if (step is int)
              JsonPathStep.index(step)
            else
              JsonPathStep.key(step as String),
        ];

    test('walks into a list of objects', () {
      final GlossJsonNode? node = glossJsonNodeAt(
        glossMenuJsonSchema,
        path(<Object>['components', 0]),
      );
      expect(node, isA<GlossJsonObject>());
      expect((node! as GlossJsonObject).field('data'), isNotNull);
    });

    test('picks the variant the owner type names', () {
      final List<JsonPathStep> toData = <JsonPathStep>[
        const JsonPathStep.key('components'),
        const JsonPathStep.index(0),
        const JsonPathStep.key('data'),
      ];
      final GlossJsonNode? data = glossJsonNodeAt(glossMenuJsonSchema, toData);
      final GlossJsonObject object = data! as GlossJsonObject;
      expect(object.field('actions', tag: 'button'), isNotNull);
      expect(object.field('actions', tag: 'decoration'), isNull);
      expect(object.field('trueIcon', tag: 'toggle'), isNotNull);
      // An unknown tag falls back to the shared fields rather than to nothing.
      expect(object.field('type', tag: 'nonsense'), isNotNull);
      expect(object.field('actions', tag: 'nonsense'), isNull);
    });

    test('resolves a field five levels down, through two variants', () {
      final GlossJsonField? field =
          glossJsonFieldAt(glossMenuJsonSchema, <JsonPathStep>[
            const JsonPathStep.key('components'),
            const JsonPathStep.index(0),
            const JsonPathStep.key('data'),
            const JsonPathStep.key('icon', ownerType: 'button'),
            const JsonPathStep.key('style', ownerType: 'text'),
            const JsonPathStep.key('billboard'),
          ]);
      expect(field, isNotNull);
      expect(field!.type, GlossJsonType.string);
      expect(
        field.values.map((GlossJsonValue v) => v.literal),
        containsAll(<String>['"fixed"', '"center"']),
      );
    });

    test('leaves the model when the path does not exist', () {
      expect(
        glossJsonNodeAt(glossMenuJsonSchema, path(<Object>['nope'])),
        isNull,
      );
      expect(
        glossJsonFieldAt(glossMenuJsonSchema, path(<Object>['offset', 'x'])),
        isNull,
      );
    });

    test('renders a path the way HuiIssue spells one', () {
      expect(
        glossJsonPathText(<JsonPathStep>[
          const JsonPathStep.key('components'),
          const JsonPathStep.index(2),
          const JsonPathStep.key('data'),
        ]),
        r'$.components[2].data',
      );
    });
  });
}
