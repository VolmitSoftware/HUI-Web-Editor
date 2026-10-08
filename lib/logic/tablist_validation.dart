/// Validation for conditional Gloss tablist documents.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_tablist.dart';
import '../model/gloss_tab_layout.dart';
import 'gloss_text.dart';
import 'gloss_condition_validation.dart';
import 'validation.dart';
import 'gloss_show.dart';
import 'preview_expr.dart';

List<HuiIssue> validateTablistDoc(
  GlossTablistDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[
    ...validateGlossShow(doc.extras['show']),
    ...validateGlossShow(
      doc.headerFooter.extras['show'],
      path: r'$.headerFooter.show',
    ),
    ...validateGlossShow(
      doc.listNames.extras['show'],
      path: r'$.listNames.show',
    ),
  ];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _validateHeaderFooterPresentation(
    doc.headerFooter.presentation,
    r'$.headerFooter.presentation',
    issues,
    animations,
  );
  _validateHeaderFooterVariants(doc, issues, animations);
  _validateListNamePresentation(
    doc.listNames.presentation,
    r'$.listNames.presentation',
    issues,
    animations,
  );
  _validateListNameVariants(doc, issues, animations);

  final GlossTabLayout? layout = doc.layout;
  if (layout != null) {
    issues.addAll(validateGlossShow(layout.show, path: r'$.layout.show'));
    _validateLayout(layout, r'$.layout', issues);
    final Set<String> ids = <String>{};
    for (int index = 0; index < layout.variants.length; index++) {
      final GlossTabLayoutVariant variant = layout.variants[index];
      final String path =
          r'$.layout.variants['
          '$index]';
      _validateLayoutIdentity(variant.id, '$path.id', ids, issues);
      issues.addAll(glossConditionIssues(variant.when, '$path.when'));
      _validateLayout(variant.presentation, '$path.presentation', issues);
    }
  }

  final List<String> allText = <String>[
    doc.headerFooter.presentation.header,
    doc.headerFooter.presentation.footer,
    doc.listNames.presentation.format,
    for (final GlossTablistHeaderFooterVariant variant
        in doc.headerFooter.variants) ...<String>[
      variant.presentation.header,
      variant.presentation.footer,
    ],
    for (final GlossTablistListNameVariant variant in doc.listNames.variants)
      variant.presentation.format,
  ];
  final HuiIssue? metrics = glossMetricInfo(allText);
  if (metrics != null) issues.add(metrics);
  return issues;
}

void _validateHeaderFooterVariants(
  GlossTablistDoc doc,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.headerFooter.variants.length; index++) {
    final GlossTablistHeaderFooterVariant variant =
        doc.headerFooter.variants[index];
    final String path =
        r'$.headerFooter.variants['
        '$index]';
    _validateVariantIdentity(variant.id, '$path.id', ids, issues);
    _validateCondition(variant.when, '$path.when', issues);
    _validateHeaderFooterPresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
    );
  }
}

void _validateListNameVariants(
  GlossTablistDoc doc,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.listNames.variants.length; index++) {
    final GlossTablistListNameVariant variant = doc.listNames.variants[index];
    final String path =
        r'$.listNames.variants['
        '$index]';
    _validateVariantIdentity(variant.id, '$path.id', ids, issues);
    _validateCondition(variant.when, '$path.when', issues);
    _validateListNamePresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
    );
  }
}

void _validateVariantIdentity(
  String id,
  String path,
  Set<String> ids,
  List<HuiIssue> issues,
) {
  final String normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message: 'A conditional variant id cannot be blank.',
        fix: 'Give the variant a stable id.',
      ),
    );
  } else if (!_validVariantId.hasMatch(normalizedId)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" contains unsupported characters. Gloss accepts only letters, numbers, dots, hyphens and underscores.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use only letters, numbers, dots, hyphens and underscores.',
      ),
    );
  } else if (!ids.add(normalizedId)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" is duplicated; priority ties use the id as the deterministic tiebreaker.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use a unique id within this section.',
      ),
    );
  }
}

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

void _validateHeaderFooterPresentation(
  GlossTablistHeaderFooterPresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  _danglingRefs(
    presentation.header,
    '$path.header',
    'header',
    issues,
    animations,
  );
  _danglingRefs(
    presentation.footer,
    '$path.footer',
    'footer',
    issues,
    animations,
  );
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.header', text: presentation.header),
      (path: '$path.footer', text: presentation.footer),
    ]),
  );
}

void _validateListNamePresentation(
  GlossTablistListNamePresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  if (presentation.format.trim().isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.info,
        path: '$path.format',
        message:
            'A blank list-name format resets matching players to their vanilla list name.',
        fix: 'Keep the reset deliberately or enter a format.',
      ),
    );
  }
  _danglingRefs(
    presentation.format,
    '$path.format',
    'list name',
    issues,
    animations,
  );
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.format', text: presentation.format),
    ]),
  );
}

void _danglingRefs(
  String text,
  String path,
  String surface,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  for (final String reference in glossLineMissingAnimationRefs(
    text,
    animations,
  )) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: path,
        message:
            '|{reference}| names an animation document this workspace does not have; the text will show literally in the {surface}.',
        messageArguments: <String, Object?>{
          'reference': reference,
          'surface': surface,
        },
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
}

