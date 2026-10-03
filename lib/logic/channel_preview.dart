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
  final _ChannelScope sendingScope = _ChannelScope(
    GlossConditionContext(
      variables: <String, Object>{
        ...values,
        'viewer.name': sender,
        'viewer.username': sender,
      },
      permissionsByRole: <String, Set<String>>{'source': senderPermissions},
      groupsByRole: <String, Set<String>>{
        'source': <String>{senderGroup},
      },
    ),
  );
  final GlossChannelDoc sending = _selected(doc, sendingScope);
  for (final GlossChannelFilter filter in sending.filters) {
    try {
      message = message.replaceAllMapped(
        RegExp(filter.match),
        (Match match) => _filterReplacement(filter.replace, match),
      );
    } on FormatException {
      continue;
    }
  }
  doc = _selected(doc, scope);
  final List<String> literals = <String>[];
  String literal(String value) {
    final int index = literals.length;
    literals.add(value);
    return '\uFDD0$index\uFDD1';
  }

  final String pattern = doc.mentions.pattern;
  final int token = pattern.indexOf('{name}');
  final GlossChannelItems items = doc.items ?? GlossChannelItems();
  final GlossChannelLinks links = doc.links ?? GlossChannelLinks();
  final List<String> scans = <String>[
    r'(?<url>https?://[^\s<>]+|www\.[^\s<>]+)',
  ];
  final bool scanItems =
      visible && items.enabled && allowed && items.token.isNotEmpty;
  final bool scanMentions =
      visible && doc.mentions.enabled && allowed && token >= 0;
  if (scanItems) {
    scans.add('(?<item>${RegExp.escape(items.token)})');
  }
  if (scanMentions) {
    scans.add(
      r'(?<prefix>^|[^A-Za-z0-9_@])' +
          RegExp.escape(pattern.substring(0, token)) +
          r'(?<mention>[A-Za-z0-9_]{1,16})' +
          RegExp.escape(pattern.substring(token + 6)) +
          r'(?![A-Za-z0-9_])',
    );
  }
  bool mentioned = false;
  int cursor = 0;
  final StringBuffer output = StringBuffer();
  for (final RegExpMatch match in RegExp(scans.join('|')).allMatches(message)) {
    final String? mention = scanMentions ? match.namedGroup('mention') : null;
    final String? url = match.namedGroup('url');
    final String? item = scanItems ? match.namedGroup('item') : null;
    String? replacement;
    if (url != null && links.enabled) {
      final Uri? parsed = Uri.tryParse(
        url.startsWith('www.') ? 'https://$url' : url,
      );
      replacement = links.render
          .replaceAll(
            RegExp(r'\{\{\s*link\.host\s*\}\}'),
            literal(parsed?.host ?? url),
          )
          .replaceAll(RegExp(r'\{\{\s*link\.url\s*\}\}'), literal(url));
    } else if (item != null) {
      replacement = items.render;
      values.addAll(<String, Object>{
        'item.name': names.name(GlossNameCategory.materials, 'diamond'),
        'item.material': 'diamond',
        'item.materialName': names.name(GlossNameCategory.materials, 'diamond'),
        'item.count': 1.0,
        'item.amount': 1.0,
        'item.countSuffix': '',
      });
    } else if (mention?.toLowerCase() == viewer.toLowerCase()) {
      replacement =
          literal(match.namedGroup('prefix') ?? '') +
          doc.mentions.render.replaceAll(
            RegExp(r'\{\{\s*mention\.(name|username)\s*\}\}'),
            mention!,
          );
      mentioned = true;
    }
    if (replacement == null) continue;
    output.write(literal(message.substring(cursor, match.start)));
    output.write(replacement);
    cursor = match.end;
  }
  output.write(literal(message.substring(cursor)));
  final String body = output.toString();
  final String format = mentioned ? doc.mentions.messageFormat : doc.format;
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

String _filterReplacement(String replacement, Match match) {
  final StringBuffer result = StringBuffer();
  for (int index = 0; index < replacement.length; index++) {
    final String character = replacement[index];
    if (character == r'\') {
      if (++index >= replacement.length) {
        throw const FormatException();
      }
      result.write(replacement[index]);
    } else if (character == r'$') {
      if (++index >= replacement.length) {
        throw const FormatException();
      }
      if (replacement[index] == '{') {
        final int end = replacement.indexOf('}', index + 1);
        if (end < 0 || match is! RegExpMatch) {
          throw const FormatException();
        }
        final String name = replacement.substring(index + 1, end);
        if (!match.groupNames.contains(name)) throw const FormatException();
        result.write(match.namedGroup(name) ?? '');
        index = end;
      } else {
        final int? first = int.tryParse(replacement[index]);
        if (first == null || first > match.groupCount) {
          throw const FormatException();
        }
        int group = first;
        while (index + 1 < replacement.length) {
          final int? digit = int.tryParse(replacement[index + 1]);
          if (digit == null || group * 10 + digit > match.groupCount) break;
          group = group * 10 + digit;
          index++;
        }
        result.write(match.group(group) ?? '');
      }
    } else {
      result.write(character);
    }
  }
  return result.toString();
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

GlossChannelDoc _selected(GlossChannelDoc doc, _ChannelScope scope) {
  final List<GlossChannelVariant> variants =
      List<GlossChannelVariant>.of(doc.variants)
        ..sort((GlossChannelVariant first, GlossChannelVariant second) {
          final int priority = second.priority.compareTo(first.priority);
          return priority != 0 ? priority : first.id.compareTo(second.id);
        });
  for (final GlossChannelVariant variant in variants) {
    if (_matches(variant.when, scope)) return variant.apply(doc);
  }
  return doc;
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
