/// Validation for conditional Gloss scoreboard documents.
library;

import '../model/gloss_doc.dart';
import '../model/json_codec.dart';
import '../model/gloss_scoreboard.dart';
import 'gloss_text.dart';
import 'gloss_condition_validation.dart';
import 'validation.dart';
import 'gloss_show.dart';
import 'preview_expr.dart';

List<HuiIssue> validateScoreboardDoc(
  GlossScoreboardDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[
    ...validateGlossShow(doc.extras['show']),
  ];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _validateObjectives(doc.extras['objectives'], issues);
  _validateCondition(doc.select.when, r'$.select.when', issues);
  _validatePresentation(
    doc.presentation,
    r'$.presentation',
    issues,
    animations,
  );

  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.variants.length; index++) {
    final GlossScoreboardVariant variant = doc.variants[index];
    final String path =
        r'$.variants['
        '$index]';
    final String normalizedId = variant.id.trim();
    if (normalizedId.isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message: 'A conditional variant id cannot be blank.',
          fix: 'Give the variant a stable id.',
        ),
      );
    } else if (!_validVariantId.hasMatch(normalizedId)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message:
              'Variant id "{id}" contains unsupported characters. Gloss accepts only letters, numbers, dots, hyphens and underscores.',
          messageArguments: <String, Object?>{'id': variant.id},
          fix: 'Use only letters, numbers, dots, hyphens and underscores.',
        ),
      );
    } else if (!ids.add(normalizedId)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message:
              'Variant id "{id}" is duplicated; priority ties use the id as the deterministic tiebreaker.',
          messageArguments: <String, Object?>{'id': variant.id},
          fix: 'Use a unique id.',
        ),
      );
    }
    _validateCondition(variant.when, '$path.when', issues);
    _validatePresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
    );
  }

  final List<String> text = <String>[
    doc.presentation.title,
    for (final GlossScoreboardLine line in doc.presentation.lines) ...<String>[
      line.text,
      line.value ?? '',
    ],
    for (final GlossScoreboardVariant variant in doc.variants) ...<String>[
      variant.presentation.title,
      for (final GlossScoreboardLine line
          in variant.presentation.lines) ...<String>[
        line.text,
        line.value ?? '',
      ],
    ],
  ];
  final HuiIssue? metrics = glossMetricInfo(text);
  if (metrics != null) issues.add(metrics);
  return issues;
}

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

void _validatePresentation(
  GlossScoreboardPresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  _validateLayout(presentation, path, issues, animations);
  if (presentation.lines.length > glossBoardMaxLines) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.lines',
        message:
            'The presentation has {length} lines; Gloss renders at most {glossBoardMaxLines} visible rows after conditions and sections.',
        messageArguments: <String, Object?>{
          'length': presentation.lines.length,
          'glossBoardMaxLines': glossBoardMaxLines,
        },
        fix: 'Use conditions, sections or pages to choose the visible rows.',
      ),
    );
  }

  final Set<String> rowIds = <String>{};
  for (int index = 0; index < presentation.lines.length; index++) {
    final GlossScoreboardLine row = presentation.lines[index];
    final String line = row.text;
    issues.addAll(
      validateGlossShow(row.show, path: '$path.lines[$index].show'),
    );
    final String linePath = '$path.lines[$index]';
    if (row.id != null &&
        (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(row.id!) ||
            !rowIds.add(row.id!))) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$linePath.id',
          message:
              'Row IDs must be unique and contain 1–64 letters, digits, dots, underscores or hyphens.',
        ),
      );
    }
    if (row.format != null &&
        !<String>{'blank', 'fixed', 'styled', 'number'}.contains(row.format)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$linePath.format',
          message: 'Use blank, fixed, styled or number.',
        ),
      );
    }
    if (row.section != null &&
        (row.text.isNotEmpty ||
            row.value != null ||
            row.format != null ||
            row.id != null)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: linePath,
          message:
              'Section references cannot also declare text, value, format or id.',
        ),
      );
    }
    for (final String reference in glossLineMissingAnimationRefs(
      line,
      animations,
    )) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: linePath,
          message:
              '|{reference}| names an animation document this workspace does not have; the text will show literally in game.',
          messageArguments: <String, Object?>{'reference': reference},
          fix: 'Create the animation document or select an existing one.',
        ),
      );
    }
  }
  for (final String reference in glossLineMissingAnimationRefs(
    presentation.title,
    animations,
  )) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.title',
        message:
            '|{reference}| names an animation document this workspace does not have; the title will show literally in game.',
        messageArguments: <String, Object?>{'reference': reference},
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.title', text: presentation.title),
      for (int index = 0; index < presentation.lines.length; index++)
        (path: '$path.lines[$index]', text: presentation.lines[index].text),
      for (int index = 0; index < presentation.lines.length; index++)
        (
          path: '$path.lines[$index].value',
          text: presentation.lines[index].value ?? '',
        ),
    ]),
  );
}

