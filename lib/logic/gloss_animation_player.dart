/// Playback state for the animation surface: play, pause, scrub.
///
/// The plugin has no player — `AnimationClip.frameAt(M.ms())` is stateless
/// wall-clock math — so this controller exists purely for the editor: playing
/// mirrors the in-game clock exactly (the same millisecond shows the same
/// frame as the server), pausing freezes the frame that was showing, and
/// scrubbing addresses a frame directly. The clock is injected so tests drive
/// it deterministically.
library;

import '../model/gloss_animation.dart';
import 'gloss_animation_playback.dart';

int _wallClock() => DateTime.now().millisecondsSinceEpoch;

final class GlossAnimationPlayer {
  GlossAnimationPlayer({int Function()? clock}) : _clock = clock ?? _wallClock;

  final int Function() _clock;

  bool _playing = true;

  /// The frame frozen by [pause] or picked by [scrubTo]; meaningless while
  /// [playing].
  int _heldIndex = 0;
  int _heldNowMs = 0;

  bool get playing => _playing;

  int get nowMs => _playing ? _clock() : _heldNowMs;

  ({int nowMs, int frameIndex, String frameText}) sample(
    GlossAnimationDoc doc,
    String id,
  ) {
    final int sampledNowMs = nowMs;
    if (doc.frames.isEmpty) {
      return (nowMs: sampledNowMs, frameIndex: 0, frameText: '');
    }
    final int sampledIndex = _playing
        ? glossAnimationFrameIndexAt(doc, id, sampledNowMs)
        : _heldIndex.clamp(0, doc.frames.length - 1);
    return (
      nowMs: sampledNowMs,
      frameIndex: sampledIndex,
      frameText: doc.frames[sampledIndex],
    );
  }

  /// The frame [doc] shows right now under this player's state. Playing, it
  /// is the in-game answer for the injected clock's current millisecond;
  /// paused, it is the held frame clamped into the current frame list.
  int frameIndex(GlossAnimationDoc doc, String id) {
    return sample(doc, id).frameIndex;
  }

  String frameText(GlossAnimationDoc doc, String id) =>
      sample(doc, id).frameText;

  /// Freezes on whatever frame the clock shows at this instant.
  void pause(GlossAnimationDoc doc, String id) {
    if (!_playing) return;
    _heldNowMs = _clock();
    _heldIndex = glossAnimationFrameIndexAt(doc, id, _heldNowMs);
    _playing = false;
  }

  /// Resumes the wall clock. Deliberately NOT from the held frame: in game
  /// the clip position is the clock, so resuming rejoins the live timeline —
  /// exactly what the server would be showing.
  void play() => _playing = true;

  void toggle(GlossAnimationDoc doc, String id) =>
      _playing ? pause(doc, id) : play();

  /// Pauses (if needed) and shows frame [index].
  void scrubTo(int index, GlossAnimationDoc doc) {
    _heldNowMs = _clock();
    _playing = false;
    _heldIndex = doc.frames.isEmpty ? 0 : index.clamp(0, doc.frames.length - 1);
  }

  /// Steps the held frame by [delta], pausing first and wrapping at the
  /// ends — a scrubber's next/previous, not a clamp.
  void step(int delta, GlossAnimationDoc doc, String id) {
    if (doc.frames.isEmpty) return;
    if (_playing) pause(doc, id);
    final int count = doc.frames.length;
    _heldIndex = ((frameIndex(doc, id) + delta) % count + count) % count;
  }
}
