import 'dart:convert';
import 'dart:math' as math;

import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/preview_card_edit.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_expr.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/preview_variant_resolver.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/catalogs.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

final class _MemoryStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

EditorStore _store({HuiCatalogs? catalogs, ImageLibrary? images}) {
  final _MemoryStorage storage = _MemoryStorage();
  return EditorStore(
    workspace: Workspace(read: storage.read, write: storage.write),
    catalogs: catalogs,
    images: images,
    autosaveDelay: Duration.zero,
  );
}

EditorStore _resourceStore() {
  const String pixel =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
      'iZk9HQAAAABJRU5ErkJggg==';
  final ImageLibrary images = ImageLibrary(
    autoLoad: false,
    writer: (String _, String _) => true,
  );
  images.upsertAll(<StoredImage>[
    const StoredImage(
      path: 'showcase/static.png',
      dataUri: pixel,
      width: 1,
      height: 1,
    ),
    const StoredImage(
      path: 'showcase/frame-01.png',
      dataUri: pixel,
      width: 1,
      height: 1,
    ),
    const StoredImage(
      path: 'showcase/frame-02.png',
      dataUri: pixel,
      width: 1,
      height: 1,
    ),
  ]);
  final HuiCustomItemCatalog customItems = HuiCustomItemCatalog.parse(
    '{"providers":["itemsadder"],"items":[{"provider":"itemsadder",'
    '"id":"showcase:ruby","material":"diamond"}]}',
  )!;
  return _store(
    catalogs: HuiCatalogs.build(
      materials: const <MaterialEntry>[
        MaterialEntry('stone', null),
        MaterialEntry('diamond', null),
      ],
      sounds: const <String>['ui.button.click', 'block.note_block.harp'],
      loaded: true,
      customItems: customItems,
    ),
    images: images,
  );
}

Iterable<HuiIcon> _menuIcons(HuiMenu menu) sync* {
  for (final HuiComponent component in menu.components) {
    switch (component.data) {
      case final HuiButtonData button:
        if (button.icon != null) yield button.icon!;
      case final HuiDecorationData decoration:
        if (decoration.icon != null) yield decoration.icon!;
      case final HuiToggleData toggle:
        if (toggle.trueIcon != null) yield toggle.trueIcon!;
        if (toggle.falseIcon != null) yield toggle.falseIcon!;
    }
  }
}

String _roundTrip(DocumentTypeAdapter type, String source) => switch (type) {
  MenuDocumentType() => encodeHuiMenu(decodeHuiMenu(source)),
  ContainerPreviewDocumentType() => encodeHuiPreviewDoc(
    decodeHuiPreviewDoc(source),
  ),
  GlossDocumentTypeAdapter() => type.encodeDoc(type.decodeDoc(source)),
  PanelDocumentType() => throw StateError('Panels have no runtime JSON.'),
  _ => throw StateError('Unsupported document type ${type.runtimeType}.'),
};

String _randomized(DocumentTypeAdapter type, int seed) {
  final EditorStore store = _store();
  type.createNew(store);
  final String documentId = store.workspace.activeId!;
  expect(
    randomizeShowcaseDocument(store, documentId, random: math.Random(seed)),
    isTrue,
    reason: '${type.noun} seed $seed',
  );
  return type.formattedJson(store);
}

void _expectMenuBudget(HuiMenu menu, String reason) {
  expect(menu.components.length, lessThanOrEqualTo(12), reason: reason);
  final List<HuiComponentData> clickable = menu.components
      .map((HuiComponent component) => component.data)
      .where(
        (HuiComponentData data) =>
            data is HuiButtonData || data is HuiToggleData,
      )
      .toList();
  expect(clickable.length, lessThanOrEqualTo(8), reason: reason);
  for (final HuiComponentData data in clickable) {
    final int actions = switch (data) {
      HuiButtonData() => data.actions.length,
      HuiToggleData() => data.trueActions.length + data.falseActions.length,
      HuiDecorationData() => 0,
    };
    expect(actions, lessThanOrEqualTo(6), reason: reason);
  }
}

