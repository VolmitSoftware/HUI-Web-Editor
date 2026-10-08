library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../../model/model.dart';
import '../../doctype/document_type_registry.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';
import '../../logic/gloss_text.dart';
import '../../logic/gloss_show.dart';
import '../../logic/player_identity_preview.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_scene.dart';
import '../../services/showcase_randomizer.dart';
import '../mc/mc_stage_controller.dart';
import '../mc/mc_dom_layer.dart';
import '../scoreboard/scoreboard_selection.dart';

class _LaneStage extends StatelessWidget {
  const _LaneStage({
    required this.gameContext,
    required this.anchor,
    required this.label,
    required this.stageClass,
    required this.child,
  });

  final bool gameContext;
  final GlossGameAnchor anchor;
  final String label;
  final String stageClass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (gameContext) {
      return GlossGameScreen(anchor: anchor, label: label, child: child);
    }
    return dom.div(classes: '$stageClass-stage', <Widget>[child]);
  }
}

class InventoryView extends StatefulWidget {
  const InventoryView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  EditorStore get store => component.store;
  bool get gameContext => component.gameContext;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GlossInventoryDoc? doc = store.inventoryDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-inventory-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.screen,
      label: huiText('Chest window'),
      stageClass: 'hui-inventory',
      child: dom.div(classes: 'hui-inventory-screen', <Widget>[
        dom.div(classes: 'hui-inventory-title', <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              doc.title,
              richText: true,
              animations: store.workspaceAnimations,
              emoji: store.workspaceEmoji,
            ),
          ),
        ]),
        dom.div(
          classes: 'hui-inventory-grid',
          styles: dom.Styles(
            raw: <String, String>{
              'grid-template-columns': 'repeat(${doc.width}, 1fr)',
            },
          ),
          <Widget>[
            for (int slot = 0; slot < doc.width * doc.rows; slot++)
              _slot(doc, slot),
          ],
        ),
      ]),
    );
  }

  Widget _slot(GlossInventoryDoc doc, int slot) {
    final int row = slot ~/ doc.width;
    final int column = slot % doc.width;
    final String cell = row < doc.mask.length && column < doc.mask[row].length
        ? doc.mask[row][column]
        : '';
    final Object? raw = doc.slots['$slot'] ?? doc.keys[cell];
    final Map<String, Object?> data = raw is Map
        ? Map<String, Object?>.from(raw)
        : const <String, Object?>{};
    final Object? rawIcon = data['icon'];
    final Map<String, Object?> icon =
        rawIcon is Map && glossShowMatches(data['show'])
        ? Map<String, Object?>.from(rawIcon)
        : const <String, Object?>{};
    final String item = icon['item'] is String ? icon['item'] as String : '';
    final String? texture = store.catalogs.textureFor(item);
    final String name = icon['name'] is String ? icon['name'] as String : item;
    final String label = renderGlossLine(name, richText: true).plainText;
    final int count = icon['count'] is num ? (icon['count'] as num).toInt() : 1;
    return dom.div(
      classes: 'hui-inventory-slot',
      attributes: <String, String>{'title': label, 'aria-label': label},
      <Widget>[
        if (texture != null) dom.img(src: texture, alt: label),
        if (texture == null && item.isNotEmpty)
          dom.span(classes: 'hui-inventory-missing', <Widget>[
            Text(item.split(':').last.replaceAll('_', ' ')),
          ]),
        if (item.isNotEmpty && count > 1)
          dom.span(classes: 'hui-inventory-count', <Widget>[Text('$count')]),
      ],
    );
  }
}

class PlayerIdentityView extends StatefulWidget {
  const PlayerIdentityView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  State<PlayerIdentityView> createState() => _PlayerIdentityViewState();
}

