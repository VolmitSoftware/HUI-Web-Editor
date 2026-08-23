/// The animation surface's playback controller under a deterministic
/// injectable clock.
library;

import 'package:gloss_editor/logic/gloss_animation_playback.dart';
import 'package:gloss_editor/logic/gloss_animation_player.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossAnimationDoc _doc({int frames = 4}) => GlossAnimationDoc(
  mode: 'ascend',
  frameIntervalMs: 100,
  frames: <String>[for (int i = 0; i < frames; i++) 'f$i'],
);

void main() {
  test('playing tracks the injected clock exactly like the server', () {
    int now = 0;
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => now);
    final GlossAnimationDoc doc = _doc();
    expect(player.frameIndex(doc, 'a'), 0);
    now = 150;
    expect(player.frameIndex(doc, 'a'), 1);
    now = 12345;
    expect(
      player.frameIndex(doc, 'a'),
      glossAnimationFrameIndexAt(doc, 'a', 12345),
    );
    expect(player.frameText(doc, 'a'), doc.frames[player.frameIndex(doc, 'a')]);
  });

  test('sample uses one clock reading for frame and expression time', () {
    int now = 99;
    final GlossAnimationPlayer player = GlossAnimationPlayer(
      clock: () => now++,
    );
    final GlossAnimationDoc doc = _doc();
    final ({int nowMs, int frameIndex, String frameText}) sample = player
        .sample(doc, 'a');
    expect(sample.nowMs, 99);
    expect(sample.frameIndex, glossAnimationFrameIndexAt(doc, 'a', 99));
    expect(sample.frameText, doc.frames[sample.frameIndex]);
    expect(now, 100, reason: 'the clock was read exactly once');
  });

  test('pause freezes the frame that was showing', () {
    int now = 250;
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => now);
    final GlossAnimationDoc doc = _doc();
    player.pause(doc, 'a');
    expect(player.playing, isFalse);
    expect(player.nowMs, 250);
    now = 999999;
    expect(player.frameIndex(doc, 'a'), 2, reason: 'held at the pause frame');
    expect(player.nowMs, 250, reason: 'expression time freezes with the frame');
  });

  test('play rejoins the live timeline, not the held frame', () {
    int now = 0;
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => now);
    final GlossAnimationDoc doc = _doc();
    player.pause(doc, 'a');
    now = 300;
    player.play();
    expect(player.frameIndex(doc, 'a'), 3);
  });

  test('scrub pauses and addresses a frame directly, clamped', () {
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => 0);
    final GlossAnimationDoc doc = _doc();
    player.scrubTo(2, doc);
    expect(player.playing, isFalse);
    expect(player.frameIndex(doc, 'a'), 2);
    player.scrubTo(99, doc);
    expect(player.frameIndex(doc, 'a'), 3);
    player.scrubTo(-5, doc);
    expect(player.frameIndex(doc, 'a'), 0);
  });

  test('step wraps at both ends', () {
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => 0);
    final GlossAnimationDoc doc = _doc();
    player.scrubTo(3, doc);
    player.step(1, doc, 'a');
    expect(player.frameIndex(doc, 'a'), 0);
    player.step(-1, doc, 'a');
    expect(player.frameIndex(doc, 'a'), 3);
  });

  test('a held index survives the frame list shrinking', () {
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => 0);
    final GlossAnimationDoc doc = _doc();
    player.scrubTo(3, doc);
    doc.frames.removeLast();
    expect(player.frameIndex(doc, 'a'), 2, reason: 'clamped into range');
  });

  test('an empty frame list is inert', () {
    final GlossAnimationPlayer player = GlossAnimationPlayer(clock: () => 0);
    final GlossAnimationDoc doc = GlossAnimationDoc(frames: <String>[]);
    expect(player.frameIndex(doc, 'a'), 0);
    expect(player.frameText(doc, 'a'), '');
    player.step(1, doc, 'a');
    expect(player.frameIndex(doc, 'a'), 0);
  });
}
