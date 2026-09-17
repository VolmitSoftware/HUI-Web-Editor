/// Validation for Gloss MOTD documents.
///
/// Errors are what `MotdDoc.java` rejects at parse: the revision range, a
/// document without entries, an entry whose line count is outside
/// 1..`MAX_LINES_PER_ENTRY` (`MotdDoc.java:20-37`), a sample past
/// `MAX_SAMPLE_LINES`, a link list past `MAX_LINKS`, and a link whose type,
/// label or url the `MotdLink` constructor refuses. The rest is what a ping
/// actually shows: `MotdService.handlePing` renders through `renderStatic`,
/// so `|animation.<id>|` references play (warn when dangling) while
/// PlaceholderAPI tokens stay literal — a ping has no viewer to expand them
/// for (`TextPipeline.render`: the placeholder stage requires a non-null
/// viewer).
library;

import '../model/gloss_doc.dart';
import '../model/gloss_motd.dart';
import 'gloss_text.dart';
import 'validation.dart';
import 'gloss_show.dart';

/// The vanilla server list truncates rows client-side around this many
/// visible characters; longer lines risk an ellipsis. Client behavior, not a
/// plugin limit.
const int glossMotdMaxVisibleLineLength = 45;

/// `TextPipeline.classify`: a `|` or a `{{` marks text the pipeline rewrites
/// before anything reads it, so a count carrying either is judged by the
/// server at ping time rather than here.
bool glossMotdIsTemplate(String raw) => raw.contains('|') || raw.contains('{{');

/// The characters `new URI(...)` refuses outright, which is where
/// `MotdLink.normalizeUrl` fails before it ever looks at the scheme.
final RegExp _illegalUriCharacters = RegExp(r'[\s<>"{}|\\^`]');

List<HuiIssue> validateMotdDoc(
  GlossMotdDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  Set<String>? knownImagePaths,
}) {
  final List<HuiIssue> issues = <HuiIssue>[
    ...validateGlossShow(doc.extras['show']),
  ];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
  }

  issues.addAll(_faviconIssues(doc.favicon, r'$.favicon', knownImagePaths));

  if (doc.entries.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.entries',
        message:
            'The document has no entries; Gloss rejects a MOTD without at '
            'least one.',
        fix: 'Add an entry with one or two lines.',
      ),
    );
  }

  for (int index = 0; index < doc.entries.length; index++) {
    final GlossMotdEntry entry = doc.entries[index];
    final String path = 'entries[$index]';
    issues.addAll(
      _faviconIssues(entry.favicon, '$path.favicon', knownImagePaths),
    );
    if (entry.lines.isEmpty || entry.lines.length > glossMotdMaxLinesPerEntry) {
      if (entry.lines.isEmpty) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.error,
            path: '$path.lines',
            message:
                'This entry has no lines; Gloss rejects the whole file — an '
                'entry needs 1 to {maximum}.',
            messageArguments: <String, Object?>{
              'maximum': glossMotdMaxLinesPerEntry,
            },
            fix: 'Give the entry one or two lines.',
          ),
        );
      } else {
        issues.add(
          HuiIssue.plural(
            severity: HuiSeverity.error,
            path: '$path.lines',
            pluralKey: 'validation.motd.entry_line_count',
            count: entry.lines.length,
            oneEnglish:
                'This entry has {count} line; Gloss rejects the whole file past {maximum}.',
            otherEnglish:
                'This entry has {count} lines; Gloss rejects the whole file past {maximum}.',
            messageArguments: <String, Object?>{
              'maximum': glossMotdMaxLinesPerEntry,
            },
            fix: 'Give the entry one or two lines.',
          ),
        );
      }
    }
    for (int line = 0; line < entry.lines.length; line++) {
      final String text = entry.lines[line];
      final String linePath = '$path.lines[$line]';
      final int visible = glossLineMaxVisibleLength(text, animations);
      if (visible > glossMotdMaxVisibleLineLength) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.warning,
            path: linePath,
            message:
                "This line shows {visible} visible characters; the vanilla server list clips rows around {glossMotdMaxVisibleLineLength}.",
            messageArguments: <String, Object?>{
              'visible': visible,
              'glossMotdMaxVisibleLineLength': glossMotdMaxVisibleLineLength,
            },
            fix: 'Shorten the line.',
          ),
        );
      }
      for (final String reference in glossLineMissingAnimationRefs(
        text,
        animations,
      )) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.warning,
            path: linePath,
            message:
                "|{reference}| names an animation document this workspace does not have; the text will show literally in the server list.",
            messageArguments: <String, Object?>{'reference': reference},
            fix:
                'Create the animation document or pick an existing one from '
                'the reference picker.',
          ),
        );
      }
      final List<String> placeholders = renderGlossLine(
        text,
        animations: animations,
      ).placeholders;
      if (placeholders.isNotEmpty) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.info,
            path: linePath,
            message:
                "{join} will stay literal: a server-list ping has no viewer, so PlaceholderAPI never runs for a MOTD.",
            messageArguments: <String, Object?>{
              'join': placeholders.join(', '),
            },
            fix: 'Remove the placeholder or accept the literal text.',
          ),
        );
      }
    }
    if (entry.sample.length > glossMotdMaxSampleLines) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.sample',
          message:
              'This entry lists {count} hover lines; Gloss rejects the whole '
              'file past {maximum}.',
          messageArguments: <String, Object?>{
            'count': entry.sample.length,
            'maximum': glossMotdMaxSampleLines,
          },
          fix: 'Remove the extra lines.',
        ),
      );
    }
    _countIssues(entry.online, '$path.online', issues);
    _countIssues(entry.max, '$path.max', issues);
  }

  _linkIssues(doc.links, issues);

  final HuiIssue? metrics = glossMetricInfo(<String>[
    for (final GlossMotdEntry entry in doc.entries) ...<String>[
      ...entry.lines,
      ...entry.sample,
      ?entry.online,
      ?entry.max,
      ?entry.version,
    ],
    for (final GlossMotdLink link in doc.links) ?link.label,
  ]);
  if (metrics != null) issues.add(metrics);
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      for (
        int entry = 0;
        entry < doc.entries.length;
        entry++
      ) ...<({String path, String text})>[
        for (int line = 0; line < doc.entries[entry].lines.length; line++)
          (
            path: 'entries[$entry].lines[$line]',
            text: doc.entries[entry].lines[line],
          ),
        for (int line = 0; line < doc.entries[entry].sample.length; line++)
          (
            path: 'entries[$entry].sample[$line]',
            text: doc.entries[entry].sample[line],
          ),
        for (final (String key, String? text) in <(String, String?)>[
          ('online', doc.entries[entry].online),
          ('max', doc.entries[entry].max),
          ('version', doc.entries[entry].version),
        ])
          if (text != null) (path: 'entries[$entry].$key', text: text),
      ],
      for (int link = 0; link < doc.links.length; link++)
        if (doc.links[link].label != null)
          (path: 'links[$link].label', text: doc.links[link].label!),
    ], playerBacked: false),
  );

  return issues;
}