class _PlayerIdentityViewState extends State<PlayerIdentityView> {
  String _name = 'Builder';
  String _permissions = 'gloss.nametag.default';
  bool _sneaking = false;
  bool _invisible = false;
  bool _spectator = false;
  bool _npc = false;
  bool _self = false;
  bool _sameTeam = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    component.store.addListener(_refresh);
    _clock = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      final GlossDoc? doc = component.store.glossDoc;
      final Iterable<String> lines = switch (doc) {
        GlossNameplateDoc() => <String>[
          ...doc.presentation.lines.map((GlossNameplateLine line) => line.text),
          for (final GlossNameplateVariant variant in doc.variants)
            ...variant.presentation.lines.map(
              (GlossNameplateLine line) => line.text,
            ),
        ],
        GlossNametagDoc() => <String>[
          doc.presentation.prefix,
          doc.presentation.suffix,
          for (final GlossNametagVariant variant in doc.variants) ...<String>[
            variant.presentation.prefix,
            variant.presentation.suffix,
          ],
        ],
        _ => const <String>[],
      };
      if (lines.any(glossTextRequiresFastRefresh)) _refresh();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    component.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final EditorStore store = component.store;
    final Set<String> permissions = _permissions
        .split(RegExp(r'[\s,]+'))
        .where((String value) => value.isNotEmpty)
        .toSet();
    final GlossConditionContext scope = identityPreviewContext(
      _name,
      permissions,
      sneaking: _sneaking,
      invisible: _invisible,
      spectator: _spectator,
      npc: _npc,
      self: _self,
    );
    final List<String> lines = <String>[];
    double offset = 0.3;
    final GlossNametagDoc? nametag = store.nametagDoc;
    final GlossNameplateDoc? nameplate = store.nameplateDoc;
    if (nametag != null) {
      final GlossNametagPresentation? presentation = resolveNametagPreview(
        nametag,
        scope,
      );
      if (presentation != null &&
          switch (presentation.nameTagVisibility) {
            'never' => false,
            'hide_for_other_teams' => _sameTeam,
            'hide_for_own_team' => !_sameTeam,
            _ => true,
          }) {
        lines.add(nametagPreviewText(presentation));
      }
    } else if (nameplate != null) {
      final GlossNameplatePresentation? presentation = resolveNameplatePreview(
        nameplate,
        scope,
      );
      if (presentation != null) {
        offset = presentation.offset;
        String relationColor = '';
        for (final GlossNameplateRelation relation in presentation.relations) {
          if (glossShowMatches(relation.when, scope: scope)) {
            relationColor = relation.color;
            break;
          }
        }
        for (final GlossNameplateLine line in presentation.lines) {
          if (glossShowMatches(line.show, scope: scope)) {
            final double health = (scope.variable('subject.health') as num?)?.toDouble() ?? 18;
            final double maximum = (scope.variable('subject.maxHealth') as num?)?.toDouble() ?? 20;
            final String text = line.text.replaceAll('{bar}', presentation.healthBar.render(presentation.healthSegments.clamp(1, 40), health, maximum, health))
                .replaceAll('{health}', presentation.healthBar.number(health))
                .replaceAll('{max_health}', presentation.healthBar.number(maximum));
            lines.add('$relationColor$text');
          }
        }
      }
    }
    final Map<String, Object> sampleValues = <String, Object>{
      for (final MapEntry<String, Object?> entry in scope.variables.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    if (nameplate != null) {
      final List<({String id, GlossNametagDoc doc})> tags = <({String id, GlossNametagDoc doc})>[];
      for (final WorkspaceDoc document in store.workspace.docs) {
        if (document.kind != DocumentTypes.nametag.kind) continue;
        try {
          tags.add((id: document.runtimeId ?? document.id,
            doc: decodeGlossNametagDoc(document.json)));
        } on HuiFormatException {
          continue;
        }
      }
      final String identity = resolveIdentityPreviewName(tags, scope,
        animations: store.workspaceAnimations, emoji: store.workspaceEmoji,
        nowMs: DateTime.now().millisecondsSinceEpoch);
      sampleValues['subject.name'] = identity;
      sampleValues['subject.displayName'] = identity;
    }
    final McStageController world = glossGameWorldController(
      GlossGameAnchor.overPlayer,
    );
    return GlossGameScreen(
      anchor: GlossGameAnchor.overPlayer,
      label: huiText(nametag == null ? 'Nameplate in game' : 'Nametag in game'),
      world: world,
      worldOverlay: <Widget>[
        if (lines.isNotEmpty)
          dom.div(
            classes: 'hui-mc-anchor',
            styles: dom.Styles(
              raw: <String, String>{
                'transform': mcDomAnchorTransform(
                  camera: world.camera,
                  position: McVec3(0.5, 1.8 + offset, 0.5),
                  billboard: McBillboardMode.center,
                ),
              },
            ),
            <Widget>[
              dom.div(classes: 'hui-identity-billboard', <Widget>[
                for (final String line in lines)
                  dom.div(<Widget>[
                    GlossTextLine(
                      render: renderGlossLine(
                        line,
                        richText: true,
                        nowMs: DateTime.now().millisecondsSinceEpoch,
                        animations: store.workspaceAnimations,
                        emoji: store.workspaceEmoji,
                        expressionSamples: GlossTextExpressionSamples(
                          values: sampleValues,
                        ),
                      ),
                    ),
                  ]),
              ]),
            ],
          ),
      ],
      controls: <Widget>[
        TextInput(
          value: _name,
          placeholder: 'Preview player',
          size: ComponentSize.sm,
          attributes: const <String, String>{'aria-label': 'Preview player'},
          onChanged: (String value) => setState(() => _name = value),
        ),
        TextInput(
          value: _permissions,
          placeholder: 'Preview permissions',
          size: ComponentSize.sm,
          attributes: const <String, String>{
            'aria-label': 'Preview permissions',
          },
          onChanged: (String value) => setState(() => _permissions = value),
        ),
        Button(
          label: _sneaking ? 'Sneaking' : 'Standing',
          variant: ButtonVariant.outline,
          onPressed: () => setState(() => _sneaking = !_sneaking),
        ),
        if (nameplate != null)
          Button(
            label: _invisible ? 'Invisible player' : 'Visible player',
            variant: ButtonVariant.outline,
            onPressed: () => setState(() => _invisible = !_invisible),
          ),
        if (nameplate != null)
          Button(
            label: _spectator ? 'Spectator player' : 'Survival player',
            variant: ButtonVariant.outline,
            onPressed: () => setState(() => _spectator = !_spectator),
          ),
        if (nameplate != null)
          Button(
            label: _npc ? 'NPC subject' : 'Player subject',
            variant: ButtonVariant.outline,
            onPressed: () => setState(() => _npc = !_npc),
          ),
        if (nameplate != null)
          Button(
            label: _self ? 'Own viewer' : 'Other viewer',
            variant: ButtonVariant.outline,
            onPressed: () => setState(() => _self = !_self),
          ),
        if (nametag != null)
          Button(
            label: _sameTeam ? 'Same team' : 'Other team',
            variant: ButtonVariant.outline,
            onPressed: () => setState(() => _sameTeam = !_sameTeam),
          ),
        Button(
          label: 'Randomize',
          variant: ButtonVariant.outline,
          onPressed: () {
            final String? id = store.workspace.activeId;
            if (id != null) randomizeShowcaseDocument(store, id);
          },
        ),
        if (lines.isEmpty) const Text('Hidden for this preview player'),
      ],
      child: const dom.div(<Widget>[]),
    );
  }
}

class MarkerView extends StatefulWidget {
  const MarkerView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  State<MarkerView> createState() => _MarkerViewState();
}

class _MarkerViewState extends State<MarkerView> {
  final McStageController _world = McStageController(
    kind: McStageKind.frame,
    homePivot: const McVec3(0.5, 0, 0.5),
    freeCamera: false,
  );

