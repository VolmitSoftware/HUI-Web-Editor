/// The per-field documentation map the inspector's help popovers read.
///
/// The key list is a contract: the inspector looks docs up by these exact
/// strings, so a rename here is a silent loss of help in the UI. The content
/// assertions pin the runtime traps that are the whole reason this file exists —
/// each one is a fact a builder gets wrong without being told.
library;

import 'package:gloss_editor/config/field_docs.dart';
import 'package:gloss_editor/config/field_docs.g.dart';
import 'package:test/test.dart';

/// Every key the inspector mounts a hand-written popover for. The key list is
/// the contract: a rename here is a silent loss of help in the UI.
const List<String> _handWrittenKeys = <String>[
  'action.command.command',
  'action.command.source',
  'action.connect.server',
  'action.message.message',
  'action.sound.pitch',
  'action.sound.sound',
  'action.sound.source',
  'action.sound.volume',
  'action.teleport.world',
  'animation.frameIntervalMs',
  'animation.frames',
  'animation.id',
  'animation.mode',
  'bubble.followPlayer',
  'bubble.hideOwn',
  'bubble.id',
  'bubble.offset',
  'bubble.prefix',
  'bubble.select.priority',
  'bubble.shimmer.color',
  'bubble.shimmer.durationMs',
  'bubble.shimmer.flyAway',
  'button.highlightModifier',
  'button.hitbox',
  'button.hoverDurationTicks',
  'button.hoverEasing',
  'component.id',
  'component.offset',
  'emoji.emoji',
  'emoji.enabled',
  'emoji.id',
  'emoji.trigger',
  'hologram.anchor.position',
  'hologram.anchor.world',
  'hologram.billboard',
  'hologram.id',
  'hologram.lines',
  'hologram.pitch',
  'hologram.revision',
  'hologram.seeThrough',
  'hologram.yaw',
  'icon.animated.source',
  'icon.animated.speed',
  'icon.block.block',
  'icon.customItem.count',
  'icon.customItem.item',
  'icon.customItem.provider',
  'icon.entity.entity',
  'icon.entity.height',
  'icon.entity.width',
  'icon.item.count',
  'icon.item.customModelValue',
  'icon.item.item',
  'icon.playerHead.player',
  'icon.playerHead.refreshTicks',
  'icon.style.backgroundArgb',
  'icon.style.billboard',
  'icon.style.blockLight',
  'icon.style.cullingHeight',
  'icon.style.cullingWidth',
  'icon.style.glowColor',
  'icon.style.lineWidth',
  'icon.style.scaleX',
  'icon.style.scaleY',
  'icon.style.scaleZ',
  'icon.style.seeThrough',
  'icon.style.shadow',
  'icon.style.shadowRadius',
  'icon.style.shadowStrength',
  'icon.style.skyLight',
  'icon.style.textAlignment',
  'icon.style.textOpacity',
  'icon.style.viewRange',
  'icon.text.refreshTicks',
  'icon.text.text',
  'icon.textImage.path',
  'menu.closeOnDeath',
  'menu.closeOnTeleport',
  'menu.followPlayer',
  'menu.id',
  'menu.lockPosition',
  'menu.maxDistance',
  'menu.offset',
  'motd.entries',
  'motd.id',
  'motd.lines',
  'panel.follow.mode',
  'panel.follow.rotation',
  'panel.follow.targetPlayerUuid',
  'panel.identity',
  'panel.rootMenuId',
  'panel.transform.position',
  'panel.transform.rotation',
  'panel.transform.scale',
  'panel.transform.world',
  'panel.visibility.interactionRange',
  'panel.visibility.interactPermission',
  'panel.visibility.mode',
  'panel.visibility.viewPermission',
  'panel.visibility.viewRange',
  'condition.when',
  'scoreboard.id',
  'scoreboard.presentation.hideNumbers',
  'scoreboard.presentation.lines',
  'scoreboard.presentation.title',
  'tablist.headerFooter.enabled',
  'tablist.headerFooter.presentation.footer',
  'tablist.headerFooter.presentation.header',
  'tablist.id',
  'tablist.listNames.enabled',
  'tablist.listNames.presentation.format',
  'toggle.condition',
  'toggle.expectedValue',
  'toggle.falseActions',
  'toggle.trueActions',
];

