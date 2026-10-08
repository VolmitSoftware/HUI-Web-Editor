library;

import '../model/gloss_channel.dart';
import '../model/gloss_doc.dart';
import 'gloss_show.dart';
import 'channel_filter_preview.dart';
import 'validation.dart';

List<HuiIssue> validateChannelDoc(GlossChannelDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[...validateGlossShow(doc.show)];
  final HuiIssue? revision = glossRevisionIssue(doc.revision);
  if (revision != null) issues.add(revision);
  void error(String path, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$').hasMatch(doc.channel.name)) {
    error(
      r'$.channel.name',
      'Use a lowercase channel name with letters, numbers, underscores or hyphens.',
    );
  }
  if (!const <String>[
    'global',
    'world',
    'radius',
    'permission',
    'direct',
  ].contains(doc.channel.scope)) {
    error(r'$.channel.scope', 'Choose a supported channel audience.');
  }
  if (doc.channel.scope == 'radius' && doc.channel.radius <= 0) {
    error(r'$.channel.radius', 'A radius channel needs a positive radius.');
  }
  if (doc.channel.scope == 'permission' &&
      doc.channel.permission.trim().isEmpty) {
    error(r'$.channel.permission', 'A permission channel needs a permission.');
  }
  for (final MapEntry<String, String> entry in <String, String>{
    r'$.format': doc.format,
    r'$.mentions.render': doc.mentions.render,
    r'$.mentions.messageFormat': doc.mentions.messageFormat,
  }.entries) {
    if (entry.value.trim().isEmpty || entry.value.length > 4096) {
      error(entry.key, 'Enter between 1 and 4096 characters.');
    }
  }
  if ('{name}'.allMatches(doc.mentions.pattern).length != 1) {
    error(
      r'$.mentions.pattern',
      'The mention pattern must contain exactly one {name}.',
    );
  }
  final Set<String> ids = <String>{};
  if (doc.variants.length > 32) {
    error(r'$.variants', 'A channel supports at most 32 variants.');
  }
  for (int index = 0; index < doc.variants.length; index++) {
    final GlossChannelVariant variant = doc.variants[index];
    final String path = '\$.variants[$index]';
    if (variant.id.trim().isEmpty || !ids.add(variant.id)) {
      error('$path.id', 'Use a unique, nonempty variant id.');
    }
    if (variant.when.trim().isEmpty) {
      error('$path.when', 'A variant requires a condition.');
    }
    issues.addAll(validateGlossShow(variant.when, path: '$path.when'));
    for (final HuiIssue issue in validateChannelDoc(variant.apply(doc))) {
      issues.add(
        HuiIssue(
          severity: issue.severity,
          path: '$path${issue.path.substring(1)}',
          message: issue.message,
        ),
      );
    }
  }
  if (doc.card.length > 16) {
    error(r'$.card', 'A hover card supports at most 16 lines.');
  }
  final GlossChannelFiltering filtering =
      doc.filtering ?? GlossChannelFiltering();
  final Map<String, Object?> policy = filtering.toJson();
  const Map<String, (int, int)> ranges = <String, (int, int)>{
    'maxInputCharacters': (1, 32768),
    'maxOutputCharacters': (1, 262144),
    'maxPatternCharacters': (1, 4096),
    'maxReplacementCharacters': (0, 16384),
    'maxFilters': (0, 256),
    'maxMatches': (1, 65536),
    'maxProgramSize': (16, 1000000),
    'maxNestingDepth': (1, 128),
    'maxWorkUnits': (1, 100000000),
    'budgetMicros': (1, 100000),
  };
  for (final MapEntry<String, (int, int)> entry in ranges.entries) {
    final int value = policy[entry.key]! as int;
    if (value < entry.value.$1 || value > entry.value.$2) {
      error(
        '\$.filtering.${entry.key}',
        'Enter a value within ${entry.value.$1}..${entry.value.$2}.',
      );
    }
  }
  if (filtering.syntax != 're2') {
    error(r'$.filtering.syntax', 'Pattern syntax must be re2.');
  }
  if (!const <String>['drop', 'keep-completed'].contains(filtering.onLimit)) {
    error(r'$.filtering.onLimit', 'Choose drop or keep-completed.');
  }
  if (doc.filters.length > filtering.maxFilters || doc.filters.length > 256) {
    error(
      r'$.filters',
      'The filter count exceeds filtering.maxFilters or the 256 entry maximum.',
    );
  }
  for (int index = 0; index < doc.filters.length; index++) {
    final GlossChannelFilter filter = doc.filters[index];
    if (filter.match.length > filtering.maxPatternCharacters) {
      error(
        '\$.filters[$index].match',
        'Pattern exceeds filtering.maxPatternCharacters.',
      );
    }
    if (filter.replace.length > filtering.maxReplacementCharacters) {
      error(
        '\$.filters[$index].replace',
        'Replacement exceeds filtering.maxReplacementCharacters.',
      );
    }
    if (filter.match.trim().isEmpty) {
      error('\$.filters[$index].match', 'A filter requires a match pattern.');
    }
  }
  if (issues.isEmpty && doc.filters.isNotEmpty) {
    final String? syntax = validateChannelFilterSyntax(doc);
    if (syntax != null) error(r'$.filters', syntax);
  }
  return issues;
}