  EditorStore get store => component.store;
  bool get gameContext => component.gameContext;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    _world.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GlossMarkerDoc? doc = store.markerDoc;
    if (doc == null) {
      return glossGameEmpty(
        anchor: GlossGameAnchor.world,
        label: huiText('Marker'),
      );
    }
    _world.spriteFor = (McSceneNode node) =>
        mcCatalogSpriteFor(store.catalogs, node);
    _world.scene = McScene(<McSceneNode>[
      if (doc.beam.enabled)
        McBlockModelNode(
          key: 'marker-beam',
          blockId: doc.beam.material,
          transform:
              McMat4.translation(
                0.5 - doc.beam.width / 2,
                0,
                0.5 - doc.beam.width / 2,
              ).multiply(
                McMat4.scale(doc.beam.width, doc.beam.height, doc.beam.width),
              ),
        ),
    ]);
    return GlossGameScreen(
      anchor: GlossGameAnchor.world,
      label: huiText('Marker'),
      world: _world,
      worldOverlay: <Widget>[
        dom.div(
          classes: 'hui-mc-anchor',
          styles: dom.Styles(
            raw: <String, String>{
              'transform': mcDomAnchorTransform(
                camera: _world.camera,
                position: const McVec3(0.5, 1.4, 0.5),
                billboard: McBillboardMode.center,
              ),
            },
          ),
          <Widget>[
            dom.div(classes: 'hui-identity-billboard', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  '<${doc.color}>${doc.label}',
                  richText: true,
                  animations: store.workspaceAnimations,
                  emoji: store.workspaceEmoji,
                ),
              ),
            ]),
          ],
        ),
      ],
      child: const dom.div(<Widget>[]),
    );
  }
}
