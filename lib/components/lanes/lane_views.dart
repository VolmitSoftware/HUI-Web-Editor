library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';
import '../../logic/gloss_text.dart';

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

class DialogView extends StatelessWidget {
  const DialogView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossDialogDoc? doc = store.dialogDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-dialog-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.screen,
      label: huiText('Dialog screen'),
      stageClass: 'hui-dialog',
      child: dom.div(classes: 'hui-dialog-screen', <Widget>[
        dom.div(classes: 'hui-dialog-title', <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              doc.title,
              richText: true,
              animations: store.workspaceAnimations,
              emoji: store.workspaceEmoji,
            ),
          ),
        ]),
        for (final GlossDialogBody block in doc.body)
          if (block.text.trim().isNotEmpty)
            dom.div(classes: 'hui-dialog-body', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  block.text,
                  richText: true,
                  animations: store.workspaceAnimations,
                  emoji: store.workspaceEmoji,
                ),
              ),
            ]),
        dom.div(classes: 'hui-dialog-buttons', <Widget>[
          for (final GlossDialogButton button in doc.buttons)
            dom.span(classes: 'hui-dialog-button', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  button.label,
                  richText: true,
                  animations: store.workspaceAnimations,
                  emoji: store.workspaceEmoji,
                ),
              ),
            ]),
        ]),
      ]),
    );
  }
}

class InventoryView extends StatelessWidget {
  const InventoryView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

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
            for (final String row in doc.mask)
              for (final String cell in row.split(''))
                dom.div(classes: 'hui-inventory-slot', <Widget>[Text(cell)]),
          ],
        ),
      ]),
    );
  }
}

class NameplateView extends StatelessWidget {
  const NameplateView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossNameplateDoc? doc = store.nameplateDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-nameplate-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.overPlayer,
      label: huiText('Nameplate'),
      stageClass: 'hui-nameplate',
      child: dom.div(classes: 'hui-nameplate-stack', <Widget>[
        for (final GlossNameplateLine line in doc.presentation.lines)
          GlossTextLine(
            render: renderGlossLine(
              line.text,
              richText: true,
              animations: store.workspaceAnimations,
              emoji: store.workspaceEmoji,
            ),
          ),
      ]),
    );
  }
}

class NametagView extends StatelessWidget {
  const NametagView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossNametagDoc? doc = store.nametagDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-nametag-stage is-empty', <Widget>[]);
    }
    final String composed =
        '${doc.presentation.prefix}{{ subject.name }}${doc.presentation.suffix}';
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.overPlayer,
      label: huiText('Nametag'),
      stageClass: 'hui-nametag',
      child: dom.div(classes: 'hui-nametag-line', <Widget>[
        GlossTextLine(
          render: renderGlossLine(
            composed,
            richText: true,
            animations: store.workspaceAnimations,
            emoji: store.workspaceEmoji,
          ),
        ),
      ]),
    );
  }
}

class MotionView extends StatelessWidget {
  const MotionView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossMotionDoc? doc = store.motionDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-motion-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.world,
      label: huiText('Motion clip'),
      stageClass: 'hui-motion',
      child: dom.div(classes: 'hui-motion-readout', <Widget>[
        dom.p(<Widget>[
          Text(
            huiText(
              '{count} tracks, {loop}, {fps} fps',
              <String, Object?>{
                'count': doc.tracks.length,
                'loop': doc.loop,
                'fps': doc.fps,
              },
            ),
          ),
        ]),
        for (final GlossMotionTrack track in doc.tracks)
          dom.div(classes: 'hui-motion-track', <Widget>[
            Text('${track.bone} / ${track.channel} (${track.keyframes.length})'),
          ]),
      ]),
    );
  }
}

class RigView extends StatelessWidget {
  const RigView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossRigDoc? doc = store.rigDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-rig-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.world,
      label: huiText('Rig'),
      stageClass: 'hui-rig',
      child: dom.div(classes: 'hui-rig-readout', <Widget>[
        for (final GlossRigPart part in doc.parts)
          dom.div(classes: 'hui-rig-part', <Widget>[
            Text('${part.id} · ${part.type} · ${part.bone}'),
          ]),
      ]),
    );
  }
}

class MarkerView extends StatelessWidget {
  const MarkerView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossMarkerDoc? doc = store.markerDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-marker-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.world,
      label: huiText('Marker'),
      stageClass: 'hui-marker',
      child: dom.div(classes: 'hui-marker-pin', <Widget>[
        GlossTextLine(
          render: renderGlossLine(
            doc.label,
            richText: true,
            animations: store.workspaceAnimations,
            emoji: store.workspaceEmoji,
          ),
        ),
        Text(
          '${doc.anchor.world ?? ''} ${doc.anchor.x ?? 0}, ${doc.anchor.y ?? 0}, ${doc.anchor.z ?? 0}',
        ),
      ]),
    );
  }
}

class ZoneView extends StatelessWidget {
  const ZoneView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;
  final bool gameContext;

  @override
  Widget build(BuildContext context) {
    final GlossZoneDoc? doc = store.zoneDoc;
    if (doc == null) {
      return const dom.div(classes: 'hui-zone-stage is-empty', <Widget>[]);
    }
    return _LaneStage(
      gameContext: gameContext,
      anchor: GlossGameAnchor.world,
      label: huiText('Zone'),
      stageClass: 'hui-zone',
      child: dom.div(classes: 'hui-zone-readout', <Widget>[
        Text('${doc.shape.type} · ${doc.render.mode} · ${doc.shape.world}'),
      ]),
    );
  }
}
