/// What a server-list ping carries besides the MOTD line, resolved the way
/// `MotdService` resolves it.
///
/// `applyExtras` sends four things past the text: the icon (`motd_view`'s own
/// slot), the player counts, the hover sample and the version label. The
/// counts go through `renderStatic` first, so they are
/// authored text like everything else — which is why they are computed here,
/// DOM-free, rather than inside the preview component.
///
/// The server edition splits along Paper: `max` is plain Bukkit
/// (`event.setMaxPlayers`), while the sample, the online count and the version
/// reach the client only through the Paper ping bridge. The preview assumes
/// Paper support and a compatible client; version text is not displayed.
library;

import 'dart:math';

import '../model/gloss_motd.dart';
import '../components/scoreboard/scoreboard_selection.dart';
import 'gloss_show.dart';
import 'motd_clock.dart';
import 'gloss_text.dart';

/// The player count the mock row falls back to, standing in for the figure a
/// real server reports. Cosmetic: the plugin never writes it.
const int glossMotdSampledOnline = 17;

/// The slot count behind the same fallback.
const int glossMotdSampledMax = 100;

/// `online/max` for the row's right-hand slot.
///
/// `MotdService.number` renders the authored text and parses the result; blank
/// or unparseable leaves the server's own figure alone, so the sampled count
/// stands in here for exactly the cases the ping would leave untouched.
String glossMotdPlayerCount(
  GlossMotdEntry? entry, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
  int realOnline = glossMotdSampledOnline,
  int realMaximum = glossMotdSampledMax,
  MotdPreviewPlatform platform = MotdPreviewPlatform.paper,
}) {
  final GlossTextExpressionSamples values = motdExpressionSamples(
    realOnline,
    realMaximum,
  );
  if (platform != MotdPreviewPlatform.spigot && entry?.counts?.hide == true) {
    return '???';
  }
  final int online = platform == MotdPreviewPlatform.spigot
      ? realOnline
      : _count(
          entry?.counts?.onlineMode,
          entry?.counts?.onlineValue,
          realOnline,
          _number(entry?.online, animations, emoji, nowMs, values),
        );
  final int max = _count(
    entry?.counts?.maximumMode,
    entry?.counts?.maximumValue,
    realMaximum,
    _number(entry?.max, animations, emoji, nowMs, values),
  );
  return '$online/$max';
}

/// The hover list under the count: the entry's own lines, still authored, cut
/// at `MotdDoc.MAX_SAMPLE_LINES` because a longer list never reaches a client
/// — the document does not load at all.
List<String> glossMotdSampleLines(
  GlossMotdEntry? entry, {
  List<String> original = const <String>[],
  MotdPreviewPlatform platform = MotdPreviewPlatform.paper,
}) {
  if (platform == MotdPreviewPlatform.spigot || entry == null) return original;
  if (entry.counts?.hide == true || entry.effectiveSampleMode == 'hide') {
    return const <String>[];
  }
  if (entry.effectiveSampleMode == 'inherit') return original;
  final List<String> sample = entry.sample;
  return sample.take(glossMotdMaxSampleLines).toList();
}

/// `MotdService.number`: render, then `(int) Double.parseDouble`. The render
/// keeps its colour codes, which is why `&a100` is not a number here either.
int? _number(
  String? raw,
  GlossAnimationResolver animations,
  GlossEmojiResolver emoji,
  int nowMs,
  GlossTextExpressionSamples samples,
) {
  if (raw == null || raw.trim().isEmpty) return null;
  final String rendered = renderGlossLine(
    raw,
    animations: animations,
    emoji: emoji,
    nowMs: nowMs,
    viewerAware: false,
    expressionSamples: samples,
  ).renderedText;
  if (rendered.trim().isEmpty) return null;
  final double? value = double.tryParse(rendered.trim());
  return value == null || !value.isFinite
      ? null
      : value.clamp(0, 2147483647).toInt();
}

int _count(String? mode, int? value, int original, int? rendered) =>
    switch (mode) {
      'fixed' => (value ?? 0).clamp(0, 2147483647),
      'offset' => (original + (value ?? 0)).clamp(0, 2147483647),
      _ => rendered ?? original,
    };

GlossTextExpressionSamples motdExpressionSamples(int online, int maximum) =>
    GlossTextExpressionSamples(
      values: <String, Object>{
        'server.online': online.toDouble(),
        'server.max': maximum.toDouble(),
        'server.maxPlayers': maximum.toDouble(),
      },
      placeholders: <String, Object>{
        'server_online': online.toDouble(),
        'server_max_players': maximum.toDouble(),
      },
    );

enum MotdPreviewPlatform { paper, spigot, velocity }

final class MotdPreviewRequest {
  const MotdPreviewRequest({
    required this.epochMillis,
    this.hostname = '',
    this.protocol,
    this.online = glossMotdSampledOnline,
    this.maximum = glossMotdSampledMax,
    this.state,
    this.platform = MotdPreviewPlatform.paper,
    this.motdEnabled = true,
  });
  final int epochMillis;
  final String hostname;
  final int? protocol;
  final int online;
  final int maximum;
  final String? state;
  final MotdPreviewPlatform platform;
  final bool motdEnabled;
  int? get effectiveProtocol =>
      platform == MotdPreviewPlatform.spigot ? null : protocol;
}