/// Keys the inspector mounts that no hand-written entry covers, so the
/// schema-derived layer is the only thing standing behind them. A key moving
/// from this list to [_handWrittenKeys] is fine; a key falling out of both is
/// a popover that silently stopped rendering.
const List<String> _generatedOnlyKeys = <String>[
  'action.navigation',
  'action.navigation.mode',
  'action.navigation.target',
  'icon.style',
  'preview.card',
  'preview.card.accent',
  'preview.card.framed',
  'preview.card.minHalfWidth',
  'preview.card.show',
  'preview.card.title',
  'preview.element.background',
  'preview.element.color',
  'preview.element.height',
  'preview.element.index',
  'preview.element.size',
  'preview.element.show',
  'preview.element.text',
  'preview.element.visible',
  'preview.element.wellColor',
  'preview.element.width',
  'preview.element.x',
  'preview.element.y',
  'preview.element.z',
  'preview.match',
  'preview.match.blocks',
  'preview.match.entities',
  'preview.match.priority',
  'preview.match.special',
  'preview.repeat.count',
  'preview.repeat.var',
  'preview.show',
  'preview.variant.blocks',
  'preview.variant.entities',
  'preview.variant.vars',
  'preview.vars',
];

/// `File.java:12` or `File.java:12-34`, nothing else.
final RegExp _citationPattern = RegExp(r'^\w+\.java:\d+(-\d+)?$');

/// `gloss.schema.json#/$defs/itemIcon/properties/item`: the generated layer
/// cites the schema it was read out of, never a Java line it never saw.
final RegExp _schemaCitationPattern = RegExp(
  r'^[\w.-]+\.schema\.json#(/[\w$.\[\]-]+)+$',
);

/// Dotted lower-camel path, matching the JSON keys the docs describe.
final RegExp _keyPattern = RegExp(
  r'^[a-z][A-Za-z0-9]*(\.[a-zA-Z][A-Za-z0-9]*)+$',
);

