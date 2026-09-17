/// Validation for Gloss surface documents — the HUD lines under
/// `plugins/Gloss/surfaces/`.
///
/// `SurfaceDoc.java` splits its rules into three kinds of outcome, and this
/// file keeps them apart because the author needs to know which is which:
///
///  * Refused. A missing or unknown `surface`, a presentation without the key
///    its kind needs, a blank or non-compiling condition, an unknown slot,
///    colour, style, trigger or priority name, a progress expression that does
///    not parse, and a blank or duplicated variant id. Every one of these
///    throws out of the parser, so the whole file fails to load.
///  * Clamped. `ttlTicks`, the three fade counts and `repeatTicks` are pinned
///    into range rather than refused (`Presentation.clamp`), so an out-of-range
///    number is a value the server quietly changes — a warning that says what
///    it will change it to.
///  * Dropped. `Presentation.forKind` rebuilds the record out of the surface
///    kind's own fields alone and discards the rest without a word, so a
///    bossbar carrying `text` keeps it in the file and never shows it.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_surface.dart';
import 'gloss_condition_validation.dart';
import 'gloss_show.dart';
import 'gloss_text.dart';
import 'preview_expr.dart';
import 'validation.dart';

/// What a surface line reads. `SurfaceDelivery` builds the scope around the
/// viewer the line is composed for, so the text sees `viewer.*` and
/// `subject.*` exactly as a condition does.
const GlossTextExpressionSamples glossSurfaceSamples =
    GlossTextExpressionSamples(values: glossScopedSampleValues);

/// The presentation fields that carry authored text or an expression. A kind
/// dropping one of these loses work someone typed, which is worth a warning;
/// dropping a colour or a tick count is worth an info.
const Set<String> _contentFields = <String>{
  'text',
  'title',
  'subtitle',
  'progress',
};

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

List<HuiIssue> validateSurfaceDoc(
  GlossSurfaceDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[
    ...validateGlossShow(doc.extras['show']),
  ];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _validateSurfaceKind(doc, issues);
  _validateSelect(doc, issues);

  _validatePresentation(
    doc.presentation,
    r'$.presentation',
    doc,
    issues,
    animations,
  );

  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.variants.length; index++) {
    final GlossSurfaceVariant variant = doc.variants[index];
    final String path =
        r'$.variants['
        '$index]';
    _validateVariantId(variant.id, '$path.id', ids, issues);
    _validateVariantCondition(variant.when, '$path.when', issues);
    _validatePresentation(
      variant.presentation,
      '$path.presentation',
      doc,
      issues,
      animations,
    );
  }

  final HuiIssue? metrics = glossMetricInfo(<String>[
    for (final GlossSurfacePresentation presentation
        in <GlossSurfacePresentation>[
          doc.presentation,
          for (final GlossSurfaceVariant variant in doc.variants)
            variant.presentation,
        ]) ...<String>[
      presentation.text ?? '',
      presentation.title ?? '',
      presentation.subtitle ?? '',
    ],
  ]);
  if (metrics != null) issues.add(metrics);

  return issues;
}

void _validateSurfaceKind(GlossSurfaceDoc doc, List<HuiIssue> issues) {
  if (doc.surface.trim().isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.surface',
        message:
            'This document names no surface. Gloss refuses the whole file '
            'without one of {allowed}.',
        messageArguments: <String, Object?>{
          'allowed': glossSurfaceKinds.join(', '),
        },
        fix: 'Pick the surface this document draws on.',
      ),
    );
    return;
  }
  if (!doc.hasKnownSurface) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.surface',
        message:
            'Surface "{surface}" is not one of {allowed}; Gloss refuses the '
            'whole file.',
        messageArguments: <String, Object?>{
          'surface': doc.surface,
          'allowed': glossSurfaceKinds.join(', '),
        },
        fix: 'Pick the surface this document draws on.',
      ),
    );
  }
}

