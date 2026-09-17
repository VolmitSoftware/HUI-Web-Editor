import 'dart:io';

import 'package:gloss_editor/logic/motd_preview.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  final String source = File(
    'lib/components/motd/motd_view.dart',
  ).readAsStringSync();
  final String inspector = File(
    'lib/components/inspector/motd_inspector.dart',
  ).readAsStringSync();

  test('both favicon fields edit through the MOTD mutation path', () {
    expect(inspector, contains("const HuiFieldHelp('motd.favicon')"));
    expect(inspector, contains("const HuiFieldHelp('motd.entries.favicon')"));
    expect(inspector, contains('edited.favicon = value.isEmpty'));
    expect(
      inspector,
      contains('edited.entries[index].favicon = value.isEmpty ? null : value'),
    );
    expect(inspector, isNot(contains('setState(() => doc.favicon')));
  });

  test('both favicon fields upload through the server-icon path', () {
    // The text-image path would downscale a 64x64 icon to 16x16.
    expect(inspector, contains('upload: images.addFaviconsFromFiles'));
    expect(inspector, isNot(contains('addFromFiles')));
    expect(inspector, contains('multiple: false'));
    expect(inspector, contains("'motd-favicon-upload'"));
    expect(inspector, contains("'motd-entry-favicon-upload-\$index'"));
  });

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

  test('the server-list icon slot draws the resolved favicon', () {
    expect(source, contains('faviconFor('));
    expect(source, contains('images?.byPath('));
    expect(source, contains('stored.dataUri'));
    expect(source, contains('image-rendering'));
    // The vanilla glyph still stands in when no icon resolves to bytes.
    expect(source, contains('hui-motd-icon-glyph'));
  });

  test('choosing an entry represents a fresh ping sample', () {
    expect(source, contains("'click': (Object? _) => _selectEntry(index)"));
    expect(source, contains('_sampledAtMs = DateTime.now()'));
  });

  test('the row draws the counts, the version slot and the hover sample', () {
    expect(source, contains('glossMotdPlayerCount('));
    expect(source, contains('glossMotdVersionLabel('));
    expect(source, contains('glossMotdSampleLines('));
    expect(source, contains('hui-motd-version'));
    expect(source, contains('hui-motd-sample'));
    // The sample is markup the stylesheet reveals on hover, never a node the
    // preview only builds while hovered: a screenshot has no pointer.
    expect(source, isNot(contains('_hoveringSample')));
    expect(source, isNot(contains("'mouseenter'")));
  });

  test('the inspector edits the links and the per-entry ping extras', () {
    for (final String key in <String>[
      'motd.links',
      'motd.links.type',
      'motd.links.label',
      'motd.links.url',
      'motd.entries.sample',
      'motd.entries.online',
      'motd.entries.max',
      'motd.entries.version',
    ]) {
      // Both mount the same popover: a field row through HuiFieldHelp, a
      // list section through the docKey its header renders.
      expect(
        inspector.contains("HuiFieldHelp('$key')") ||
            inspector.contains("docKey: '$key'"),
        isTrue,
        reason: key,
      );
    }
    expect(inspector, contains('edited.links.add('));
    expect(inspector, contains('edited.links.removeAt('));
    expect(inspector, contains('onReorder:'));
    expect(inspector, contains('glossMotdLinkTypes'));
    expect(inspector, contains('edited.entries[index].sample'));
    expect(inspector, contains('edited.entries[index].online'));
    expect(inspector, contains('edited.entries[index].max'));
    expect(inspector, contains('edited.entries[index].version'));
  });

  group('the mock row reports the ping an entry authors', () {
    GlossMotdEntry entry({
      List<String>? sample,
      String? online,
      String? max,
      String? version,
    }) => GlossMotdEntry(
      lines: <String>['&dA glossy server'],
      sample: sample,
      online: online,
      max: max,
      version: version,
    );

    test('an unset count falls back to the sampled figure', () {
      expect(glossMotdPlayerCount(entry()), '17/100');
      expect(glossMotdPlayerCount(null), '17/100');
      expect(glossMotdPlayerCount(entry(online: '   ')), '17/100');
    });

    test('an authored count replaces the sampled one on its own side', () {
      expect(glossMotdPlayerCount(entry(online: '42')), '42/100');
      expect(glossMotdPlayerCount(entry(max: '500')), '17/500');
      expect(glossMotdPlayerCount(entry(online: '8', max: '9')), '8/9');
    });

    test('a fractional count truncates, the way MotdService.number does', () {
      expect(glossMotdPlayerCount(entry(online: '7.9')), '7/100');
    });

    test('a count that does not render to a number keeps the sample', () {
      expect(glossMotdPlayerCount(entry(online: 'lots')), '17/100');
      expect(glossMotdPlayerCount(entry(max: '&a100')), '17/100');
    });

    test('the hover sample renders and stops at twelve lines', () {
      expect(glossMotdSampleLines(entry()), isEmpty);
      expect(glossMotdSampleLines(null), isEmpty);
      expect(
        glossMotdSampleLines(entry(sample: <String>['&7Now playing', '&fSky'])),
        <String>['&7Now playing', '&fSky'],
      );
      expect(
        glossMotdSampleLines(
          entry(
            sample: <String>[
              for (int index = 0; index < 20; index++) 'line $index',
            ],
          ),
        ),
        hasLength(glossMotdMaxSampleLines),
      );
    });

    test('the version label is the rendered text, or nothing when blank', () {
      expect(glossMotdVersionLabel(entry(version: '&cOutdated')), '&cOutdated');
      expect(glossMotdVersionLabel(entry(version: '  ')), isNull);
      expect(glossMotdVersionLabel(entry()), isNull);
      expect(glossMotdVersionLabel(null), isNull);
    });
  });
}
