library;

import '../model/gloss_bubble_style.dart';
import 'bubble_lines.dart';
import 'bubble_motion.dart';
import 'bubble_shimmer.dart';
import 'bubble_stack_math.dart';
import 'preview_expr.dart';

const List<String> glossBubblePreviewMessages = <String>[
  '§1Magic_Psycho: §7Important server news: §dSwiftSwamp smells >.< §7and I have gathered extremely scientific evidence.',
  '§bSwiftSwamp: §7I reject this allegation. That was clearly §5Cyberpwn §7testing a suspicious new particle effect nearby.',
  '§5Cyberpwn: §7The profiler says the smell started exactly when §bSwiftSwamp §7joined, but correlation is not causation.',
  '§6Puretie: §7I brought soap, flowers, and a written incident report. We can settle this responsibly at spawn.',
  '§1Magic_Psycho: §7Great. Meeting in five minutes; bring screenshots, snacks, and the animated rainbow evidence.',
  '§bSwiftSwamp: §7Fine, but when I prove it was the swamp biome, everyone owes me diamonds and a public apology.',
];

const int glossBubblePreviewMessageGapMs = 1800;

final class GlossBubblePreviewBubble {
  const GlossBubblePreviewBubble({
    required this.text,
    required this.lineCount,
    required this.stackY,
    required this.remainingMs,
    required this.motion,
    required this.shimmerHead,
  });

  final String text;
  final int lineCount;
  final double stackY;
  final int remainingMs;
  final GlossBubbleMotionFrame motion;

  /// The shine band head in visible glyphs, or null while no cycle runs. Free
  /// running: once a cycle starts this keeps climbing past the end of the text.
  final int? shimmerHead;
}

final class GlossBubblePreviewTimeline {
  GlossBubblePreviewTimeline(GlossBubbleStyleDoc style, {double? spread})
    : _spread = spread ?? glossBubbleDefaultStackSpread,
      _maxAliveMs = style.effectiveMaxAliveMs,
      _motion = _compileMotion(style.motion),
      _shimmer = style.shimmer.copy() {
    int cursor = 0;
    int sequence = 0;
    for (final String message in glossBubblePreviewMessages) {
      final String text = glossBubbleWrap(
        message,
        style.effectiveWordWrapChars,
      );
      final int lineCount = glossBubbleWrappedLineCount(text);
      if (lineCount > 0) {
        _spawns.add((
          at: cursor,
          text: text,
          lineCount: lineCount,
          seed: _previewSeed(text, sequence),
        ));
        sequence++;
      }
      cursor += glossBubblePreviewMessageGapMs;
    }
    int lastExpiry = 0;
    for (final _BubbleSpawn spawn in _spawns) {
      final int expiry = spawn.at + _maxAliveMs;
      if (expiry > lastExpiry) lastExpiry = expiry;
    }
    _periodMs = lastExpiry + 1000;
  }

  final List<_BubbleSpawn> _spawns = <_BubbleSpawn>[];
  final double _spread;
  final int _maxAliveMs;
  final GlossBubbleMotionProgram? _motion;
  final GlossBubbleShimmer _shimmer;
  late final int _periodMs;

  int get periodMs => _periodMs;

  List<GlossBubblePreviewBubble> bubblesAt(int nowMs) {
    final int cycle = _periodMs <= 0 ? 0 : nowMs % _periodMs;
    final List<_BubbleSpawn> live = <_BubbleSpawn>[
      for (final _BubbleSpawn spawn in _spawns)
        if (cycle >= spawn.at && cycle < spawn.at + _maxAliveMs) spawn,
    ];
    final List<int> lineCounts = <int>[
      for (final _BubbleSpawn spawn in live) spawn.lineCount,
    ];
    final int liveCount = live.length;
    return <GlossBubblePreviewBubble>[
      for (int index = 0; index < liveCount; index++)
        _bubbleAt(live[index], index, lineCounts, cycle),
    ];
  }

  GlossBubblePreviewBubble _bubbleAt(
    _BubbleSpawn spawn,
    int index,
    List<int> lineCounts,
    int cycle,
  ) {
    final int ageMs = cycle - spawn.at;
    final int remainingMs = _maxAliveMs - ageMs;
    final double stackY = glossBubbleStackY(_spread, index, lineCounts);
    final double t = _maxAliveMs <= 0
        ? 1.0
        : (ageMs / _maxAliveMs).clamp(0.0, 1.0).toDouble();
    GlossBubbleMotionFrame frame = const GlossBubbleMotionFrame.identity();
    final GlossBubbleMotionProgram? program = _motion;
    if (program != null) {
      try {
        frame = program.evaluate(
          GlossBubbleMotionContext(
            t: t,
            ageMs: ageMs.toDouble(),
            lifetimeMs: _maxAliveMs.toDouble(),
            stackIndex: index.toDouble(),
            stackCount: lineCounts.length.toDouble(),
            lineCount: spawn.lineCount.toDouble(),
            stackY: stackY,
            seed: spawn.seed,
          ),
        );
      } on PExprException {
        frame = const GlossBubbleMotionFrame.identity();
      }
    }
    return GlossBubblePreviewBubble(
      text: spawn.text,
      lineCount: spawn.lineCount,
      stackY: stackY,
      remainingMs: remainingMs,
      motion: frame,
      shimmerHead: glossBubbleShimmerHead(
        _shimmer,
        ageMs: ageMs,
        lifetimeMs: _maxAliveMs,
      ),
    );
  }

  static GlossBubbleMotionProgram? _compileMotion(GlossBubbleMotion motion) {
    try {
      return GlossBubbleMotionProgram.compile(motion);
    } on PExprException {
      return null;
    }
  }
}

typedef _BubbleSpawn = ({int at, String text, int lineCount, double seed});

double _previewSeed(String text, int sequence) {
  int hash = 0x811C9DC5 ^ sequence;
  for (final int unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash / 0xFFFFFFFF;
}
