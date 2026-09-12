import 'dart:convert';
import 'dart:math' as math;

import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/entity_overlay_preview.dart';
import 'package:gloss_editor/logic/entity_overlay_validation.dart';
import 'package:gloss_editor/logic/particle_layer_validation.dart';
import 'package:gloss_editor/logic/preview_doc_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/real_drop_validation.dart';
import 'package:gloss_editor/logic/damage_indicator_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/model/runtime_panel_definition.dart';
import 'package:gloss_editor/services/catalogs.dart';
import 'package:gloss_editor/services/editor_sync.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/services/showcase_features.dart';
import 'package:gloss_editor/services/showcase_effects.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_panel.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

EditorStore _store() {
  final Map<String, String> storage = <String, String>{};
  final ImageLibrary images = ImageLibrary();
  final String png =
      'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 1, height: 1)))}';
  images.upsertAll(<StoredImage>[
    for (int index = 0; index < 2; index++)
      StoredImage(
        path: 'sample/frame-$index.png',
        dataUri: png,
        width: 1,
        height: 1,
      ),
  ]);
  final HuiCustomItemCatalog customItems = HuiCustomItemCatalog.parse(
    jsonEncode(<String, Object?>{
      'items': <Object?>[
        for (final String provider in huiCustomItemProviders)
          <String, Object?>{
            'provider': provider,
            'id': 'sample_wand',
            'material': 'stick',
          },
      ],
    }),
  )!;
  final EditorStore store = EditorStore(
    workspace: Workspace(
      read: (String key) => storage[key],
      write: (String key, String value) {
        storage[key] = value;
        return true;
      },
    ),
    images: images,
    catalogs: HuiCatalogs.empty().withCustomItems(customItems),
    autosaveDelay: Duration.zero,
  )..newDocument();
  store.newDocument();
  return store;
}

Iterable<HuiIcon> _icons(HuiComponentData data) => switch (data) {
  HuiButtonData() => <HuiIcon>[?data.icon],
  HuiDecorationData() => <HuiIcon>[?data.icon],
  HuiToggleData() => <HuiIcon>[?data.trueIcon, ?data.falseIcon],
};

Iterable<HuiAction> _actions(HuiComponentData data) => switch (data) {
  HuiButtonData() => data.actions,
  HuiDecorationData() => const <HuiAction>[],
  HuiToggleData() => <HuiAction>[...data.trueActions, ...data.falseActions],
};

