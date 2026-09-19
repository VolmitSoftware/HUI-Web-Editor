library;

import '../model/model.dart';
import 'gloss_condition_validation.dart';
import 'gloss_show.dart';
import 'validation.dart';

List<HuiIssue> _envelope(GlossDoc doc, Object? show) => <HuiIssue>[
  ...validateGlossShow(show),
  if (glossRevisionIssue(doc.revision) case final HuiIssue issue) issue,
];

List<HuiIssue> validateDialogDoc(GlossDialogDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (!glossDialogTypes.contains(doc.type)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.type',
        message: 'Dialog type must be notice, confirmation, multi_action, server_links or dialog_list.',
        fix: 'Pick one of the five protocol shapes.',
      ),
    );
  }
  if (doc.title.trim().isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.title',
        message: 'A dialog needs a title.',
        fix: 'Write the title the client shows.',
      ),
    );
  }
  if (!glossDialogAfterActions.contains(doc.afterAction)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.afterAction',
        message: 'afterAction must be close, none or wait_for_response.',
        fix: 'Use close unless the screen should stay open.',
      ),
    );
  }
  if (doc.pause && doc.afterAction == 'none') {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.afterAction',
        message: 'A paused dialog cannot use afterAction none; the client would stay paused.',
        fix: 'Use close or wait_for_response.',
      ),
    );
  }
  if (doc.type == 'notice' && doc.buttons.length > 1) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.buttons',
        message: 'A notice dialog declares at most one button.',
        fix: 'Keep one button, or switch the type to multi_action.',
      ),
    );
  }
  if (doc.type == 'confirmation' && (doc.yes == null || doc.no == null)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.yes',
        message: 'A confirmation dialog requires both yes and no buttons.',
        fix: 'Add yes and no.',
      ),
    );
  }
  if (doc.type == 'multi_action' && doc.buttons.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.buttons',
        message: 'A multi_action dialog needs at least one button.',
        fix: 'Add a button.',
      ),
    );
  }
  if (doc.type == 'dialog_list' && doc.dialogs.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.dialogs',
        message: 'A dialog_list dialog needs at least one dialog id.',
        fix: 'List the dialog ids to offer.',
      ),
    );
  }
  if (doc.body.length > glossDialogMaxBody) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.body',
        message: 'A dialog declares at most {maximum} body blocks.',
        messageArguments: <String, Object?>{'maximum': glossDialogMaxBody},
        fix: 'Remove extra body blocks.',
      ),
    );
  }
  final Set<String> keys = <String>{};
  for (int index = 0; index < doc.inputs.length; index++) {
    final String key = doc.inputs[index].key.trim();
    if (key.isEmpty || !keys.add(key)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'inputs[$index].key',
          message: 'Each dialog input needs a unique key.',
          fix: 'Give this input its own key.',
        ),
      );
    }
  }
  issues.addAll(glossConditionIssues(doc.select.when, r'$.select.when'));
  return issues;
}

List<HuiIssue> validateInventoryDoc(GlossInventoryDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (!glossInventoryResolutions.contains(doc.resolution)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.resolution',
        message: 'Inventory resolution must be one of 9x1-9x6, 5x1 or 3x3.',
        fix: 'Pick a vanilla chest size.',
      ),
    );
  }
  final int width = doc.width;
  final int rows = doc.rows;
  if (doc.mask.length > rows) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.mask',
        message: 'The mask has more rows than the resolution allows.',
        fix: 'Keep the mask at {rows} rows.',
        fixArguments: <String, Object?>{'rows': rows},
      ),
    );
  }
  for (int index = 0; index < doc.mask.length; index++) {
    if (doc.mask[index].length != width) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'mask[$index]',
          message: 'Each mask row must be exactly {width} characters.',
          messageArguments: <String, Object?>{'width': width},
          fix: 'Pad or trim this row.',
        ),
      );
    }
  }
  if (doc.list != null) {
    if (doc.list!.area.length != 1) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.list.area',
          message: 'Inventory list area must be exactly one mask character.',
          fix: 'Use a single character that appears in the mask.',
        ),
      );
    } else if (!doc.mask.any((String row) => row.contains(doc.list!.area))) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.list.area',
          message: "List area '{area}' does not appear in the mask.",
          messageArguments: <String, Object?>{'area': doc.list!.area},
          fix: 'Put that character in the mask, or change the list area.',
        ),
      );
    }
    if (doc.list!.source.trim().isEmpty) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.list.source',
          message: 'Inventory list requires a source expression.',
          fix: 'Write the list source.',
        ),
      );
    }
  }
  issues.addAll(glossConditionIssues(doc.select.when, r'$.select.when'));
  return issues;
}

List<HuiIssue> validateNameplateDoc(GlossNameplateDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (doc.presentation.lines.length > glossNameplateMaxLines) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.presentation.lines',
        message: 'A nameplate may declare at most {maximum} lines.',
        messageArguments: <String, Object?>{'maximum': glossNameplateMaxLines},
        fix: 'Remove extra lines.',
      ),
    );
  }
  issues.addAll(glossConditionIssues(doc.select.when, r'$.select.when'));
  for (int index = 0; index < doc.variants.length; index++) {
    issues.addAll(
      glossConditionIssues(
        doc.variants[index].when,
        'variants[$index].when',
      ),
    );
  }
  return issues;
}

