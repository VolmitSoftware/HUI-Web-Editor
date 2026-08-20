library;

import 'package:gloss_editor/logic/bubble_motion.dart';
import 'package:gloss_editor/logic/preview_expr.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const GlossBubbleMotionContext _context = GlossBubbleMotionContext(
  t: 0.25,
  ageMs: 500,
  lifetimeMs: 2000,
  stackIndex: 1,
  stackCount: 3,
  lineCount: 2,
  stackY: 1.64,
  seed: 0.4,
);

void main() {
  test('all bubble variables and shared math functions evaluate', () {
    expect(
      evaluateGlossBubbleMotionSource(
        't + remaining + ageMs / lifetimeMs + stackIndex + stackCount + '
        'lineCount + stackY + seed + sin(pi / 2) + pow(2, 3) + '
        'smoothstep(0, 1, t)',
        _context,
      ),
      closeTo(18.44625, 1e-12),
    );
  });

  test('effective values clamp and rotations normalize', () {
    final GlossBubbleMotionProgram program = GlossBubbleMotionProgram.compile(
      GlossBubbleMotion(
        translation: GlossBubbleMotionVector(x: '-100', y: '100', z: '1'),
        scale: GlossBubbleMotionVector(x: '-2', y: '20', z: '1'),
        rotation: GlossBubbleMotionVector(x: '450', y: '-450', z: '720'),
        opacity: '2',
      ),
    );
    final GlossBubbleMotionFrame written = program.evaluateWritten(_context);
    final GlossBubbleMotionFrame effective = program.evaluate(_context);
    expect(written.translationX, -100);
    expect(written.opacity, 2);
    expect(effective.translationX, -64);
    expect(effective.translationY, 64);
    expect(effective.scaleX, 0);
    expect(effective.scaleY, 16);
    expect(effective.rotationX, 90);
    expect(effective.rotationY, 270);
    expect(effective.rotationZ, 0);
    expect(effective.opacity, 1);
  });

  test('negative rotation normalizes into the runtime 0-to-360 range', () {
    final GlossBubbleMotion motion = GlossBubbleMotion.identity();
    motion.rotation.z = '-90';
    final GlossBubbleMotionFrame frame = GlossBubbleMotionProgram.compile(
      motion,
    ).evaluate(_context);
    expect(frame.rotationZ, 270);
  });

  test('context inputs normalize at the same boundaries as Java', () {
    const GlossBubbleMotionContext context = GlossBubbleMotionContext(
      t: 2,
      ageMs: -5,
      lifetimeMs: 0,
      stackIndex: 0,
      stackCount: 1,
      lineCount: 1,
      stackY: 1.12,
      seed: 0.5,
    );
    expect(context.t, 1);
    expect(context.remaining, 0);
    expect(context.ageMs, 0);
    expect(context.lifetimeMs, 1);
    expect(
      evaluateGlossBubbleMotionSource(
        't + remaining + ageMs + lifetimeMs',
        context,
      ),
      2,
    );
  });

  test('overlong and non-finite expressions fail safely', () {
    expect(
      () => GlossBubbleMotionProgram.compile(
        GlossBubbleMotion.identity()..opacity = '1' * 513,
      ),
      throwsA(isA<PExprException>()),
    );
    expect(
      () => evaluateGlossBubbleMotionSource('pow(10, 10000)', _context),
      throwsA(isA<PExprException>()),
    );
  });

  test(
    'a runtime-only leaf failure uses its neutral fallback in isolation',
    () {
      final GlossBubbleMotionProgram program = GlossBubbleMotionProgram.compile(
        GlossBubbleMotion(
          translation: GlossBubbleMotionVector(
            x: '1 / (t - 0.123)',
            y: '3',
            z: '0',
          ),
          scale: GlossBubbleMotionVector.scaleDefaults(),
          rotation: GlossBubbleMotionVector.rotationDefaults(),
          opacity: '0.75',
        ),
      );
      final GlossBubbleMotionFrame frame = program.evaluate(
        const GlossBubbleMotionContext(
          t: 0.123,
          ageMs: 615,
          lifetimeMs: 5000,
          stackIndex: 0,
          stackCount: 1,
          lineCount: 1,
          stackY: 1.12,
          seed: 0.5,
        ),
      );
      expect(frame.translationX, 0);
      expect(frame.translationY, 3);
      expect(frame.opacity, 0.75);
    },
  );
}