void _validateCondition(String source, String path, List<HuiIssue> issues) =>
    issues.addAll(glossConditionIssues(source, path));

void _validateLayout(
  GlossScoreboardPresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  final Object? raw = presentation.extras['layout'];
  if (raw == null) return;
  void error(String suffix, String message) => issues.add(
    HuiIssue(
      severity: HuiSeverity.error,
      path: '$path.layout$suffix',
      message: message,
    ),
  );
  if (raw is! Map) {
    error('', 'Layout must be an object.');
    return;
  }
  final Map<String, List<GlossScoreboardLine>> sections =
      <String, List<GlossScoreboardLine>>{};
  List<GlossScoreboardLine> rows(Object? value, String suffix) {
    if (value is! List) {
      error(suffix, 'Rows must be an array.');
      return <GlossScoreboardLine>[];
    }
    if (value.length > 256) {
      error(suffix, 'At most 256 rows may be authored in one list.');
    }
    final List<GlossScoreboardLine> result = <GlossScoreboardLine>[];
    for (final (int index, Object? row) in value.take(256).indexed) {
      try {
        result.add(
          GlossScoreboardLine.fromJson(row, '$path.layout$suffix[$index]'),
        );
      } on HuiFormatException {
        error('$suffix[$index]', 'Use a text string or a valid row object.');
      }
    }
    _validatePresentation(
      GlossScoreboardPresentation(lines: result),
      '$path.layout$suffix',
      issues,
      animations,
    );
    return result;
  }

  final Object? rawSections = raw['sections'];
  if (rawSections != null && rawSections is! Map) {
    error('.sections', 'Sections must be an object.');
  }
  if (rawSections is Map) {
    if (rawSections.length > 64) {
      error('.sections', 'At most 64 sections are supported.');
    }
    for (final MapEntry<Object?, Object?> entry in rawSections.entries.take(
      64,
    )) {
      final String id = '${entry.key}';
      if (!_validRowId.hasMatch(id)) {
        error(
          '.sections.$id',
          'Use a section ID of 1–64 letters, digits, dots, underscores or hyphens, starting with a letter or digit.',
        );
      }
      sections[id] = rows(entry.value, '.sections.$id');
    }
  }
  final List<({List<GlossScoreboardLine> rows, String suffix})> roots =
      <({List<GlossScoreboardLine> rows, String suffix})>[
        (rows: presentation.lines, suffix: ''),
        for (final MapEntry<String, List<GlossScoreboardLine>> section
            in sections.entries)
          (rows: section.value, suffix: '.sections.${section.key}'),
      ];
  final Object? rawPages = raw['pages'];
  if (rawPages != null && rawPages is! List) {
    error('.pages', 'Pages must be an array.');
  }
  if (rawPages is List) {
    if (rawPages.length > 64) {
      error('.pages', 'At most 64 pages are supported.');
    }
    final Set<String> ids = <String>{};
    for (final (int index, Object? page) in rawPages.take(64).indexed) {
      final String suffix = '.pages[$index]';
      if (page is! Map) {
        error(suffix, 'A page must be an object.');
        continue;
      }
      final Object? id = page['id'];
      if (id is! String || !_validRowId.hasMatch(id) || !ids.add(id)) {
        error(
          '$suffix.id',
          'Pages require unique IDs of 1–64 letters, digits, dots, underscores or hyphens, starting with a letter or digit.',
        );
      }
      issues.addAll(
        validateGlossShow(page['show'], path: '$path.layout$suffix.show'),
      );
      final Object? duration = page['durationTicks'];
      if (duration != null &&
          (duration is! int || duration < 1 || duration > 72000)) {
        error(
          '$suffix.durationTicks',
          'Duration must be an integer from 1 to 72000 ticks.',
        );
      }
      roots.add((
        rows: rows(page['lines'] ?? <Object?>[], '$suffix.lines'),
        suffix: suffix,
      ));
      if (page['title'] != null && page['title'] is! String) {
        error('$suffix.title', 'Expected a string');
      }
      if (page['title'] is String) {
        issues.addAll(
          glossTextExpressionIssues(<({String path, String text})>[
            (path: '$path.layout$suffix.title', text: page['title'] as String),
          ]),
        );
      }
    }
  }
  final Object? overflow = raw['overflow'];
  if (overflow != null && overflow != 'truncate' && overflow != 'error') {
    error('.overflow', 'Use truncate or error.');
  }
  for (final ({List<GlossScoreboardLine> rows, String suffix}) root in roots) {
    final Set<String> ids = <String>{};
    int count = 0;
    void expand(List<GlossScoreboardLine> entries, Set<String> active) {
      for (final GlossScoreboardLine row in entries) {
        if (count > 256) return;
        if (row.section case final String section) {
          if (!sections.containsKey(section)) {
            error(root.suffix, 'Unknown section "$section".');
          } else if (!active.add(section)) {
            error(root.suffix, 'Section "$section" refers back to itself.');
          } else {
            expand(sections[section]!, active);
            active.remove(section);
          }
        } else {
          count++;
          if (row.id != null && !ids.add(row.id!)) {
            error(root.suffix, 'Expanded rows repeat ID "${row.id}".');
          }
        }
      }
    }

    expand(root.rows, <String>{});
    if (count > 256) {
      error(root.suffix, 'A layout may expand to at most 256 rows.');
    }
    if (overflow == 'error' && count > glossBoardMaxLines) {
      error(
        root.suffix,
        'Overflow error allows at most 15 expanded rows, including conditional rows.',
      );
    }
  }
  final Object? refresh = raw['refresh'];
  if (refresh != null && refresh is! Map) {
    error('.refresh', 'Refresh must be an object.');
  }
  if (refresh is Map) {
    for (final String field in <String>[
      'titleTicks',
      'textTicks',
      'valueTicks',
    ]) {
      final Object? interval = refresh[field];
      if (interval != null &&
          (interval is! int || interval < 1 || interval > 72000)) {
        error(
          '.refresh.$field',
          'Refresh must be an integer from 1 to 72000 ticks.',
        );
      }
    }
  }
}