List<HuiIssue> validateNametagDoc(GlossNametagDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (!glossNametagVisibilities.contains(doc.presentation.nameTagVisibility)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.presentation.nameTagVisibility',
        message:
            'nameTagVisibility must be always, never, hide_for_other_teams or hide_for_own_team.',
        fix: 'Pick one of the four vanilla team values.',
      ),
    );
  }
  if (!glossNametagCollisions.contains(doc.presentation.collision)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.presentation.collision',
        message:
            'collision must be always, never, push_other_teams or push_own_team.',
        fix: 'Pick one of the four vanilla team values.',
      ),
    );
  }
  issues.addAll(glossConditionIssues(doc.select.when, r'$.select.when'));
  for (int index = 0; index < doc.variants.length; index++) {
    if (doc.variants[index].id.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'variants[$index].id',
          message: 'A nametag variant id may not be blank.',
          fix: 'Give the variant an id.',
        ),
      );
    }
    issues.addAll(
      glossConditionIssues(doc.variants[index].when, 'variants[$index].when'),
    );
  }
  return issues;
}

List<HuiIssue> validateMotionDoc(GlossMotionDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[
    if (glossRevisionIssue(doc.revision) case final HuiIssue issue) issue,
  ];
  if (!glossMotionLoops.contains(doc.loop)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.loop',
        message: 'Motion loop must be once, loop or pingpong.',
        fix: 'Pick a loop mode.',
      ),
    );
  }
  if (doc.tracks.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.tracks',
        message: 'Motion needs at least one track.',
        fix: 'Add a track with two keyframes.',
      ),
    );
  }
  for (int index = 0; index < doc.tracks.length; index++) {
    final GlossMotionTrack track = doc.tracks[index];
    if (track.keyframes.isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'tracks[$index].keyframes',
          message: 'Each motion track needs at least one keyframe.',
          fix: 'Add a keyframe.',
        ),
      );
    }
  }
  return issues;
}

List<HuiIssue> validateRigDoc(GlossRigDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (doc.bones.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.bones',
        message: 'A rig needs at least one bone.',
        fix: 'Add a root bone.',
      ),
    );
  }
  if (doc.parts.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.parts',
        message: 'A rig needs at least one part.',
        fix: 'Attach a block, item or text part to a bone.',
      ),
    );
  }
  final Set<String> boneIds = <String>{
    for (final GlossRigBone bone in doc.bones) bone.id,
  };
  final Set<String> partIds = <String>{};
  for (int index = 0; index < doc.parts.length; index++) {
    final GlossRigPart part = doc.parts[index];
    if (!partIds.add(part.id) || part.id.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'parts[$index].id',
          message: 'Each rig part needs a unique id.',
          fix: 'Rename this part.',
        ),
      );
    }
    if (!boneIds.contains(part.bone)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: 'parts[$index].bone',
          message: 'Part {id} names unknown bone {bone}.',
          messageArguments: <String, Object?>{'id': part.id, 'bone': part.bone},
          fix: 'Point it at a declared bone.',
        ),
      );
    }
  }
  return issues;
}

List<HuiIssue> validateMarkerDoc(GlossMarkerDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  final GlossMarkerAnchor anchor = doc.anchor;
  final bool hasPosition =
      (anchor.world != null && anchor.world!.trim().isNotEmpty) ||
      anchor.x != null ||
      anchor.y != null ||
      anchor.z != null;
  final int targets =
      (hasPosition ? 1 : 0) +
      ((anchor.entity != null && anchor.entity!.trim().isNotEmpty) ? 1 : 0) +
      ((anchor.player != null && anchor.player!.trim().isNotEmpty) ? 1 : 0);
  if (targets != 1) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.anchor',
        message:
            'A marker anchor must name exactly one of a world position, an entity or a player.',
        fix: 'Keep world+x+y+z, or entity, or player.',
      ),
    );
  }
  if (hasPosition &&
      (anchor.world == null ||
          anchor.world!.trim().isEmpty ||
          anchor.x == null ||
          anchor.y == null ||
          anchor.z == null)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.anchor',
        message: 'A position anchor requires world, x, y and z.',
        fix: 'Fill in the world and the three coordinates.',
      ),
    );
  }
  return issues;
}

List<HuiIssue> validateZoneDoc(GlossZoneDoc doc) {
  final List<HuiIssue> issues = _envelope(doc, doc.extras['show']);
  if (!glossZoneShapeTypes.contains(doc.shape.type)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.shape.type',
        message: 'Zone shape type must be cuboid, cylinder, polygon or region.',
        fix: 'Pick a shape type.',
      ),
    );
  }
  if (!glossZoneRenderModes.contains(doc.render.mode)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.render.mode',
        message: 'Zone render mode must be particles, walls or hybrid.',
        fix: 'Pick a render mode.',
      ),
    );
  }
  return issues;
}