void main() {
  test(
    'typewriter uses the bounded native function for long and quoted text',
    () {
      for (final String text in <String>[
        ...showcaseHeadlines,
        "It's a long message with a \\ path and 'quotes' that still reveals correctly",
      ]) {
        final ShowcaseEffect effect = showcaseTypewriter(
          math.Random(1729),
          text,
        );
        expect(effect.text, contains('typewriter('));
        expect(effect.text.length, lessThan(1024));
        for (final int nowMs in <int>[0, 500, 1000, 5000, 10000]) {
          final GlossLineRender rendered = renderGlossLine(
            effect.text,
            nowMs: nowMs,
          );
          expect(rendered.expressionErrors, isEmpty, reason: text);
          expect(rendered.renderedText, isNot(contains('{{')), reason: text);
        }
      }
    },
  );

  test(
    'composed menus cover every icon, component, interaction and style mode',
    () {
      final EditorStore store = _store();
      final Set<String> components = <String>{};
      final Set<String> icons = <String>{};
      final Set<String> actions = <String>{};
      final Set<String> triggers = <String>{};
      final Set<String> sources = <String>{};
      final Set<String> navigation = <String>{};
      final Set<String> billboards = <String>{};
      final Set<String> alignment = <String>{};
      final Set<HuiHoverEasing> easing = <HuiHoverEasing>{};
      final Set<int> sizes = <int>{};
      final Set<String> placements = <String>{};
      final Set<String> behaviors = <String>{};
      final Set<bool> textBoxes = <bool>{};
      for (int seed = 0; seed < 256; seed++) {
        final HuiMenu menu = buildRandomMenuShowcase(store, math.Random(seed));
        store.replaceMenu('randomize', menu);
        expect(
          store.issues.where(
            (HuiIssue issue) => issue.severity == HuiSeverity.error,
          ),
          isEmpty,
          reason: 'seed $seed',
        );
        sizes.add(menu.components.length);
        behaviors.add(
          '${menu.lockPosition}:${menu.followPlayer}:${menu.closeOnDeath}:${menu.closeOnTeleport}',
        );
        placements.add(
          menu.components
              .map((HuiComponent item) => item.offset.toJson().join(','))
              .join(';'),
        );
        expect(menu.particleLayers, isNotEmpty);
        for (final HuiComponent component in menu.components) {
          components.add(component.data.type);
          for (final HuiIcon icon in _icons(component.data)) {
            icons.add(icon.type);
            if (icon is HuiTextIcon) {
              expect(icon.box, isNotNull);
              textBoxes.add(icon.box!.enabled);
            }
            final HuiIconStyle? style = icon.style;
            if (style != null) {
              billboards.add(style.billboard);
              alignment.add(style.textAlignment);
            }
          }
          for (final HuiAction action in _actions(component.data)) {
            actions.add(action.type);
            triggers.add(action.trigger);
            if (action is HuiSoundAction) sources.add(action.source);
            if (action is HuiNavigateAction) navigation.add(action.mode);
          }
          switch (component.data) {
            case final HuiButtonData button:
              easing.add(button.hoverEasing);
            case final HuiToggleData toggle:
              easing.add(toggle.hoverEasing);
            case HuiDecorationData():
              break;
          }
        }
      }
      expect(components, huiEditorComponentTypes.toSet());
      expect(icons, huiIconTypes.toSet());
      expect(actions, huiEditorActionTypes.toSet());
      expect(triggers, huiActionTriggers.toSet());
      expect(sources, huiSoundSources.toSet());
      expect(navigation, huiNavigationModes.toSet());
      expect(billboards, huiIconBillboards.toSet());
      expect(alignment, huiIconTextAlignments.toSet());
      expect(easing, HuiHoverEasing.values.toSet());
      expect(sizes.length, greaterThanOrEqualTo(6));
      expect(behaviors, hasLength(16));
      expect(textBoxes, <bool>{true, false});
      expect(placements.length, greaterThanOrEqualTo(250));
    },
  );

  test(
    'particles cover all targets, geometry, patterns and placement with valid data',
    () {
      final Set<String> scopes = <String>{};
      final Set<String> geometry = <String>{};
      final Set<String> patterns = <String>{};
      final Set<String> placements = <String>{};
      final Set<String> keys = <String>{};
      for (int seed = 0; seed < 256; seed++) {
        final List<GlossParticleLayer> layers = showcaseParticleLayers(
          math.Random(seed),
          showcaseMoods[seed % showcaseMoods.length],
          scopes: glossParticleTargetScopes,
          componentId: 'title',
          lineCount: 4,
        );
        expect(validateParticleLayers(layers), isEmpty, reason: 'seed $seed');
        for (final GlossParticleLayer layer in layers) {
          scopes.add(layer.target.scope);
          geometry.add(layer.geometry.type);
          patterns.add(layer.emission.pattern);
          placements.add(layer.placement.layer);
          keys.add(layer.particle.key);
          if (layer.target.scope == 'component') {
            expect(layer.target.component, 'title');
          }
          if (layer.target.scope == 'span') {
            expect(layer.target.name, 'highlight');
          }
          if (layer.target.scope == 'line') {
            expect(layer.target.line, inInclusiveRange(1, 4));
          }
        }
      }
      expect(scopes, glossParticleTargetScopes.toSet());
      expect(geometry, glossParticleGeometryTypes.toSet());
      expect(patterns, glossParticleEmissionPatterns.toSet());
      expect(placements, glossParticlePlacementLayers.toSet());
      expect(keys.length, greaterThanOrEqualTo(4));
    },
  );

  test(
    'entity compositions vary complete layouts and render every generated expression',
    () {
      final Set<String> orders = <String>{};
      final Set<String> rowTypes = <String>{};
      final Set<String> conditions = <String>{};
      final Set<String> boxes = <String>{};
      final Set<String> billboards = <String>{};
      for (int seed = 0; seed < 256; seed++) {
        final GlossEntityOverlaysDoc doc = buildRandomEntityOverlayShowcase(
          GlossEntityOverlaysDoc(revision: 7),
          math.Random(seed),
        );
        expect(doc.revision, 7);
        expect(validateEntityOverlaysDoc(doc), isEmpty, reason: 'seed $seed');
        expect(
          encodeGlossEntityOverlaysDoc(
            buildRandomEntityOverlayShowcase(doc, math.Random(seed)),
          ),
          encodeGlossEntityOverlaysDoc(doc),
        );
        orders.add(
          doc.lines.map((GlossEntityOverlayLine line) => line.id).join(','),
        );
        rowTypes.addAll(
          doc.lines.map((GlossEntityOverlayLine line) => line.type),
        );
        conditions.addAll(
          doc.lines.map((GlossEntityOverlayLine line) => line.show.toString()),
        );
        boxes.add(jsonEncode(doc.box.toJson()));
        billboards.add(doc.style.billboard);
        for (final int time in <int>[0, 500, 1250]) {
          final EntityOverlayPreview preview = resolveEntityOverlayPreview(
            doc,
            const EntityOverlaySample(
              name: 'Sample target',
              health: 14,
              maxHealth: 20,
              attack: 3,
              armor: 2,
              distance: 6,
              react: true,
              stackCount: 8,
              adapt: true,
              insight: true,
            ),
            nowMs: time,
          );
          expect(preview.errors, isEmpty, reason: 'seed $seed at $time');
          expect(preview.visible, isTrue, reason: 'seed $seed');
          expect(preview.lines.join('\n'), contains('14'));
        }
      }
      expect(orders, hasLength(256));
      expect(boxes.length, greaterThan(200));
      expect(rowTypes, glossEntityOverlayLineTypes.toSet());
      expect(conditions.length, greaterThanOrEqualTo(6));
      expect(billboards, huiIconBillboards.toSet());
    },
  );

  test('container cards compose all shared style and frame fields', () {
    final Set<String> textModes = <String>{};
    final Set<String> itemModes = <String>{};
    final Set<bool> inherited = <bool>{};
    final Set<bool> boxes = <bool>{};
    final Map<String, Set<Object?>> fields = <String, Set<Object?>>{
      for (final String field in <String>[
        'padding',
        'borderWidth',
        'trayPadding',
        'titleHeight',
        'titleGap',
        'backgroundArgb',
        'trayArgb',
        'borderArgb',
        'titleArgb',
      ])
        field: <Object?>{},
    };
    for (int seed = 0; seed < 128; seed++) {
      final HuiPreviewDoc preview = buildRandomPreviewShowcase(
        math.Random(seed),
      );
      expect(
        validatePreviewDoc(
          preview,
        ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
        isEmpty,
      );
      textModes.add(preview.textStyle!.billboard);
      itemModes.add(preview.itemStyle!.billboard);
      for (final HuiPreviewElement element in preview.elements) {
        inherited.add(element.style == null);
        if (element.type == 'label') {
          expect(element.box, isNotNull);
          boxes.add(element.box!.enabled);
        }
      }
      final Map<String, dynamic>? card = preview.card?.toJson();
      if (card != null) {
        for (final String field in fields.keys) {
          fields[field]!.add(card[field]);
        }
      }
    }
    expect(textModes, huiIconBillboards.toSet());
    expect(itemModes, huiIconBillboards.toSet());
    expect(inherited, <bool>{true, false});
    expect(boxes, <bool>{true, false});
    for (final MapEntry<String, Set<Object?>> field in fields.entries) {
      expect(field.value, isNot(contains(null)), reason: field.key);
      expect(field.value.length, greaterThan(2), reason: field.key);
    }
  });

  test(
    'nested variants cover complete display and drop animation contracts',
    () {
      final Set<GlossRealDropAnimationTrigger> triggers =
          <GlossRealDropAnimationTrigger>{};
      final Set<GlossRealDropAnimationTarget> targets =
          <GlossRealDropAnimationTarget>{};
      final Set<GlossRealDropAnimationBlend> blends =
          <GlossRealDropAnimationBlend>{};
      final Set<GlossRealDropAnimationEasing> easings =
          <GlossRealDropAnimationEasing>{};
      final Set<String> displayModes = <String>{};
      final Set<int> variantCounts = <int>{};
      final Set<String> conditions = <String>{};
      final Set<bool> amountToken = <bool>{};
      final Set<bool> loops = <bool>{};
      for (int seed = 0; seed < 128; seed++) {
        final GlossRealDropSettingsDoc drops = buildRandomRealDropShowcase(
          GlossRealDropSettingsDoc(),
          math.Random(seed),
        );
        expect(
          validateRealDropSettingsDoc(drops),
          isEmpty,
          reason: 'drop seed $seed',
        );
        variantCounts.add(drops.variants.length);
        for (final GlossRealDropVariant variant in drops.variants) {
          conditions.add(variant.when);
        }
        for (final GlossRealDropPresentation presentation
            in <GlossRealDropPresentation>[
              drops.presentation,
              ...drops.variants.map(
                (GlossRealDropVariant variant) => variant.presentation,
              ),
            ]) {
          displayModes.add(presentation.labels.style.billboard);
          expect(presentation.particleLayers, isNotEmpty);
          for (final GlossRealDropAnimationProfile profile
              in presentation.animation?.profiles ??
                  const <GlossRealDropAnimationProfile>[]) {
            for (final GlossRealDropAnimationClip clip in profile.clips) {
              triggers.add(clip.trigger);
              loops.add(clip.loop);
              for (final GlossRealDropAnimationTrack track in clip.tracks) {
                targets.add(track.target);
                blends.add(track.blend);
                easings.addAll(
                  track.keyframes.map(
                    (GlossRealDropAnimationKeyframe frame) => frame.easing,
                  ),
                );
              }
            }
          }
        }
        final GlossDamageIndicatorsDoc indicators =
            buildRandomDamageIndicatorsShowcase(
              GlossDamageIndicatorsDoc(),
              math.Random(seed),
            );
        expect(
          validateDamageIndicatorsDoc(indicators),
          isEmpty,
          reason: 'indicator seed $seed',
        );
        for (final GlossDamageIndicatorStyle style
            in <GlossDamageIndicatorStyle>[
              indicators.damage,
              indicators.healing,
            ]) {
          expect(style.variants.length, greaterThan(1));
          for (final GlossDamageIndicatorPresentation presentation
              in <GlossDamageIndicatorPresentation>[
                style.presentation,
                ...style.variants.map(
                  (GlossDamageIndicatorVariant variant) => variant.presentation,
                ),
              ]) {
            amountToken.add(presentation.format.contains('{amount}'));
            displayModes.add(presentation.style.billboard);
            expect(presentation.particleLayers, isNotEmpty);
          }
        }
      }
      expect(triggers, GlossRealDropAnimationTrigger.values.toSet());
      expect(targets, GlossRealDropAnimationTarget.values.toSet());
      expect(blends, GlossRealDropAnimationBlend.values.toSet());
      expect(easings, GlossRealDropAnimationEasing.values.toSet());
      expect(displayModes, huiIconBillboards.toSet());
      expect(variantCounts, <int>{1, 2, 3, 4});
      expect(conditions.length, greaterThanOrEqualTo(4));
      expect(amountToken, <bool>{true, false});
      expect(loops, <bool>{true, false});
    },
  );

  test('linked world panels replay their seed and keep identity with undo', () {
    final Set<RuntimePanelFollowMode> followModes = <RuntimePanelFollowMode>{};
    final Set<RuntimePanelFollowRotation> rotations =
        <RuntimePanelFollowRotation>{};
    final Set<RuntimePanelVisibilityMode> audiences =
        <RuntimePanelVisibilityMode>{};
    final Set<String> conditions = <String>{};
    final RuntimePanelDefinition original = _panel();
    for (int seed = 0; seed < 128; seed++) {
      final RuntimePanelDefinition panel = buildRandomRuntimePanelShowcase(
        original,
        math.Random(seed),
      );
      expect(
        RuntimePanelDefinition.fromJson(panel.toJson()).toJson(),
        panel.toJson(),
      );
      expect(
        editorSyncPanelDefinitionProblem(panel.toJson(), <String>[
          original.rootMenuId,
        ]),
        isNull,
        reason: 'following panel seed $seed',
      );
      final RuntimePanelDefinition fixed = buildRandomRuntimePanelShowcase(
        original.copyWith(
          follow: const RuntimePanelFollow(
            mode: RuntimePanelFollowMode.none,
            targetPlayerUuid: null,
            rotation: RuntimePanelFollowRotation.fixed,
          ),
        ),
        math.Random(seed),
      );
      expect(
        editorSyncPanelDefinitionProblem(fixed.toJson(), <String>[
          original.rootMenuId,
        ]),
        isNull,
        reason: 'fixed panel seed $seed',
      );
      expect(fixed.follow.rotation, RuntimePanelFollowRotation.fixed);
      followModes.add(fixed.follow.mode);
      expect(
        buildRandomRuntimePanelShowcase(panel, math.Random(seed)).toJson(),
        panel.toJson(),
      );
      expect(panel.schemaVersion, original.schemaVersion);
      expect(panel.id, original.id);
      expect(panel.uuid, original.uuid);
      expect(panel.revision, original.revision);
      expect(panel.rootMenuId, original.rootMenuId);
      expect(panel.transform.worldKey, original.transform.worldKey);
      expect(panel.transform.worldUuid, original.transform.worldUuid);
      expect(panel.follow.targetPlayerUuid, original.follow.targetPlayerUuid);
      expect((panel.transform.x - original.transform.x).abs(), lessThan(1));
      expect((panel.transform.y - original.transform.y).abs(), lessThan(1));
      expect((panel.transform.z - original.transform.z).abs(), lessThan(1));
      expect(
        panel.visibility.interactionRange,
        lessThan(panel.visibility.viewRange),
      );
      followModes.add(panel.follow.mode);
      rotations.add(panel.follow.rotation);
      audiences.add(panel.visibility.mode);
      conditions.add(panel.show.toString());
    }
    expect(followModes, RuntimePanelFollowMode.values.toSet());
    expect(rotations, RuntimePanelFollowRotation.values.toSet());
    expect(audiences, <RuntimePanelVisibilityMode>{
      RuntimePanelVisibilityMode.public,
      RuntimePanelVisibilityMode.permission,
    });
    expect(conditions.length, greaterThanOrEqualTo(5));
    final EditorStore store = _store()..newPanelDocument();
    final WorkspaceDoc document = store.workspace.active!;
    expect(
      randomizeShowcaseDocument(store, document.id, random: math.Random(9)),
      isFalse,
    );
    final WorkspacePanelData source = WorkspacePanelData(
      runtimeBoardId: original.id,
      runtimeBoard: original.toJson(),
      positions: <String, WorkspacePanelPoint>{
        document.id: const WorkspacePanelPoint(12, 18),
      },
    );
    expect(store.updatePanel(source), isTrue);
    expect(
      canRandomizeShowcase(DocumentTypes.panel, linkedPanel: true),
      isTrue,
    );
    expect(
      randomizeShowcaseDocument(store, document.id, random: math.Random(9)),
      isTrue,
    );
    final String generated = encodeWorkspacePanel(store.activePanel!.data);
    expect(store.activePanel!.data.positions[document.id]!.x, 12);
    expect(store.performUndo(), isTrue);
    expect(store.activePanel!.data.toJson(), source.toJson());
    expect(store.performRedo(), isTrue);
    expect(encodeWorkspacePanel(store.activePanel!.data), generated);
  });

  test(
    'every runtime randomizer replays the same seed and keeps canonical identity',
    () {
      for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
        if (!canRandomizeShowcase(type)) continue;
        final EditorStore store = _store();
        type.createNew(store);
        final WorkspaceDoc before = store.workspace.active!;
        expect(
          randomizeShowcaseDocument(
            store,
            before.id,
            random: math.Random(1729),
          ),
          isTrue,
        );
        final String first = store.exportJson();
        expect(
          randomizeShowcaseDocument(
            store,
            before.id,
            random: math.Random(1729),
          ),
          isTrue,
        );
        expect(store.exportJson(), first, reason: type.noun);
        expect(store.workspace.active!.id, before.id);
        expect(store.workspace.active!.runtimeId, before.runtimeId);
        expect(
          store.issues.where(
            (HuiIssue issue) => issue.severity == HuiSeverity.error,
          ),
          isEmpty,
          reason: type.noun,
        );
      }
    },
  );
}

RuntimePanelDefinition _panel() => const RuntimePanelDefinition(
  schemaVersion: 1,
  id: 'welcome',
  uuid: '00000000-0000-4000-8000-000000000042',
  revision: 7,
  rootMenuId: 'welcome/root',
  transform: RuntimePanelTransform(
    worldKey: 'minecraft:overworld',
    worldUuid: '00000000-0000-4000-8000-000000000043',
    x: -12.3,
    y: 64,
    z: 16.4,
    yaw: 0,
    pitch: 0,
    roll: 0,
    scale: 1,
  ),
  follow: RuntimePanelFollow(
    mode: RuntimePanelFollowMode.player,
    targetPlayerUuid: '00000000-0000-4000-8000-000000000044',
    rotation: RuntimePanelFollowRotation.fixed,
  ),
  visibility: RuntimePanelVisibility(
    mode: RuntimePanelVisibilityMode.public,
    viewPermission: null,
    interactPermission: null,
    viewRange: 32,
    interactionRange: 4,
  ),
);
