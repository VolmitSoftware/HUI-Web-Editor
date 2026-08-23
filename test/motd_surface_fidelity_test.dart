import 'dart:io';

import 'package:test/test.dart';

void main() {
  final String source = File(
    'lib/components/motd/motd_view.dart',
  ).readAsStringSync();

  test('MOTD preview holds one sampled server-ping frame', () {
    expect(source, contains('int _sampledAtMs ='));
    expect(source, contains('final int nowMs = _sampledAtMs;'));
    expect(source, isNot(contains('Timer.periodic')));
    expect(source, isNot(contains('animationsPlaying')));
  });

  test('Refresh is the only MOTD frame transport', () {
    expect(source, contains('onPressed: _refreshSample'));
    expect(source, contains('ArcaneIcon.refreshCcw'));
    expect(source, isNot(contains('_playPause')));
    expect(source, isNot(contains('ArcaneIcon.play')));
    expect(source, isNot(contains('ArcaneIcon.pause')));
  });

  test('choosing an entry represents a fresh ping sample', () {
    expect(source, contains("'click': (Object? _) => _selectEntry(index)"));
    expect(source, contains('_sampledAtMs = DateTime.now()'));
  });
}