final RegExp _validRowId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

void _validateObjectives(Object? raw, List<HuiIssue> issues) {
  if (raw == null) return;
  void error(String path, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
  if (raw is! Map) {
    error(r'$.objectives', 'Native objectives must be an object.');
    return;
  }
  for (final String name in <String>['playerList', 'belowName']) {
    final Object? slot = raw[name];
    if (slot == null) continue;
    final String path = r'$.objectives.' + name;
    if (slot is! Map) {
      error(path, 'A native objective must be an object.');
      continue;
    }
    for (final String field in <String>['title', 'value', 'valueText']) {
      final Object? value = slot[field];
      if (value == null) continue;
      if (value is! String) {
        error('$path.$field', 'Expected a string');
        continue;
      }
      if (field == 'value') {
        try {
          parsePreviewExpr(value);
        } on PExprException catch (failure) {
          issues.add(
            HuiIssue(
              severity: HuiSeverity.error,
              path: '$path.value',
              message: 'Invalid numeric expression: {error}',
              messageArguments: <String, Object?>{'error': failure.message},
            ),
          );
        }
      } else {
        issues.addAll(
          glossTextExpressionIssues(
            <({String path, String text})>[(path: '$path.$field', text: value)],
            expressionSamples: const GlossTextExpressionSamples(
              values: <String, Object>{
                ...glossScopedSampleValues,
                'subject.health': 18.0,
                'subject.maxHealth': 20.0,
                'subject.healthPercent': 90.0,
                'subject.level': 27.0,
                'subject.ping': 42.0,
                'subject.gameMode': 'survival',
              },
            ),
          ),
        );
      }
    }
    for (final MapEntry<String, Set<String>> field
        in const <String, Set<String>>{
          'renderType': <String>{'integer', 'hearts'},
          'format': <String>{'number', 'blank', 'fixed', 'styled'},
          'conflict': <String>{'yield', 'override'},
        }.entries) {
      final Object? value = slot[field.key];
      if (value != null &&
          (value is! String ||
              !field.value.contains(
                field.key == 'format'
                    ? value.trim().toLowerCase()
                    : value.toLowerCase(),
              ))) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.error,
            path: '$path.${field.key}',
            message: 'Choose one of: {values}',
            messageArguments: <String, Object?>{
              'values': field.value.join(', '),
            },
          ),
        );
      }
    }
    for (final String condition in <String>['show', 'subjects']) {
      issues.addAll(
        validateGlossShow(slot[condition], path: '$path.$condition'),
      );
    }
    final Object? interval = slot['refreshTicks'];
    if (interval != null &&
        (interval is! int || interval < 1 || interval > 72000)) {
      error(
        '$path.refreshTicks',
        'Refresh must be an integer from 1 to 72000 ticks.',
      );
    }
  }
}
