/// MOTD validation: the `MotdDoc.java` parse rejections as errors, the
/// renderStatic realities (animations play, placeholders never expand) as
/// warnings and infos.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/motd_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossMotdDoc _doc(List<List<String>> entries, {int revision = 1}) =>
    GlossMotdDoc(
      revision: revision,
      entries: <GlossMotdEntry>[
        for (final List<String> lines in entries)
          GlossMotdEntry(lines: List<String>.of(lines)),
      ],
    );

final class _OneAnimation implements GlossAnimationResolver {
  _OneAnimation(this.id);

  final String id;

  @override
  List<String> get ids => <String>[id];

  @override
  GlossAnimationDoc? byId(String wanted) =>
      wanted == id ? GlossAnimationDoc(frames: <String>['&cGloss']) : null;
}

void main() {
  test('the shipped default validates clean', () {
    expect(
      validateMotdDoc(
        _doc(<List<String>>[
          <String>['&dA glossy server'],
        ]),
      ),
      isEmpty,
    );
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['a'],
      ], revision: 0),
    );
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  test('no entries is an error — the plugin rejects the file', () {
    final List<HuiIssue> issues = validateMotdDoc(_doc(<List<String>>[]));
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.entries');
  });

  test('an entry with zero or three lines is an error', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>[],
        <String>['a', 'b', 'c'],
        <String>['fine'],
      ]),
    );
    expect(issues, hasLength(2));
    expect(issues[0].path, 'entries[0].lines');
    expect(issues[0].severity, HuiSeverity.error);
    expect(issues[1].path, 'entries[1].lines');
    expect(issues[1].message, contains('3 lines'));
  });

  test('a long line warns with the visible character count', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&d${'x' * 60}'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.warning);
    expect(issues.single.message, contains('60 visible characters'));
  });

  test('a dangling animation reference warns; a resolvable one is clean', () {
    final GlossMotdDoc doc = _doc(<List<String>>[
      <String>['|animation.rainbow|'],
    ]);
    final List<HuiIssue> dangling = validateMotdDoc(doc);
    expect(dangling.single.severity, HuiSeverity.warning);
    expect(dangling.single.message, contains('animation.rainbow'));
    expect(validateMotdDoc(doc, animations: _OneAnimation('rainbow')), isEmpty);
  });

  test('a placeholder is an info — a ping has no viewer', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&7Hi %player_name%'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains('%player_name%'));
    expect(issues.single.message, contains('no viewer'));
  });

  group('favicon', () {
    GlossMotdDoc iconDoc({String? document, String? entry}) => GlossMotdDoc(
      favicon: document,
      entries: <GlossMotdEntry>[
        GlossMotdEntry(lines: <String>['&dA glossy server'], favicon: entry),
      ],
    );

    test('an absent or blank favicon is clean at both levels', () {
      expect(validateMotdDoc(iconDoc()), isEmpty);
      expect(validateMotdDoc(iconDoc(document: '   ', entry: '')), isEmpty);
    });

    test('a plain relative path is clean at both levels', () {
      expect(
        validateMotdDoc(
          iconDoc(document: 'server.png', entry: 'icons/event.png'),
        ),
        isEmpty,
      );
    });

    test('an extension other than png warns at both levels', () {
      final List<HuiIssue> document = validateMotdDoc(
        iconDoc(document: 'server.webp'),
      );
      expect(document.single.severity, HuiSeverity.warning);
      expect(document.single.path, r'$.favicon');
      expect(document.single.message, contains('PNG'));

      final List<HuiIssue> entry = validateMotdDoc(
        iconDoc(entry: 'icons/event.JPG'),
      );
      expect(entry.single.severity, HuiSeverity.warning);
      expect(entry.single.path, 'entries[0].favicon');
    });

    test('a .PNG in any casing is clean', () {
      expect(validateMotdDoc(iconDoc(document: 'server.PNG')), isEmpty);
    });

    test('an absolute document favicon is an error on the document path', () {
      final List<HuiIssue> issues = validateMotdDoc(
        iconDoc(document: '/srv/server.png'),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.favicon');
      expect(issues.single.message, contains('must not start with'));
    });

    test('traversal and a drive-style path are errors on the entry', () {
      final List<HuiIssue> issues = validateMotdDoc(
        iconDoc(entry: r'C:..\icons\event.png'),
      );
      expect(
        issues.map((HuiIssue issue) => issue.severity).toSet(),
        <HuiSeverity>{HuiSeverity.error},
      );
      expect(issues.map((HuiIssue issue) => issue.path).toSet(), <String>{
        'entries[0].favicon',
      });
      expect(issues, hasLength(3));
    });

    test('a path the image library does not hold is an info', () {
      final List<HuiIssue> clean = validateMotdDoc(
        iconDoc(document: 'server.png', entry: 'event.png'),
        knownImagePaths: <String>{'server.png', 'event.png'},
      );
      expect(clean, isEmpty);

      final List<HuiIssue> missing = validateMotdDoc(
        iconDoc(document: 'server.png', entry: 'event.png'),
        knownImagePaths: <String>{'server.png'},
      );
      expect(missing.single.severity, HuiSeverity.info);
      expect(missing.single.path, 'entries[0].favicon');
      expect(missing.single.message, contains('image library'));
    });
  });

  group('links', () {
    GlossMotdDoc linkDoc(List<GlossMotdLink> links) => GlossMotdDoc(
      entries: <GlossMotdEntry>[
        GlossMotdEntry(lines: <String>['&dA glossy server']),
      ],
      links: links,
    );

    test('a typed link and a labelled link are both clean', () {
      expect(
        validateMotdDoc(
          linkDoc(<GlossMotdLink>[
            GlossMotdLink(type: 'website', url: 'https://example.net'),
            GlossMotdLink(
              label: '&bStore',
              url: 'http://store.example.net/buy',
            ),
          ]),
        ),
        isEmpty,
      );
    });

    test('past sixteen links is an error naming the count', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[
          for (int index = 0; index < glossMotdMaxLinks + 1; index++)
            GlossMotdLink(type: 'website', url: 'https://example.net/$index'),
        ]),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.links');
      expect(issues.single.message, contains('17'));
      expect(issues.single.message, contains('16'));
    });

    test('exactly sixteen links is clean', () {
      expect(
        validateMotdDoc(
          linkDoc(<GlossMotdLink>[
            for (int index = 0; index < glossMotdMaxLinks; index++)
              GlossMotdLink(type: 'news', url: 'https://example.net/$index'),
          ]),
        ),
        isEmpty,
      );
    });

    test('a link with neither a type nor a label is an error', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[GlossMotdLink(url: 'https://example.net')]),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, 'links[0]');
      expect(issues.single.message, contains('label'));
    });

    test('a blank label is absent, so it does not stand in for a type', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[
          GlossMotdLink(label: '   ', url: 'https://example.net'),
        ]),
      );
      expect(issues.single.path, 'links[0]');
    });

    test('a type outside LINK_TYPES is an error listing the ten', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[
          GlossMotdLink(type: 'discord', url: 'https://example.net'),
        ]),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, 'links[0].type');
      expect(issues.single.message, contains('discord'));
      expect(issues.single.message, contains('report_bug'));
    });

    test('a missing url is an error', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[GlossMotdLink(type: 'website', url: '  ')]),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, 'links[0].url');
    });

    test('a non-http scheme and a url without a host are errors', () {
      for (final String url in <String>[
        'ftp://example.net',
        'example.net',
        'https:///nohost',
        'mailto:staff@example.net',
      ]) {
        final List<HuiIssue> issues = validateMotdDoc(
          linkDoc(<GlossMotdLink>[GlossMotdLink(type: 'support', url: url)]),
        );
        expect(issues.single.severity, HuiSeverity.error, reason: url);
        expect(issues.single.path, 'links[0].url', reason: url);
      }
    });

    test('a url that is not a URI at all is an error', () {
      final List<HuiIssue> issues = validateMotdDoc(
        linkDoc(<GlossMotdLink>[
          GlossMotdLink(type: 'support', url: 'https://exa mple.net'),
        ]),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, 'links[0].url');
    });
  });

  group('entry ping extras', () {
    GlossMotdDoc entryDoc({
      List<String>? sample,
      String? online,
      String? max,
      String? version,
    }) => GlossMotdDoc(
      entries: <GlossMotdEntry>[
        GlossMotdEntry(
          lines: <String>['&dA glossy server'],
          sample: sample,
          online: online,
          max: max,
          version: version,
        ),
      ],
    );

    test('twelve hover lines are clean, thirteen are an error', () {
      expect(
        validateMotdDoc(
          entryDoc(
            sample: <String>[
              for (int index = 0; index < glossMotdMaxSampleLines; index++)
                '&7line $index',
            ],
          ),
        ),
        isEmpty,
      );

      final List<HuiIssue> issues = validateMotdDoc(
        entryDoc(
          sample: <String>[
            for (int index = 0; index < glossMotdMaxSampleLines + 1; index++)
              '&7line $index',
          ],
        ),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, 'entries[0].sample');
      expect(issues.single.message, contains('13'));
      expect(issues.single.message, contains('12'));
    });

    test('a plain number is clean for both counts', () {
      expect(validateMotdDoc(entryDoc(online: '42', max: '500')), isEmpty);
      expect(validateMotdDoc(entryDoc(online: '7.0')), isEmpty);
    });

    test('a non-numeric literal count is an error on its own path', () {
      final List<HuiIssue> online = validateMotdDoc(entryDoc(online: 'lots'));
      expect(online.single.severity, HuiSeverity.error);
      expect(online.single.path, 'entries[0].online');
      expect(online.single.message, contains('lots'));

      final List<HuiIssue> max = validateMotdDoc(entryDoc(max: '&a100'));
      expect(max.single.severity, HuiSeverity.error);
      expect(max.single.path, 'entries[0].max');
    });

    test('a template count is accepted — the ping renders it', () {
      expect(
        validateMotdDoc(
          entryDoc(
            online: '{{ server.online }}',
            max: '{{ server.maxPlayers }}',
          ),
        ),
        isEmpty,
      );

      // A |function| count is a template too: the note it raises is the
      // document-level metric one, never a broken-count error.
      final List<HuiIssue> metric = validateMotdDoc(
        entryDoc(online: '|metric.react.tps|'),
      );
      expect(metric.single.severity, HuiSeverity.info);
      expect(metric.single.path, r'$');
    });

    test('a blank count is absent, not a broken one', () {
      expect(validateMotdDoc(entryDoc(online: '   ', max: '')), isEmpty);
    });

    test('the version label is free text', () {
      expect(validateMotdDoc(entryDoc(version: '&cOutdated — 1.21')), isEmpty);
    });

    test('a broken expression in a ping extra is reported on its path', () {
      final List<HuiIssue> issues = validateMotdDoc(
        entryDoc(version: '{{ nope( }}'),
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.path, 'entries[0].version');
    });
  });

  test('metric references are one info listing the keys', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&7TPS |metric.react.tps|', '|metric.iris.chunks|'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$');
    expect(issues.single.message, contains('react.tps'));
    expect(issues.single.message, contains('iris.chunks'));
  });
}
