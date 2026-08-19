/// Deterministic chat-bubble preview timeline for the bubble surface.
///
/// Editor presentation over plugin math: the SCHEDULE (a canned three-message
/// chat replayed on a loop) is editor fiction, but everything positional runs
/// through the ported plugin code — `BubbleLines.split` for wrapping,
/// `lineStaggerTicks * 50 ms` per line for spawn delay
/// (`ChatBubblesService.onChat` schedules line N at
/// `lineStaggerTicks * N` ticks), `maxAliveMs` for lifetime, and
/// `BubbleStackMath.offsetY` with the live list built exactly like
/// `SenderState.live` (spawn order, expired records removed).
///
/// Everything takes `nowMs` explicitly: the caller owns the clock, tests
/// inject one, and the same millisecond always shows the same stack.
library;

import '../model/gloss_bubble_style.dart';
import 'bubble_lines.dart';
import 'bubble_stack_math.dart';

const List<String> glossBubblePreviewMessages = <String>[
  'Magic_Psycho: Important server news: SwiftSwamp smells >.< and I have gathered extremely scientific evidence.',
  'SwiftSwamp: I reject this allegation. That was clearly Cyberpwn testing a suspicious new particle effect nearby.',
  'Cyberpwn: The profiler says the smell started exactly when SwiftSwamp joined, but correlation is not causation.',
  'Puretie: I brought soap, flowers, and a written incident report. We can settle this responsibly at spawn.',
  'Magic_Psycho: Great. Meeting in five minutes; bring screenshots, snacks, and the animated rainbow evidence.',
  'SwiftSwamp: Fine, but when I prove it was the swamp biome, everyone owes me diamonds and a public apology.',
];

/// Gap between canned messages. Editor fiction: a believable chat rhythm.
const int glossBubblePreviewMessageGapMs = 1800;

/// One bubble to draw: its stripped, wrapped text and its lift above the
/// anchor at the requested instant.
final class GlossBubblePreviewBubble {
  const GlossBubblePreviewBubble({
    required this.text,
    required this.offsetY,
    required this.remainingMs,
  });

  final String text;

  /// `BubbleStackMath.offsetY` — blocks above the anchor (eye + style
  /// offset).
  final double offsetY;

  final int remainingMs;
}

/// The timeline: spawn instants for every line of the looped conversation,
/// derived once per style revision.
final class GlossBubblePreviewTimeline {
  GlossBubblePreviewTimeline(GlossBubbleStyleDoc style, {double? spread})
    : _spread = spread ?? glossBubbleDefaultStackSpread,
      _maxAliveMs = style.effectiveMaxAliveMs,
      _flyAway = style.flyAway {
    final int staggerMs = style.effectiveLineStaggerTicks * 50;
    int cursor = 0;
    for (final String message in glossBubblePreviewMessages) {
      final List<String> lines = glossBubbleSplit(
        message,
        style.effectiveWordWrapChars,
      );
      for (int index = 0; index < lines.length; index++) {
        _spawns.add((at: cursor + index * staggerMs, text: lines[index]));
      }
      cursor += glossBubblePreviewMessageGapMs;
    }
    // The loop restarts once the last line has fully expired, plus a beat of
    // quiet so the stack visibly clears.
    int lastExpiry = 0;
    for (final ({int at, String text}) spawn in _spawns) {
      final int expiry = spawn.at + _maxAliveMs;
      if (expiry > lastExpiry) lastExpiry = expiry;
    }
    _periodMs = lastExpiry + 1000;
  }

  final List<({int at, String text})> _spawns = <({int at, String text})>[];
  final double _spread;
  final int _maxAliveMs;
  final bool _flyAway;
  late final int _periodMs;

  /// The loop length in milliseconds.
  int get periodMs => _periodMs;

  /// The live stack at [nowMs], oldest first — the order
  /// `SenderState.live` holds records in, which is what gives older bubbles
  /// the higher stack offsets.
  List<GlossBubblePreviewBubble> bubblesAt(int nowMs) {
    final int cycle = _periodMs <= 0 ? 0 : nowMs % _periodMs;
    final List<({int at, String text})> live = <({int at, String text})>[
      for (final ({int at, String text}) spawn in _spawns)
        if (cycle >= spawn.at && cycle < spawn.at + _maxAliveMs) spawn,
    ];
    final int liveCount = live.length;
    return <GlossBubblePreviewBubble>[
      for (int index = 0; index < liveCount; index++)
        GlossBubblePreviewBubble(
          text: live[index].text,
          remainingMs: live[index].at + _maxAliveMs - cycle,
          offsetY: glossBubbleOffsetY(
            _spread,
            index,
            liveCount,
            live[index].at + _maxAliveMs - cycle,
            flyAwayEnabled: _flyAway,
          ),
        ),
    ];
  }
}