void _validateCondition(String source, String path, List<HuiIssue> issues) =>
    issues.addAll(glossConditionIssues(source, path));

void _layoutError(List<HuiIssue> issues, String path, String message) {
  issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
}

void _validateLayout(
  GlossTabPresentation layout,
  String path,
  List<HuiIssue> issues,
) {
  if (layout.entries < 1 || layout.entries > 80) {
    _layoutError(
      issues,
      '$path.entries',
      'Minecraft tab layouts require 1–80 entries.',
    );
    return;
  }
  final Set<int> occupied = <int>{};
  bool claim(int column, int row, String owner) {
    final int index = column * layout.rows + row;
    if (column < 0 ||
        column >= layout.columns ||
        row < 0 ||
        row >= layout.rows ||
        index >= layout.entries) {
      _layoutError(
        issues,
        owner,
        'Cell is outside the entry-count-derived client geometry.',
      );
      return false;
    }
    if (!occupied.add(index)) {
      _layoutError(
        issues,
        owner,
        'Fixed slots and roster sections cannot overlap.',
      );
    }
    return true;
  }

  for (int index = 0; index < layout.slots.length; index++) {
    final GlossTabSlot slot = layout.slots[index];
    claim(slot.column, slot.row, '$path.slots[$index]');
    issues.addAll(
      glossTextExpressionIssues(<({String path, String text})>[
        (path: '$path.slots[$index].text', text: slot.text),
      ]),
    );
    if (slot.ping != null && (slot.ping! < -1 || slot.ping! > 10000)) {
      _layoutError(
        issues,
        '$path.slots[$index].ping',
        'Ping must be between -1 and 10000.',
      );
    }
  }
  final Set<String> ids = <String>{};
  for (int index = 0; index < layout.sections.length; index++) {
    final GlossTabSection section = layout.sections[index];
    final String owner = '$path.sections[$index]';
    _validateLayoutIdentity(section.id, '$owner.id', ids, issues);
    issues.addAll(glossConditionIssues(section.filter, '$owner.filter'));
    if (section.columns < 1 ||
        section.columns > 4 ||
        section.rows < 1 ||
        section.rows > 20) {
      _layoutError(
        issues,
        owner,
        'Section dimensions must fit 1–4 columns and 1–20 rows.',
      );
    } else {
      for (
        int column = section.column;
        column < section.column + section.columns;
        column++
      ) {
        for (int row = section.row; row < section.row + section.rows; row++) {
          claim(column, row, owner);
        }
      }
    }
    if (!<String>{'hide', 'count'}.contains(section.overflow)) {
      _layoutError(
        issues,
        '$owner.overflow',
        'Overflow must be hide or count.',
      );
    }
    if (section.sort.length > 16) {
      _layoutError(
        issues,
        '$owner.sort',
        'A section accepts at most 16 sort keys.',
      );
    }
    for (int keyIndex = 0; keyIndex < section.sort.length; keyIndex++) {
      final GlossTabSortKey key = section.sort[keyIndex];
      try {
        parsePreviewExpr(key.expression);
      } on PExprException {
        _layoutError(
          issues,
          '$owner.sort[$keyIndex].expression',
          'Invalid sort expression.',
        );
      }
      if (!<String>{'text', 'number'}.contains(key.type)) {
        _layoutError(
          issues,
          '$owner.sort[$keyIndex].type',
          'Sort type must be text or number.',
        );
      }
      if (!<String>{'ascending', 'descending'}.contains(key.direction)) {
        _layoutError(
          issues,
          '$owner.sort[$keyIndex].direction',
          'Sort direction must be ascending or descending.',
        );
      }
    }
    issues.addAll(
      glossTextExpressionIssues(<({String path, String text})>[
        if (section.format != null)
          (path: '$owner.format', text: section.format!),
        (path: '$owner.overflowFormat', text: section.overflowFormat),
      ]),
    );
  }
  for (final MapEntry<String, GlossTabSkin> entry in layout.skins.entries) {
    _validateLayoutIdentity(entry.key, '$path.skins', <String>{}, issues);
    if (entry.value.value.trim().isEmpty ||
        entry.value.value.length > 16384 ||
        (entry.value.signature?.length ?? 0) > 16384) {
      _layoutError(
        issues,
        '$path.skins.${entry.key}',
        'Texture values require 1–16384 characters; signatures accept at most 16384.',
      );
    }
  }
}

void _validateLayoutIdentity(
  String id,
  String path,
  Set<String> ids,
  List<HuiIssue> issues,
) {
  final String normalized = id.trim();
  if (!RegExp(r'^[\p{L}\p{Nd}._-]+$', unicode: true).hasMatch(normalized)) {
    _layoutError(
      issues,
      path,
      'Use a nonempty identifier containing letters, numbers, dots, hyphens or underscores.',
    );
  } else if (!ids.add(normalized)) {
    _layoutError(issues, path, 'Identifiers must be unique after trimming.');
  }
}
