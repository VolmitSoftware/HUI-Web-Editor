library;

import '../model/gloss_channel.dart';
import '../model/gloss_doc.dart';
import 'gloss_show.dart';
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
  return issues;
}