final class MotdPreviewResult {
  const MotdPreviewResult({
    required this.eligible,
    required this.selectedIndex,
    required this.icon,
    required this.links,
  });
  final List<int> eligible;
  final int? selectedIndex;
  final String? icon;
  final List<GlossMotdLink> links;
}

MotdPreviewResult simulateMotdRequest(
  GlossMotdDoc doc,
  MotdPreviewRequest request, {
  int sequence = 0,
  int randomSeed = 0,
}) {
  final List<int> eligible = <int>[];
  final GlossConditionContext scope = GlossConditionContext(
    variables: <String, Object?>{
      'server.online': request.online.toDouble(),
      'server.max': request.maximum.toDouble(),
      'server.maxPlayers': request.maximum.toDouble(),
    },
  );
  if (request.motdEnabled &&
      glossShowMatches(
        doc.extras['show'],
        scope: scope,
        nowMs: request.epochMillis,
        viewerAware: false,
      )) {
    for (int index = 0; index < doc.entries.length; index++) {
      final GlossMotdEntry entry = doc.entries[index];
      if (glossShowMatches(
            entry.show,
            scope: scope,
            nowMs: request.epochMillis,
            viewerAware: false,
          ) &&
          motdSelectorMatches(entry.select, request, doc.effectiveState)) {
        eligible.add(index);
      }
    }
  }
  final String mode = doc.rotation?.effectiveMode ?? 'weighted';
  final int interval = doc.rotation?.effectiveIntervalSeconds ?? 60;
  if (!const <String>{'weighted', 'sequence', 'time', 'first'}.contains(mode) ||
      interval < 1 ||
      interval > 86400) {
    throw const FormatException('Invalid rotation settings');
  }
  final int position = mode == 'time'
      ? (request.epochMillis / (interval * 1000)).floor()
      : mode == 'sequence'
      ? sequence
      : 0;
  final Random random = Random(randomSeed);
  int? selected;
  if (eligible.isNotEmpty) {
    if (mode == 'weighted') {
      int total = 0;
      for (final int index in eligible) {
        final int weight = doc.entries[index].weight;
        if (weight < 1 || weight > 1000000) {
          throw const FormatException('Invalid entry weight');
        }
        total += weight;
        if (random.nextInt(total) < weight) selected = index;
      }
    } else {
      selected = eligible[mode == 'first' ? 0 : position % eligible.length];
    }
  }
  final List<String> icons = selected == null
      ? const <String>[]
      : doc.iconsFor(doc.entries[selected]);
  final String? icon = icons.isEmpty
      ? null
      : icons[mode == 'weighted'
            ? random.nextInt(icons.length)
            : mode == 'first'
            ? 0
            : position % icons.length];
  return MotdPreviewResult(
    eligible: eligible,
    selectedIndex: selected,
    icon: icon,
    links: request.platform == MotdPreviewPlatform.spigot
        ? const <GlossMotdLink>[]
        : doc.enabledLinks(request.motdEnabled),
  );
}

bool motdSelectorMatches(
  GlossMotdSelector? selector,
  MotdPreviewRequest request,
  String documentState,
) {
  if (selector == null) return true;
  final int? protocol = request.effectiveProtocol;
  if ((selector.minProtocol != null || selector.maxProtocol != null) &&
      protocol == null) {
    return false;
  }
  if (selector.minProtocol != null && protocol! < selector.minProtocol! ||
      selector.maxProtocol != null && protocol! > selector.maxProtocol!) {
    return false;
  }
  String hostname = request.hostname.toLowerCase().split('\u0000').first;
  if (hostname.endsWith('.')) {
    hostname = hostname.substring(0, hostname.length - 1);
  }
  if (selector.hostnames?.isNotEmpty ?? false) {
    bool found = false;
    for (final String source in selector.hostnames!) {
      final String host = source.trim().toLowerCase();
      if (host.startsWith('*.')) {
        final String suffix = host.substring(1);
        if (hostname.endsWith(suffix) && hostname.length > suffix.length) {
          found = true;
        }
      } else if (hostname == host) {
        found = true;
      }
    }
    if (!found) return false;
  }
  if ((selector.states?.isNotEmpty ?? false) &&
      !selector.states!.contains(request.state ?? documentState)) {
    return false;
  }
  if (selector.minOnline != null && request.online < selector.minOnline! ||
      selector.maxOnline != null && request.online > selector.maxOnline!) {
    return false;
  }
  if ((selector.startTime == null) != (selector.endTime == null)) {
    throw const FormatException('Both clock bounds are required');
  }
  final DateTime local = motdZonedTime(
    selector.zone ?? 'UTC',
    request.epochMillis,
  );
  if ((selector.days?.isNotEmpty ?? false) &&
      !selector.days!.contains(local.weekday)) {
    return false;
  }
  if (selector.startTime == null) return true;
  final int? start = motdTimeNanos(selector.startTime!);
  final int? end = motdTimeNanos(selector.endTime!);
  if (start == null || end == null) {
    throw const FormatException('Invalid clock bounds');
  }
  final int time =
      (local.hour * 3600 + local.minute * 60 + local.second) * 1000000000 +
      local.millisecond * 1000000;
  return start == end ||
      (start < end ? time >= start && time < end : time >= start || time < end);
}