void main() {
  group('huiFieldDocs', () {
    test('covers every key the inspector mounts help for', () {
      for (final String key in _handWrittenKeys) {
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

  group('huiGeneratedFieldDocs', () {
    test('covers the whole documented surface of both schemas', () {
      // The two schemas carry a description on roughly ninety properties
      // across two dozen `$defs`. A generator that silently stopped walking
      // one of them would still produce a valid map, just a much smaller one.
      expect(huiGeneratedFieldDocs.length, greaterThanOrEqualTo(100));
      expect(
        huiGeneratedFieldDocs.keys.where(
          (String k) => k.startsWith('preview.'),
        ),
        hasLength(greaterThanOrEqualTo(30)),
      );
      expect(
        huiGeneratedFieldDocs.keys.where((String k) => k.startsWith('icon.')),
        hasLength(greaterThanOrEqualTo(20)),
      );
    });

    test('backs every mounted key no hand-written entry covers', () {
      for (final String key in _generatedOnlyKeys) {
        expect(huiGeneratedFieldDocs.containsKey(key), isTrue, reason: key);
        expect(huiFieldDocs.containsKey(key), isFalse, reason: key);
      }
    });

    test('every key is a dotted field path', () {
      for (final String key in huiGeneratedFieldDocs.keys) {
        expect(_keyPattern.hasMatch(key), isTrue, reason: key);
      }
    });

    test('every doc has a title, a body and a schema citation', () {
      for (final MapEntry<String, HuiFieldDoc> entry
          in huiGeneratedFieldDocs.entries) {
        expect(entry.value.title.trim(), isNotEmpty, reason: entry.key);
        expect(entry.value.body.trim(), isNotEmpty, reason: entry.key);
        expect(
          _schemaCitationPattern.hasMatch(entry.value.citation ?? ''),
          isTrue,
          reason: '${entry.key} -> ${entry.value.citation}',
        );
      }
    });

    test('carries the constraints the pane cannot show inline', () {
      // `icon.style.*` has no descriptions in the schema at all, so a body
      // built only from `description` would have dropped these entirely.
      expect(
        huiGeneratedFieldDocs['icon.style.textOpacity']!.body,
        contains('0 through 255'),
      );
      expect(
        huiGeneratedFieldDocs['icon.style.billboard']!.body,
        contains('fixed, vertical, horizontal, center'),
      );
      expect(
        huiGeneratedFieldDocs['icon.text.refreshTicks']!.body,
        contains('Omitted, this is 10.'),
      );
    });
  });

  group('huiFieldDoc', () {
    test('resolves a known key', () {
      _expectDocSource(
        huiFieldDoc('menu.offset'),
        huiFieldDocs['menu.offset']!,
      );
    });

    test('returns null for a key with no doc', () {
      expect(huiFieldDoc('menu.notAThing'), isNull);
    });

    test('a hand-written doc wins over the generated one', () {
      // Both maps carry `icon.item.count`; the hand-written body is the one
      // that knows 0 becomes 1, which is the whole reason it exists.
      expect(huiGeneratedFieldDocs.containsKey('icon.item.count'), isTrue);
      _expectDocSource(
        huiFieldDoc('icon.item.count'),
        huiFieldDocs['icon.item.count']!,
      );
    });

    test('falls back to the generated doc when nothing is hand-written', () {
      expect(huiFieldDocs.containsKey('preview.element.wellColor'), isFalse);
      _expectDocSource(
        huiFieldDoc('preview.element.wellColor'),
        huiGeneratedFieldDocs['preview.element.wellColor']!,
      );
    });

    test('resolves every key the inspector mounts', () {
      for (final String key in <String>[
        ..._handWrittenKeys,
        ..._generatedOnlyKeys,
      ]) {
        expect(huiFieldDoc(key), isNotNull, reason: key);
      }
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

    test('an omitted command source dispatches as the player', () {
      expect(body('action.command.source'), contains('console'));
      expect(body('action.command.source'), contains('omitted key'));
      expect(body('action.command.source'), contains('clicking player'));
    });

    test('a sound with no category plays on master', () {
      expect(body('action.sound.source'), contains('master'));
      expect(body('action.sound.source'), contains('optional'));
    });

    test('an omitted sound volume is 1 and an explicit 0 is silence', () {
      expect(body('action.sound.volume'), contains('is 1'));
      expect(body('action.sound.volume'), contains('0 is silence'));
    });

    test('the text-only display style fields say they are text-only', () {
      for (final String key in <String>[
        'icon.style.shadow',
        'icon.style.seeThrough',
        'icon.style.backgroundArgb',
        'icon.style.textOpacity',
        'icon.style.lineWidth',
      ]) {
        expect(body(key).toLowerCase(), contains('text'), reason: key);
      }
      expect(body('icon.style.shadow'), contains('inert'));
      expect(body('icon.style.lineWidth'), contains('16384'));
    });

    test('brightness is a pair and one channel alone is rejected', () {
      expect(body('icon.style.blockLight'), contains('alone'));
      expect(body('icon.style.skyLight'), contains('alone'));
    });

    test('a ground shadow needs both radius and strength', () {
      expect(body('icon.style.shadowRadius'), contains('strength'));
      expect(body('icon.style.shadowStrength'), contains('radius'));
    });

    test('culling is not a click dimension and scale Z is not either', () {
      expect(body('icon.style.cullingWidth'), contains('no effect on click'));
      expect(body('icon.style.scaleZ'), contains('never affects the click'));
    });

    test('display view range is a multiplier, not blocks', () {
      expect(body('icon.style.viewRange'), contains('multiplier'));
      expect(body('icon.style.viewRange'), contains('64'));
    });

    test('a glow colour is also the glow switch', () {
      expect(body('icon.style.glowColor'), contains('no separate toggle'));
    });

    test('panel position changes meaning under a follow mode', () {
      expect(body('panel.transform.position'), contains('follow mode'));
      expect(body('panel.transform.position'), contains('jumps'));
    });

    test('panel rotation is silently wrapped by the server', () {
      expect(body('panel.transform.rotation'), contains('-180 to 180'));
    });

    test('a hidden panel still costs work every tick', () {
      expect(body('panel.visibility.mode'), contains('does not disable'));
    });

    test('the interact permission hides nothing', () {
      expect(
        body('panel.visibility.interactPermission'),
        contains('never on the render path'),
      );
    });

    test('one wide panel widens the query for every player', () {
      expect(body('panel.visibility.viewRange'), contains('every player'));
    });
  });
}

void _expectDocSource(HuiFieldDoc? actual, HuiFieldDoc source) {
  expect(actual, isNotNull);
  expect(actual!.title, source.title);
  expect(actual.body, source.body);
  expect(actual.citation, source.citation);
}
