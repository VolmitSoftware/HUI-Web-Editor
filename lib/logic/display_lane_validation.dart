library;

import '../model/model.dart';
import 'gloss_condition_validation.dart';
import 'gloss_show.dart';
import 'validation.dart';

List<HuiIssue> _envelope(GlossDoc doc, Object? show) => <HuiIssue>[
  ...validateGlossShow(show),
  if (glossRevisionIssue(doc.revision) case final HuiIssue issue) issue,
];

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