/// `MotdService.number` renders the count and parses the result. A literal
/// that is not already a number can only fail, so it is reported here; a
/// template is the server's to render, and a blank is simply no count.
void _countIssues(String? raw, String path, List<HuiIssue> issues) {
  if (raw == null || raw.trim().isEmpty) return;
  if (glossMotdIsTemplate(raw)) return;
  if (double.tryParse(raw.trim()) != null) return;
  issues.add(
    HuiIssue(
      severity: HuiSeverity.error,
      path: path,
      message:
          'The count "{value}" does not render to a number, so the ping '
          'reports the server\'s own figure and the console warns once.',
      messageArguments: <String, Object?>{'value': raw},
      fix: 'Write a plain number, or an expression that renders to one.',
    ),
  );
}

/// `MotdDoc.copyLinks` and the `MotdLink` constructor: every one of these
/// throws at parse, so a document that trips one does not load at all.
void _linkIssues(List<GlossMotdLink> links, List<HuiIssue> issues) {
  if (links.length > glossMotdMaxLinks) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.links',
        message:
            'This document declares {count} server links; Gloss rejects the '
            'whole file past {maximum}.',
        messageArguments: <String, Object?>{
          'count': links.length,
          'maximum': glossMotdMaxLinks,
        },
        fix: 'Remove the extra links.',
      ),
    );
  }

  for (int index = 0; index < links.length; index++) {
    final GlossMotdLink link = links[index];
    final String path = 'links[$index]';
    final String type = link.type?.trim() ?? '';
    final String label = link.label?.trim() ?? '';
    if (type.isNotEmpty && !glossMotdLinkTypes.contains(type)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.type',
          message:
              'Link type "{type}" is not one of {allowed}; Gloss rejects the '
              'whole file.',
          messageArguments: <String, Object?>{
            'type': type,
            'allowed': glossMotdLinkTypes.join(', '),
          },
          fix: 'Pick a known type, or clear it and give the link a label.',
        ),
      );
    } else if (type.isEmpty && label.isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: path,
          message:
              'This link has neither a known type nor a label; Gloss rejects '
              'the whole file.',
          messageArguments: <String, Object?>{},
          fix: 'Pick a type the client already labels, or write a label.',
        ),
      );
    }
    _linkUrlIssues(link.url, '$path.url', issues);
  }
}

void _linkUrlIssues(String url, String path, List<HuiIssue> issues) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message: 'This link has no url; Gloss rejects the whole file.',
        fix: 'Give the link an http or https address.',
      ),
    );
    return;
  }
  final Uri? parsed = _illegalUriCharacters.hasMatch(trimmed)
      ? null
      : Uri.tryParse(trimmed);
  if (parsed == null) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'The url "{url}" is not a valid address; Gloss rejects the whole '
            'file.',
        messageArguments: <String, Object?>{'url': url},
        fix: 'Remove the spaces or illegal characters from the address.',
      ),
    );
    return;
  }
  final String scheme = parsed.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || parsed.host.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'The url "{url}" is not an http or https address with a host; '
            'Gloss rejects the whole file.',
        messageArguments: <String, Object?>{'url': url},
        fix: 'Write the full address, such as https://example.net.',
      ),
    );
  }
}

/// A favicon is optional at both levels — blank or missing keeps the icon the
/// level above supplies (`FaviconCache.iconFor` returns null for a blank
/// path) — so only a named file is measured, and against the same image-folder
/// rules every other image path follows.
///
/// `FaviconCache.decode` reads the format out of the bytes, not the name, so
/// the extension is a warning rather than an error: it is the one part of the
/// PNG rule a path can show. The 64x64 half is a property of the file alone
/// and stays out of here.
List<HuiIssue> _faviconIssues(
  String? favicon,
  String path,
  Set<String>? knownImagePaths,
) {
  if (favicon == null || favicon.trim().isEmpty) return const <HuiIssue>[];
  return <HuiIssue>[
    ...glossImagePathIssues(
      favicon,
      path,
      knownImagePaths: knownImagePaths,
      blankIsEmptyError: false,
    ),
    if (!favicon.trim().toLowerCase().endsWith('.png'))
      HuiIssue(
        severity: HuiSeverity.warning,
        path: path,
        message:
            'The server refuses a server-list icon that is not a PNG file, '
            'and "{favicon}" does not name one.',
        messageArguments: <String, Object?>{'favicon': favicon},
        fix: 'Point the field at a 64x64 PNG.',
      ),
  ];
}