void _expectPreviewBudget(HuiPreviewDoc doc, String reason) {
  final PreviewSim sim = PreviewSim(previewAutoSimCategory(doc));
  sim.vars = PreviewSim.parseVars(previewVarsForMaterial(doc, null));
  for (final HuiPreviewElement element in doc.elements) {
    final HuiPreviewRepeat? repeat = element.repeat;
    if (repeat == null) continue;
    final Object? raw = repeat.count;
    final double count = switch (raw) {
      num() => raw.toDouble(),
      String() => evalNumber(parsePreviewExpr(raw), sim),
      _ => 0,
    };
    expect(count.floor(), lessThanOrEqualTo(32), reason: reason);
  }

  final List<String> errors = <String>[];
  final PreviewCardScene scene = buildCardScene(doc, sim, onError: errors.add);
  expect(errors, isEmpty, reason: reason);
  expect(scene.items.length, lessThanOrEqualTo(64), reason: reason);
  final int weightedHandles = scene.items.fold<int>(
    0,
    (int total, CardItem item) => total + (item is CardSlot ? 3 : 1),
  );
  expect(weightedHandles, lessThanOrEqualTo(96), reason: reason);
}

void main() {
  test(
    'panel randomization stays disabled and leaves the active panel intact',
    () {
      final EditorStore store = _store();
      DocumentTypes.panel.createNew(store);
      final WorkspaceDoc before = store.workspace.active!;
      final String beforeJson = before.json;
      final String? beforeActiveId = store.workspace.activeId;
      final int beforeCount = store.workspace.docs.length;

      expect(canRandomizeShowcase(DocumentTypes.panel), isFalse);
      expect(
        randomizeShowcaseDocument(store, before.id, random: math.Random(19)),
        isFalse,
      );
      expect(store.workspace.activeId, beforeActiveId);
      expect(store.workspace.docs.length, beforeCount);
      expect(store.workspace.active!.json, beforeJson);
    },
  );

  test('seeded runtime documents round trip cleanly within safety budgets', () {
    for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
      if (type is PanelDocumentType) continue;
      for (int seed = 0; seed < 32; seed++) {
        final EditorStore store = _store();
        type.createNew(store);
        final String documentId = store.workspace.activeId!;
        expect(
          randomizeShowcaseDocument(
            store,
            documentId,
            random: math.Random(seed),
          ),
          isTrue,
          reason: '${type.noun} seed $seed',
        );
        final String reason = '${type.noun} seed $seed';
        final String encoded = type.formattedJson(store);
        expect(utf8.encode(encoded).length, lessThanOrEqualTo(64 * 1024));
        expect(jsonDecode(_roundTrip(type, encoded)), jsonDecode(encoded));

        final List<HuiIssue> blocking = type
            .validate(store)
            .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
            .toList();
        expect(blocking, isEmpty, reason: reason);

        if (type is MenuDocumentType) {
          _expectMenuBudget(store.menu, reason);
        } else if (type is ContainerPreviewDocumentType) {
          _expectPreviewBudget(store.previewDoc!, reason);
        } else if (type is HologramDocumentType) {
          expect(store.hologramDoc!.lines.length, lessThanOrEqualTo(12));
        } else if (type is MotdDocumentType) {
          expect(store.motdDoc!.entries.length, lessThanOrEqualTo(8));
        } else if (type is TablistDocumentType) {
          expect(store.tablistDoc!.nameFormats.length, lessThanOrEqualTo(8));
        }
      }
    }
  });

  test('same seeds produce byte-identical runtime documents', () {
    for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
      if (type is PanelDocumentType) continue;
      for (final int seed in <int>[0, 7, 31, 127]) {
        expect(
          _randomized(type, seed),
          _randomized(type, seed),
          reason: '${type.noun} seed $seed',
        );
      }
    }
  });

  test('menu generation reaches every icon, action and interaction enum', () {
    final EditorStore store = _resourceStore();
    store.newDocument();
    store.newDocument();
    final Set<String> iconTypes = <String>{};
    final Set<String> actionTypes = <String>{};
    final Set<String> triggers = <String>{};
    final Set<String> commandSources = <String>{};
    final Set<String> soundSources = <String>{};
    final Set<String> navigationModes = <String>{};
    final Set<HuiHoverEasing> easings = <HuiHoverEasing>{};
    final Set<HuiHitboxAnchor> anchors = <HuiHitboxAnchor>{};
    for (int seed = 0; seed < 256; seed++) {
      final HuiMenu menu = buildRandomMenuShowcase(store, math.Random(seed));
      iconTypes.addAll(_menuIcons(menu).map((HuiIcon icon) => icon.type));
      for (final HuiComponent component in menu.components) {
        final List<HuiAction> actions = switch (component.data) {
          final HuiButtonData button => button.actions,
          final HuiToggleData toggle => <HuiAction>[
            ...toggle.trueActions,
            ...toggle.falseActions,
          ],
          HuiDecorationData() => const <HuiAction>[],
        };
        for (final HuiAction action in actions) {
          actionTypes.add(action.type);
          triggers.add(action.trigger);
          if (action is HuiCommandAction) commandSources.add(action.source);
          if (action is HuiSoundAction) soundSources.add(action.source);
          if (action is HuiNavigateAction) navigationModes.add(action.mode);
        }
        switch (component.data) {
          case final HuiButtonData button:
            easings.add(button.hoverEasing);
            if (button.hitbox != null) anchors.add(button.hitbox!.anchor);
          case final HuiToggleData toggle:
            easings.add(toggle.hoverEasing);
            if (toggle.hitbox != null) anchors.add(toggle.hitbox!.anchor);
          case HuiDecorationData():
            break;
        }
      }
      _expectMenuBudget(menu, 'menu seed $seed');
    }
    expect(iconTypes, huiIconTypes.toSet());
    expect(actionTypes, huiActionTypes.toSet());
    expect(triggers, huiActionTriggers.toSet());
    expect(commandSources, huiCommandSources.toSet());
    expect(soundSources, huiSoundSources.toSet());
    expect(navigationModes, huiNavigationModes.toSet());
    expect(easings, HuiHoverEasing.values.toSet());
    expect(anchors, HuiHitboxAnchor.values.toSet());
  });

  test(
    'all 14 preview families exercise the complete bounded field surface',
    () {
      final Set<String> documents = <String>{};
      bool sawBareCard = false;
      bool sawFramedFalse = false;
      bool sawFramedExpression = false;
      bool sawZ = false;
      bool sawBackground = false;
      bool sawVisible = false;
      for (final PreviewShowcaseArchetype archetype
          in PreviewShowcaseArchetype.values) {
        for (int variant = 0; variant < 16; variant++) {
          final HuiPreviewDoc doc = buildRandomPreviewShowcase(
            math.Random(archetype.index * 100 + variant),
            archetype: archetype,
          );
          final String encoded = encodeHuiPreviewDoc(doc);
          documents.add('${archetype.name}:$encoded');
          sawBareCard |= doc.card == null;
          sawFramedFalse |= doc.card?.framed == false;
          sawFramedExpression |= doc.card?.framed is String;
          sawZ |= doc.elements.any(
            (HuiPreviewElement element) => element.z != null,
          );
          sawBackground |= doc.elements.any(
            (HuiPreviewElement element) => element.background != null,
          );
          sawVisible |= doc.elements.any(
            (HuiPreviewElement element) => element.visible != null,
          );
          _expectPreviewBudget(doc, '${archetype.name} variant $variant');
        }
      }
      final String combined = documents.join('\n');
      expect(PreviewShowcaseArchetype.values, hasLength(14));
      expect(sawBareCard, isTrue);
      expect(sawFramedFalse, isTrue);
      expect(sawFramedExpression, isTrue);
      expect(sawZ, isTrue);
      expect(sawBackground, isTrue);
      expect(sawVisible, isTrue);
      for (final String feature in <String>[
        'papi(',
        'papiNumber(',
        'metric(',
        'lerp(',
        'min(',
        'abs(',
        'cos(',
        'pow(',
        'smoothstep(',
        'rgb(',
        'argb(',
        'number(',
        'hex(',
        'time.ms',
        'time.seconds',
        'time.ticks',
        'player.health',
        'player.level',
      ]) {
        expect(combined, contains(feature), reason: feature);
      }
    },
  );

  test('gloss generators vary every presentation switch and enum', () {
    final Set<String> billboards = <String>{};
    final Set<bool> seeThrough = <bool>{};
    final Set<bool> hideNumbers = <bool>{};
    final Set<bool> emojiEnabled = <bool>{};
    final Set<bool> emojiTriggerPresent = <bool>{};
    final Set<bool> bubbleSelectPresent = <bool>{};
    final Set<String> shimmerPasses = <String>{};
    final Set<int> headerLineCounts = <int>{};
    final Set<int> footerLineCounts = <int>{};
    final Set<int> formatCounts = <int>{};
    final Set<String> tablists = <String>{};
    for (int seed = 0; seed < 256; seed++) {
      final GlossHologramDoc hologram = buildRandomHologramShowcase(
        GlossHologramDoc(),
        math.Random(seed),
      );
      billboards.add(hologram.billboard);
      seeThrough.add(hologram.seeThrough);
      expect(hologram.yaw, inInclusiveRange(-180, 180));
      expect(hologram.pitch, inInclusiveRange(-90, 90));
      hideNumbers.add(
        buildRandomScoreboardShowcase(
          GlossScoreboardDoc(),
          math.Random(seed),
        ).hideNumbers,
      );
      final GlossEmojiDoc emoji = buildRandomEmojiShowcase(
        GlossEmojiDoc(),
        math.Random(seed),
      );
      emojiEnabled.add(emoji.enabled);
      emojiTriggerPresent.add(emoji.trigger.isNotEmpty);
      expect(emoji.resolvedGlyph, isNotEmpty);
      final GlossBubbleStyleDoc bubble = buildRandomBubbleShowcase(
        GlossBubbleStyleDoc(),
        math.Random(seed),
      );
      bubbleSelectPresent.add(bubble.select != null);
      shimmerPasses.add('${bubble.shimmer.spawn}:${bubble.shimmer.flyAway}');
      expect(bubble.maxAliveMs, inInclusiveRange(4000, 12000));
      final GlossTablistDoc tablist = buildRandomTablistShowcase(
        GlossTablistDoc(),
        math.Random(seed),
      );
      expect(tablist.useHeaderFooter, isTrue);
      expect(tablist.groupListNames, isTrue);
      headerLineCounts.add(tablist.header.split('\n').length);
      footerLineCounts.add(tablist.footer.split('\n').length);
      formatCounts.add(tablist.nameFormats.length);
      tablists.add(encodeGlossTablistDoc(tablist));
    }
    expect(billboards, glossHologramBillboards.toSet());
    expect(seeThrough, <bool>{true, false});
    expect(hideNumbers, <bool>{true, false});
    expect(emojiEnabled, <bool>{true, false});
    expect(emojiTriggerPresent, <bool>{true, false});
    expect(bubbleSelectPresent, <bool>{true, false});
    expect(shimmerPasses, <String>{'true:true', 'false:true', 'true:false'});
    expect(headerLineCounts, <int>{1, 2, 3, 4, 5});
    expect(footerLineCounts, <int>{1, 2, 3, 4, 5});
    expect(formatCounts, <int>{1, 2, 3, 4, 5, 6, 7});
    expect(tablists.length, greaterThanOrEqualTo(248));
  });

  test('all menu component kinds randomize within their action budgets', () {
    final EditorStore store = _store()..newDocument();
    final List<HuiComponent> components = <HuiComponent>[
      HuiComponent(
        'button',
        Vec3(1, 2, 3),
        HuiButtonData(0.05, <HuiAction>[], HuiTextIcon('Button')),
      ),
      HuiComponent(
        'decoration',
        Vec3(4, 5, 6),
        HuiDecorationData(HuiTextIcon('Decoration')),
      ),
      HuiComponent(
        'toggle',
        Vec3(7, 8, 9),
        HuiToggleData(
          0.05,
          '%player_is_op%',
          'yes',
          <HuiAction>[],
          <HuiAction>[],
          HuiTextIcon('On'),
          HuiTextIcon('Off'),
        ),
      ),
    ];
    store.replaceMenu(
      'Install component contract fixtures',
      HuiMenu(components: components),
    );

    for (int index = 0; index < components.length; index++) {
      final HuiComponent before = store.menu.components[index].copy();
      expect(
        randomizeMenuComponent(
          store,
          before.id,
          random: math.Random(400 + index),
        ),
        isTrue,
      );
      final HuiComponent after = store.menu.componentById(before.id)!;
      expect(after.id, before.id);
      expect(after.offset, before.offset);
      expect(after.data.type, before.data.type);
      expect(after.data.toJson(), isNot(before.data.toJson()));
    }

    _expectMenuBudget(store.menu, 'component randomization');
  });

  test('all preview element kinds randomize in place and remain valid', () {
    final EditorStore store = _store();
    DocumentTypes.containerPreview.createNew(store);
    store.replacePreviewDoc(
      'Install element contract fixtures',
      HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          for (final String type in previewElementTypes)
            createDefaultPreviewElement(type),
        ],
      ),
    );

    for (int index = 0; index < previewElementTypes.length; index++) {
      final String before = store.previewDoc!.elements[index]
          .toJson()
          .toString();
      expect(
        randomizePreviewElement(store, index, random: math.Random(900 + index)),
        isTrue,
      );
      final HuiPreviewElement after = store.previewDoc!.elements[index];
      expect(after.type, previewElementTypes[index]);
      expect(after.toJson().toString(), isNot(before));
    }

    expect(
      DocumentTypes.containerPreview
          .validate(store)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    expect(store.canUndo, isTrue);
  });
}
