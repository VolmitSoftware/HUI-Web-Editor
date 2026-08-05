/// The per-field documentation map the inspector's help popovers read.
///
/// The key list is a contract: the inspector looks docs up by these exact
/// strings, so a rename here is a silent loss of help in the UI. The content
/// assertions pin the runtime traps that are the whole reason this file exists —
/// each one is a fact a builder gets wrong without being told.
library;

import 'package:holoui_editor/config/field_docs.dart';
import 'package:test/test.dart';

/// Every key the inspector mounts help for.
const List<String> _contractKeys = <String>[
  'menu.offset',
  'menu.lockPosition',
  'menu.followPlayer',
  'menu.maxDistance',
  'menu.closeOnDeath',
  'menu.closeOnTeleport',
  'component.id',
  'component.offset',
  'button.highlightModifier',
  'button.hitbox',
  'toggle.condition',
  'toggle.expectedValue',
  'toggle.trueActions',
  'toggle.falseActions',
  'icon.item.item',
  'icon.item.count',
  'icon.item.customModelValue',
  'icon.customItem.provider',
  'icon.customItem.item',
  'icon.textImage.path',
  'icon.animated.source',
  'icon.animated.speed',
  'icon.text.text',
  'action.command.command',
  'action.command.source',
  'action.sound.sound',
  'action.sound.source',
  'action.sound.volume',
  'action.sound.pitch',
];

/// `File.java:12` or `File.java:12-34`, nothing else.
final RegExp _citationPattern = RegExp(r'^\w+\.java:\d+(-\d+)?$');

/// Dotted lower-camel path, matching the JSON keys the docs describe.
final RegExp _keyPattern = RegExp(
  r'^[a-z][A-Za-z0-9]*(\.[a-zA-Z][A-Za-z0-9]*)+$',
);

void main() {
  group('huiFieldDocs', () {
    test('covers every key the inspector mounts help for', () {
      for (final String key in _contractKeys) {
        expect(huiFieldDocs.containsKey(key), isTrue, reason: key);
      }
    });

    test('every key is a dotted field path', () {
      for (final String key in huiFieldDocs.keys) {
        expect(_keyPattern.hasMatch(key), isTrue, reason: key);
      }
    });

    test('every doc has a title and a body', () {
      for (final MapEntry<String, HuiFieldDoc> entry in huiFieldDocs.entries) {
        expect(entry.value.title.trim(), isNotEmpty, reason: entry.key);
        expect(entry.value.body.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('every doc cites one Java source line', () {
      for (final MapEntry<String, HuiFieldDoc> entry in huiFieldDocs.entries) {
        final String? citation = entry.value.citation;
        expect(citation, isNotNull, reason: entry.key);
        expect(
          _citationPattern.hasMatch(citation!),
          isTrue,
          reason: '${entry.key} -> $citation',
        );
      }
    });

    test('no body repeats its own title as the first sentence', () {
      for (final MapEntry<String, HuiFieldDoc> entry in huiFieldDocs.entries) {
        expect(
          entry.value.body.startsWith(entry.value.title),
          isFalse,
          reason: entry.key,
        );
      }
    });
  });

  group('huiFieldDoc', () {
    test('resolves a known key', () {
      expect(huiFieldDoc('menu.offset'), same(huiFieldDocs['menu.offset']));
    });

    test('returns null for a key with no doc', () {
      expect(huiFieldDoc('menu.notAThing'), isNull);
    });
  });

  group('runtime traps the docs must teach', () {
    String body(String key) => huiFieldDocs[key]!.body;

    test('the menu offset is measured from the feet and is never scaled', () {
      expect(body('menu.offset'), contains('feet'));
      expect(body('menu.offset'), contains('uiScale'));
    });

    test('component offsets are the ones uiScale multiplies', () {
      expect(body('component.offset'), contains('uiScale'));
    });

    test('the menu id comes from the filename and name is ignored', () {
      expect(body('menu.id'), contains('file'));
      expect(body('menu.id'), contains('name'));
    });

    test('highlightModifier remains stable while hovered', () {
      expect(body('button.highlightModifier'), contains('while'));
      expect(body('button.highlightModifier'), contains('stays fixed'));
    });

    test('button hitbox documents both anchors and scaling', () {
      expect(body('button.hitbox'), contains('uiScale'));
      expect(body('button.hitbox'), contains('linked'));
      expect(body('button.hitbox'), contains('detaches'));
    });

    test('a toggle condition is sampled once, at open', () {
      expect(body('toggle.condition'), contains('once'));
    });

    test('item count 0 becomes 1', () {
      expect(body('icon.item.count'), contains('0 is coerced to 1'));
    });

    test('the key is customModelValue, not customModelData', () {
      expect(body('icon.item.customModelValue'), contains('customModelValue'));
      expect(body('icon.item.customModelValue'), contains('customModelData'));
    });

    test('animated icons take source, not path', () {
      expect(body('icon.animated.source'), contains('source'));
      expect(body('icon.animated.source'), contains('path'));
    });

    test('animation speed is ticks at 50 ms', () {
      expect(body('icon.animated.speed'), contains('tick'));
      expect(body('icon.animated.speed'), contains('50 ms'));
    });

    test('an omitted command source dispatches from the console', () {
      expect(body('action.command.source'), contains('console'));
      expect(body('action.command.source'), contains('omitt'));
    });

    test('a sound with no category throws', () {
      expect(body('action.sound.source'), contains('throws'));
    });

    test('the sound volume default of 0 is silence', () {
      expect(body('action.sound.volume'), contains('0'));
    });
  });
}