void _validateSelect(GlossSurfaceDoc doc, List<HuiIssue> issues) {
  const String path = r'$.select.when';
  if (doc.select.when.trim().isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'A surface selection needs a condition; Gloss refuses the whole '
            'file when one is blank.',
        fix:
            'Write the condition, or leave the key out to keep the '
            'never-selected default.',
      ),
    );
    return;
  }
  issues.addAll(glossConditionIssues(doc.select.when, path));
  if (doc.select.when.trim() == glossSurfaceNeverCondition) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: path,
        message:
            'The selection condition is false, which is the default a '
            'document with no condition takes, so this surface never reaches '
            'anyone.',
        fix: 'Write the condition that should put this surface on screen.',
      ),
    );
  }
}

void _validateVariantId(
  String id,
  String path,
  Set<String> ids,
  List<HuiIssue> issues,
) {
  final String normalized = id.trim();
  if (normalized.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message: 'A conditional variant id cannot be blank.',
        fix: 'Give the variant a stable id.',
      ),
    );
    return;
  }
  if (!_validVariantId.hasMatch(normalized)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" contains unsupported characters. Gloss accepts '
            'only letters, numbers, dots, hyphens and underscores.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use only letters, numbers, dots, hyphens and underscores.',
      ),
    );
    return;
  }
  if (!ids.add(normalized)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" is duplicated; priority ties use the id as the '
            'deterministic tiebreaker.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use a unique id.',
      ),
    );
  }
}

void _validateVariantCondition(
  String when,
  String path,
  List<HuiIssue> issues,
) {
  if (when.trim().isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'A surface variant needs a condition; Gloss refuses the whole '
            'file when one is blank.',
        fix: 'Give the variant a condition, or delete it.',
      ),
    );
    return;
  }
  issues.addAll(glossConditionIssues(when, path));
}

void _validatePresentation(
  GlossSurfacePresentation presentation,
  String path,
  GlossSurfaceDoc doc,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  if (doc.hasKnownSurface) {
    _validateKindFields(presentation, path, doc.surface, issues);
  }
  _validateSlots(presentation.slots, '$path.slots', issues);
  _validateName(
    presentation.priority,
    'priority',
    glossSurfacePriorities,
    '$path.priority',
    issues,
  );
  _validateName(
    presentation.color,
    'color',
    glossSurfaceColors,
    '$path.color',
    issues,
  );
  _validateName(
    presentation.style,
    'style',
    glossSurfaceStyles,
    '$path.style',
    issues,
  );
  _validateName(
    presentation.trigger,
    'trigger',
    glossSurfaceTriggers,
    '$path.trigger',
    issues,
  );
  _validateProgress(presentation.progress, '$path.progress', issues);
  _validateClamp(
    presentation.ttlTicks,
    'ttlTicks',
    glossSurfaceMinTtlTicks,
    glossSurfaceMaxTtlTicks,
    '$path.ttlTicks',
    issues,
  );
  for (final (String field, int? value) in <(String, int?)>[
    ('fadeInTicks', presentation.fadeInTicks),
    ('stayTicks', presentation.stayTicks),
    ('fadeOutTicks', presentation.fadeOutTicks),
  ]) {
    _validateClamp(
      value,
      field,
      glossSurfaceMinFadeTicks,
      glossSurfaceMaxFadeTicks,
      '$path.$field',
      issues,
    );
  }
  _validateClamp(
    presentation.repeatTicks,
    'repeatTicks',
    glossSurfaceMinRepeatTicks,
    glossSurfaceMaxRepeatTicks,
    '$path.repeatTicks',
    issues,
  );

  _validateLine(
    presentation.text,
    '$path.text',
    issues,
    animations,
    isTitle: false,
  );
  _validateLine(
    presentation.title,
    '$path.title',
    issues,
    animations,
    isTitle: true,
  );
  _validateLine(
    presentation.subtitle,
    '$path.subtitle',
    issues,
    animations,
    isTitle: false,
  );
}

