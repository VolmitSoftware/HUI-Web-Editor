/// Mirror of Gloss `BubbleStackMath.java` — where a chat bubble sits above
/// the sender's eyes, exactly as the plugin computes it every position poll.
///
/// `ChatBubblesService.bubblePosition` feeds it: `spread` is the hologram
/// stack distance (config `holograms.stackDistance`, default 0.26, clamped
/// 0.05..2.0), `lineIndex` is the bubble's index in the sender's live list,
/// `liveCount` the list size, `remainingMs` the bubble's time left of
/// `maxAliveMs`. The result is the Y lift added to the anchor (the captured
/// or followed eye location plus the style offset).
///
/// `test/fixtures/bubble_stack_vectors.json` replays these functions over a
/// deterministic grid to 1e-9; the twin Java test on the Gloss side pins the
/// same vectors — IEEE double pow implementations differ by ulps at most,
/// far inside that tolerance.
library;

import 'dart:math' as math;

/// `BubbleStackMath.BASE_LIFT`.
const double glossBubbleBaseLift = 0.86;

/// `BubbleStackMath.FLY_AWAY_WINDOW_MS` — the easing starts this long
/// before expiry.
const int glossBubbleFlyAwayWindowMs = 2000;

/// `BubbleStackMath.FLY_AWAY_EXPONENT`.
const double glossBubbleFlyAwayExponent = 16;

/// `BubbleStackMath.FLY_AWAY_HEIGHT` — blocks risen at the instant of
/// expiry.
const double glossBubbleFlyAwayHeight = 10;

/// `GlossConfigFile.Holograms.stackDistance` default — what a stock server
/// feeds in as `spread`.
const double glossBubbleDefaultStackSpread = 0.26;

/// `BubbleStackMath.stackOffset`: newer bubbles push older ones up; never
/// negative.
double glossBubbleStackOffset(double spread, int lineIndex, int liveCount) {
  final double offset = spread * (liveCount - lineIndex);
  return offset > 0 ? offset : 0;
}

/// `BubbleStackMath.flyAway`: zero until the last
/// [glossBubbleFlyAwayWindowMs], then `(1 - remaining/window)^16 * 10` — a
/// sharp late launch.
double glossBubbleFlyAway(int remainingMs) {
  if (remainingMs >= glossBubbleFlyAwayWindowMs) return 0;
  final int remaining = remainingMs > 0 ? remainingMs : 0;
  final double eased = math
      .pow(
        1.0 - (remaining / glossBubbleFlyAwayWindowMs),
        glossBubbleFlyAwayExponent,
      )
      .toDouble();
  return eased * glossBubbleFlyAwayHeight;
}

/// `BubbleStackMath.offsetY`: base lift + stack offset + fly-away easing.
double glossBubbleOffsetY(
  double spread,
  int lineIndex,
  int liveCount,
  int remainingMs, {
  required bool flyAwayEnabled,
}) {
  final double flyLift = flyAwayEnabled ? glossBubbleFlyAway(remainingMs) : 0;
  return glossBubbleBaseLift +
      glossBubbleStackOffset(spread, lineIndex, liveCount) +
      flyLift;
}
