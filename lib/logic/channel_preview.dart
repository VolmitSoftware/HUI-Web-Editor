library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_channel.dart';
import '../model/gloss_names.dart';
import '../model/preview_doc.dart';
import 'gloss_show.dart';
import 'gloss_text.dart';
import 'preview_expr.dart';

final class ChannelPreview {
  const ChannelPreview({
    required this.render,
    required this.mentioned,
    required this.visible,
    required this.hoverText,
  });
  final GlossLineRender render;
  final bool mentioned;
  final bool visible;
  final String hoverText;
  String get text => render.renderedText;
}

ChannelPreview channelPreview(
  GlossChannelDoc doc, {
  required String message,
  String sender = 'Alex',
  String viewer = 'Steve',
  String senderGroup = 'member',
  GlossNamesCatalog names = const GlossNamesCatalog(),
  bool allowed = true,
  Set<String> senderPermissions = const <String>{},
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final Map<String, Object> values = <String, Object>{
    ...glossScopedSampleValues,
    'sender.name': sender,
    'sender.username': sender,
    'sender.group': senderGroup,
    'sender.groupName': names.name(GlossNameCategory.groups, senderGroup),
    'sender.worldName': names.name(GlossNameCategory.worlds, 'world'),
    'sender.world': 'world',
    'source.name': sender,
    'viewer.name': viewer,
    'viewer.username': viewer,
    'channel.name': doc.channel.name,
    'channel.id': doc.channel.name,
  };
  final _ChannelScope scope = _ChannelScope(
    GlossConditionContext(
      variables: values,
      permissionsByRole: <String, Set<String>>{'source': senderPermissions},
      groupsByRole: <String, Set<String>>{
        'source': <String>{senderGroup},
      },
    ),
  );
  final bool visible = _matches(doc.show, scope);
  final List<String> literals = <String>[];
  String literal(String value) {
    final int index = literals.length;
    literals.add(value);
    return '\uFDD0$index\uFDD1';
  }

  final String pattern = doc.mentions.pattern;
  final int token = pattern.indexOf('{name}');
  bool mentioned = false;
  String body = '';
  if (visible && doc.mentions.enabled && allowed && token >= 0) {
    final RegExp scanner = RegExp(
      r'https?://[^\s<>]+|www\.[^\s<>]+|(^|[^A-Za-z0-9_@])' +
          RegExp.escape(pattern.substring(0, token)) +
          r'([A-Za-z0-9_]{1,16})' +
          RegExp.escape(pattern.substring(token + 6)) +
          r'(?![A-Za-z0-9_])',
    );
    int cursor = 0;
    final StringBuffer output = StringBuffer();
    for (final RegExpMatch match in scanner.allMatches(message)) {
      if (match.group(2)?.toLowerCase() != viewer.toLowerCase()) continue;
      output.write(
        literal(message.substring(cursor, match.start) + match.group(1)!),
      );
      output.write(
        doc.mentions.render.replaceAll(
          RegExp(r'\{\{\s*mention\.(name|username)\s*\}\}'),
          match.group(2)!,
        ),
      );
      mentioned = true;
      cursor = match.end;
    }
    output.write(literal(message.substring(cursor)));
    body = output.toString();
  } else {
    body = literal(message);
  }
  final String format = mentioned
      ? doc.mentions.messageFormat
      : _format(doc, scope);
  final GlossTextExpressionSamples samples = GlossTextExpressionSamples(
    values: values,
    names: names,
  );
  final String card = doc.card.join('<newline>');
  final String hoverText = renderGlossLine(
    card,
    richText: true,
    expressionSamples: samples,
    animations: animations,
    emoji: emoji,
  ).plainText;
  final String prepared = _withoutInteractions(format)
      .replaceAll(RegExp(r'\{\{\s*message\s*\}\}'), body)
      .replaceAll(RegExp(r'\{\{\s*card\s*\}\}'), card);
  final GlossLineRender parsed = renderGlossLine(
    visible ? prepared : '',
    richText: true,
    expressionSamples: samples,
    animations: animations,
    emoji: emoji,
  );
  String restore(String source) => source.replaceAllMapped(
    RegExp('\uFDD0(\\d+)\uFDD1'),
    (Match match) => literals[int.parse(match.group(1)!)],
  );
  final GlossLineRender render = GlossLineRender(
    pieces: <GlossTextPiece>[
      for (final GlossTextPiece piece in parsed.pieces)
        if (piece is GlossTextRun)
          GlossTextRun(piece.span.withText(restore(piece.span.text)))
        else
          piece,
    ],
    usedAnimations: parsed.usedAnimations,
    missingAnimations: parsed.missingAnimations,
    placeholders: parsed.placeholders,
    metrics: parsed.metrics,
    expressions: parsed.expressions,
    expressionErrors: parsed.expressionErrors,
    renderedText: restore(parsed.renderedText),
    particleSpans: parsed.particleSpans,
    particleSpanError: parsed.particleSpanError,
  );
  return ChannelPreview(
    render: render,
    mentioned: mentioned,
    visible: visible,
    hoverText: hoverText,
  );
}

bool _matches(Object? raw, _ChannelScope scope) {
  if (raw == null) return true;
  if (raw is bool) return raw;
  if (raw is! String) return false;
  try {
    final Object? condition = previewShowExpression(raw);
    if (condition == null) return true;
    if (condition is bool) return condition;
    return evalBool(parsePreviewExpr(condition as String), scope);
  } on PExprException {
    return false;
  }
}

String _format(GlossChannelDoc doc, _ChannelScope scope) {
  final Object? raw = doc.extras['variants'];
  if (raw is! List) return doc.format;
  final List<Map<String, Object?>> variants =
      <Map<String, Object?>>[
        for (final Object? value in raw)
          if (value is Map<String, Object?> &&
              value['when'] is String &&
              value['format'] is String)
            value,
      ]..sort((Map<String, Object?> first, Map<String, Object?> second) {
        final int priority =
            (second['priority'] is num ? second['priority']! as num : 0)
                .compareTo(
                  first['priority'] is num ? first['priority']! as num : 0,
                );
        return priority != 0
            ? priority
            : '${first['id']}'.compareTo('${second['id']}');
      });
  for (final Map<String, Object?> variant in variants) {
    if (_matches(variant['when'], scope)) {
      return variant['format']! as String;
    }
  }
  return doc.format;
}

String _withoutInteractions(String source) => source.replaceAll(
  RegExp(
    r'''<(?:hover|click):(?:'[^']*'|"[^"]*"|[^>'"])*>|</(?:hover|click)>''',
    caseSensitive: false,
  ),
  '',
);

final class _ChannelScope extends PExprScope {
  _ChannelScope(this.delegate);
  final GlossConditionContext delegate;
  @override
  Object? variable(String name) => delegate.variable(name);
  @override
  Object? call(String name, List<Object?> args) => delegate.call(
    name,
    args.isNotEmpty && args.first == 'sender'
        ? <Object?>['source', ...args.skip(1)]
        : args,
  );
}
