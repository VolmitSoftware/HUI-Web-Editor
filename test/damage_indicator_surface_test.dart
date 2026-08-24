library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the editor mounts both authored and in-game renderer surfaces', () {
    final String app = File('lib/app.dart').readAsStringSync();
    expect(
      RegExp(
        r'DocumentSurface\.damageIndicators\s*:\s*DamageIndicatorView',
      ).allMatches(app),
      hasLength(2),
    );
    expect(app, contains('gameContext: true'));
  });

  test('the renderer exposes trajectory, sample, and transport controls', () {
    final String source = File(
      'lib/components/damage_indicators/damage_indicator_view.dart',
    ).readAsStringSync();
    expect(source, contains('resolveDamageIndicatorFrame'));
    expect(source, contains('renderDamageIndicatorText'));
    expect(source, contains('Sample amount'));
    expect(source, contains('Next trajectory'));
    expect(source, contains('Replay'));
    expect(source, contains('GlossGameScreen'));
    expect(
      source,
      contains(
        'final GlossDamageIndicatorsDoc? current = '
        '_store.damageIndicatorsDoc;',
      ),
    );
    expect(source, contains('_workspaceAnimationsPlaying'));
  });

  test('the selected indicator type uses a complete perimeter emphasis', () {
    final String css = File('web/styles/10-gloss.css').readAsStringSync();
    expect(
      css,
      contains(
        '.hui-damage-indicator-kind .arcane-button[aria-pressed="true"]',
      ),
    );
    expect(css, contains('inset 0 0 0 1px var(--hui-accent)'));
  });
}