/// The two halves of `Presentation.forKind`: the field the kind cannot open
/// without, and the fields it silently discards.
void _validateKindFields(
  GlossSurfacePresentation presentation,
  String path,
  String surface,
  List<HuiIssue> issues,
) {
  final String required = glossSurfaceRequiredField[surface]!;
  final String? value = required == 'text'
      ? presentation.text
      : presentation.title;
  if (value == null || value.trim().isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: '$path.$required',
        message:
            'A {surface} surface has no {field}, so Gloss refuses the whole '
            'file.',
        messageArguments: <String, Object?>{
          'surface': surface,
          'field': required,
        },
        fix: 'Write the {field}, or change the surface this document draws on.',
        fixArguments: <String, Object?>{'field': required},
      ),
    );
  }

  final Set<String> kept = glossSurfaceKindFields[surface]!;
  for (final String field in presentation.authoredFields) {
    if (kept.contains(field)) continue;
    issues.add(
      HuiIssue(
        severity: _contentFields.contains(field)
            ? HuiSeverity.warning
            : HuiSeverity.info,
        path: '$path.$field',
        message:
            'Gloss drops {field} on a {surface} surface, so this value never '
            'reaches the client.',
        messageArguments: <String, Object?>{
          'field': field,
          'surface': surface,
        },
        fix:
            'Delete the field, or change the surface this document draws on '
            'to one that uses it.',
      ),
    );
  }
}

void _validateSlots(
  List<String>? slots,
  String path,
  List<HuiIssue> issues,
) {
  if (slots == null) return;
  for (final String slot in slots) {
    final String normalized = slot.trim().toLowerCase();
    if (glossSurfaceSlots.contains(normalized)) continue;
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Slot "{slot}" is not one of {allowed}; Gloss refuses the whole '
            'file.',
        messageArguments: <String, Object?>{
          'slot': slot,
          'allowed': glossSurfaceSlots.join(', '),
        },
        fix: 'Use {allowed}.',
        fixArguments: <String, Object?>{
          'allowed': glossSurfaceSlots.join(', '),
        },
      ),
    );
  }
}

void _validateName(
  String? value,
  String field,
  List<String> allowed,
  String path,
  List<HuiIssue> issues,
) {
  if (value == null) return;
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || allowed.contains(normalized)) return;
  issues.add(
    HuiIssue(
      severity: HuiSeverity.error,
      path: path,
      message:
          'The {field} "{value}" is not one of {allowed}; Gloss refuses the '
          'whole file.',
      messageArguments: <String, Object?>{
        'field': field,
        'value': value,
        'allowed': allowed.join(', '),
      },
      fix: 'Use {allowed}.',
      fixArguments: <String, Object?>{'allowed': allowed.join(', ')},
    ),
  );
}

void _validateProgress(String? progress, String path, List<HuiIssue> issues) {
  final String? source = glossSurfaceProgressSource(progress);
  if (source == null) return;
  if (source.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'The progress expression is empty; Gloss refuses the whole file.',
        fix:
            'Write an expression that yields 0 through 1, or leave progress '
            'out to keep the bar full.',
      ),
    );
    return;
  }
  try {
    parsePreviewExpr(source);
  } on PExprException catch (error) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'The progress expression does not compile: {error}. Gloss refuses '
            'the whole file.',
        messageArguments: <String, Object?>{'error': error.message},
        fix: 'Correct the expression; it must yield a number from 0 through 1.',
      ),
    );
  }
}

void _validateClamp(
  int? value,
  String field,
  int minimum,
  int maximum,
  String path,
  List<HuiIssue> issues,
) {
  if (value == null || (value >= minimum && value <= maximum)) return;
  issues.add(
    HuiIssue(
      severity: HuiSeverity.warning,
      path: path,
      message:
          'Gloss pins {field} into {minimum} through {maximum}, so it delivers '
          '{clamped} rather than {value}.',
      messageArguments: <String, Object?>{
        'field': field,
        'minimum': minimum,
        'maximum': maximum,
        'clamped': value < minimum ? minimum : maximum,
        'value': value,
      },
      fix: 'Use a value from {minimum} through {maximum}.',
      fixArguments: <String, Object?>{'minimum': minimum, 'maximum': maximum},
    ),
  );
}

void _validateLine(
  String? text,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations, {
  required bool isTitle,
}) {
  if (text == null || text.isEmpty) return;
  for (final String reference in glossLineMissingAnimationRefs(
    text,
    animations,
  )) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: path,
        message: isTitle
            ? '|{reference}| names an animation document this workspace does not have; the title will show literally in game.'
            : '|{reference}| names an animation document this workspace does not have; the text will show literally in game.',
        messageArguments: <String, Object?>{'reference': reference},
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: path, text: text),
    ], expressionSamples: glossSurfaceSamples),
  );
}
