import 'dart:convert';

import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/motd_clock.dart';
import 'package:gloss_editor/logic/motd_preview.dart';
import 'package:gloss_editor/logic/motd_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_motd.dart';
import 'package:gloss_editor/model/json_codec.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:test/test.dart';

void main() {
  final Map<String, Object?> fixture = <String, Object?>{
    'schemaVersion': 1,
    'revision': 7,
    'custom': <String, Object?>{'retained': true},
    'state': 'event',
    'rotation': <String, Object?>{
      'mode': 'sequence',
      'intervalSeconds': 30,
      'future': 'keep',
    },
    'icons': <String>['default.png'],
    'favicon': 'fallback.png',
    'links': <Object?>[
      <String, Object?>{
        'type': 'website',
        'url': 'https://example.org/original',
      },
    ],
    'serverLinks': <String, Object?>{
      'enabled': false,
      'future': 42,
      'links': <Object?>[
        <String, Object?>{
          'label': 'Rules',
          'url': 'https://example.org/rules',
          'custom': 'keep',
        },
      ],
    },
    'entries': <Object?>[
      <String, Object?>{
        'lines': <String>['Event'],
        'icons': <String>['event.png'],
        'sampleMode': 'hide',
        'sample': <String>['Hidden sample'],
        'select': <String, Object?>{
          'hostnames': <String>['*.example.org'],
          'minProtocol': 768,
          'maxProtocol': 999,
          'zone': 'Europe/Paris',
          'startTime': '18:00',
          'endTime': '02:00',
          'days': <int>[5, 6],
          'states': <String>['event'],
          'minOnline': 1,
          'maxOnline': 100,
          'future': true,
        },
        'counts': <String, Object?>{
          'onlineMode': 'offset',
          'onlineValue': -3,
          'maximumMode': 'fixed',
          'maximumValue': 200,
          'hide': false,
          'future': 'keep',
        },
      },
    ],
  };
  GlossMotdDoc doc() => GlossMotdDoc.fromJson(jsonDecode(jsonEncode(fixture)));
  MotdPreviewRequest request(
    String instant, {
    String host = 'play.example.org',
    int? protocol = 771,
    int online = 17,
    String? state,
    MotdPreviewPlatform platform = MotdPreviewPlatform.paper,
    bool enabled = true,
  }) => MotdPreviewRequest(
    epochMillis: DateTime.parse(instant).millisecondsSinceEpoch,
    hostname: host,
    protocol: protocol,
    online: online,
    state: state,
    platform: platform,
    motdEnabled: enabled,
  );

  test(
    'typed policies preserve nested extensions, omissions and explicit empty values',
    () {
      final GlossMotdDoc value = doc();
      expect(value.toJson(), fixture);
      expect(value.copy().toJson(), fixture);
      final GlossMotdDoc sparse = decodeGlossMotdDoc(
        '{"schemaVersion":1,"entries":[{"lines":["Hi"]}]}',
      );
      expect(sparse.toJson(), <String, Object?>{
        'schemaVersion': 1,
        'entries': <Object?>[
          <String, Object?>{
            'lines': <String>['Hi'],
          },
        ],
      });
      final GlossMotdDoc empty = decodeGlossMotdDoc(
        '{"schemaVersion":1,"entries":[{"lines":["Hi"],"select":{},"counts":{},"icons":[]}],"rotation":{},"serverLinks":{},"icons":[]}',
      );
      expect(empty.toJson()['rotation'], isEmpty);
      expect(empty.entries.single.toJson()['icons'], isEmpty);
      expect(empty.toJson()['serverLinks'], isEmpty);
    },
  );
  test('policy edits use history and preserve imported extensions', () {
    final EditorStore store = EditorStore();
    store.importJson('motd.json', jsonEncode(fixture));
    store.mutateMotd(
      'rotation',
      (GlossMotdDoc next) => next.rotation!.mode = 'time',
    );
    expect(store.motdDoc!.rotation!.mode, 'time');
    expect(store.performUndo(), isTrue);
    expect(store.motdDoc!.toJson(), fixture);
    expect(store.performRedo(), isTrue);
    expect(store.motdDoc!.rotation!.mode, 'time');
    expect(store.motdDoc!.rotation!.extras, <String, Object?>{
      'future': 'keep',
    });
    expect(store.motdDoc!.entries.single.select!.extras, <String, Object?>{
      'future': true,
    });
  });
  test('invalid policy wire shapes fail without truncating integers', () {
    for (final Object? invalid in <Object?>[1.5, '20', true, 2147483648]) {
      expect(
        () => decodeGlossMotdDoc(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'entries': <Object?>[
              <String, Object?>{
                'lines': <String>['Hi'],
                'select': <String, Object?>{'minProtocol': invalid},
              },
            ],
          }),
        ),
        throwsA(isA<HuiFormatException>()),
      );
    }
    expect(
      () => GlossMotdSelector.fromJson(<String, Object?>{
        'days': <Object?>[null],
      }, r'$.select'),
      throwsA(isA<HuiFormatException>()),
    );
    expect(
      () => GlossMotdServerLinks.fromJson(<String, Object?>{
        'enabled': 'false',
      }, r'$.serverLinks'),
      throwsA(isA<HuiFormatException>()),
    );
  });
  test(
    'validation covers rotation bounds, selector clocks and ranges, icons and links',
    () {
      final GlossMotdDoc value = doc();
      value.rotation!.mode = 'cycle';
      value.rotation!.intervalSeconds = 0;
      value.state = ' ';
      value.icons = <String>[''];
      value.entries.single.sampleMode = 'clear';
      final GlossMotdSelector selector = value.entries.single.select!;
      selector.hostnames = <String>['bad*host'];
      selector.minProtocol = 10;
      selector.maxProtocol = 9;
      selector.startTime = '24:00';
      selector.endTime = null;
      selector.zone = 'No/Such_Zone';
      selector.days = <int>[0, 8];
      value.entries.single.counts!.maximumValue = -1;
      value.serverLinks!.links!.single.url = 'file:///tmp/rules';
      final Set<String> paths = validateMotdDoc(value)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
          .map((HuiIssue issue) => issue.path)
          .toSet();
      expect(
        paths,
        containsAll(<String>[
          r'$.rotation.mode',
          r'$.rotation.intervalSeconds',
          r'$.state',
          r'$.icons[0]',
          'entries[0].sampleMode',
          'entries[0].select.hostnames[0]',
          'entries[0].select.maxProtocol',
          'entries[0].select.zone',
          'entries[0].select.startTime',
          'entries[0].select.days[0]',
          'entries[0].counts.maximumValue',
          r'$.serverLinks.links[0].url',
        ]),
      );
    },
  );
  test('valid policies match the backend document contract', () {
    expect(
      validateMotdDoc(
        doc(),
      ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });
  test(
    'selectors normalize hostnames, require subdomain and bound protocol metadata',
    () {
      final GlossMotdSelector select = GlossMotdSelector(
        hostnames: <String>['*.example.org'],
        minProtocol: 768,
        maxProtocol: 771,
      );
      expect(
        motdSelectorMatches(
          select,
          request('2026-10-09T19:00:00Z', host: 'PLAY.EXAMPLE.ORG.\u0000extra'),
          'normal',
        ),
        isTrue,
      );
      expect(
        motdSelectorMatches(
          select,
          request('2026-10-09T19:00:00Z', host: 'example.org'),
          'normal',
        ),
        isFalse,
      );
      expect(
        motdSelectorMatches(
          select,
          request('2026-10-09T19:00:00Z', protocol: null),
          'normal',
        ),
        isFalse,
      );
      expect(
        motdSelectorMatches(
          select,
          request('2026-10-09T19:00:00Z', protocol: 772),
          'normal',
        ),
        isFalse,
      );
      expect(
        motdSelectorMatches(
          select,
          request('2026-10-09T19:00:00Z', platform: MotdPreviewPlatform.spigot),
          'normal',
        ),
        isFalse,
      );
    },
  );
  test('overnight windows use the new calendar day after midnight', () {
    final GlossMotdSelector select = GlossMotdSelector(
      zone: 'Europe/Paris',
      startTime: '18:00',
      endTime: '02:00',
      days: <int>[5],
    );
    expect(
      motdSelectorMatches(select, request('2026-10-09T16:00:00Z'), 'normal'),
      isTrue,
    );
    expect(
      motdSelectorMatches(select, request('2026-10-09T22:30:00Z'), 'normal'),
      isFalse,
    );
    select.days = <int>[6];
    expect(
      motdSelectorMatches(select, request('2026-10-09T22:30:00Z'), 'normal'),
      isTrue,
    );
    expect(
      motdSelectorMatches(select, request('2026-10-10T00:00:00Z'), 'normal'),
      isFalse,
    );
  });
  test(
    'IANA daylight saving and UTC offsets are evaluated at the requested instant',
    () {
      expect(
        motdZonedTime(
          'America/New_York',
          DateTime.parse('2026-03-08T06:59:00Z').millisecondsSinceEpoch,
        ).hour,
        1,
      );
      expect(
        motdZonedTime(
          'America/New_York',
          DateTime.parse('2026-03-08T07:00:00Z').millisecondsSinceEpoch,
        ).hour,
        3,
      );
      expect(motdZonedTime('UTC+05:30', 0).hour, 5);
      expect(motdZonedTime('UTC+05:30', 0).minute, 30);
      expect(() => motdZonedTime('UTC+18:01', 0), throwsFormatException);
      expect(() => motdZonedTime('Missing/Zone', 0), throwsFormatException);
      expect(motdTimeNanos('23:59:59.123456789'), 86399123456789);
      expect(motdTimeNanos('24:00'), isNull);
      expect(motdTimeNanos('9:00'), isNull);
    },
  );
  test('state and online bounds use real counts before display overrides', () {
    final GlossMotdDoc value = doc();
    expect(
      simulateMotdRequest(value, request('2026-10-09T19:00:00Z')).selectedIndex,
      0,
    );
    expect(
      simulateMotdRequest(
        value,
        request('2026-10-09T19:00:00Z', state: 'maintenance'),
      ).selectedIndex,
      isNull,
    );
    expect(
      simulateMotdRequest(
        value,
        request('2026-10-09T19:00:00Z', online: 101),
      ).selectedIndex,
      isNull,
    );
  });
  test('first, sequence and time rotation select only eligible responses', () {
    final GlossMotdDoc value = GlossMotdDoc(
      entries: <GlossMotdEntry>[
        GlossMotdEntry(lines: <String>['Hidden'], show: false),
        GlossMotdEntry(lines: <String>['One']),
        GlossMotdEntry(lines: <String>['Two']),
      ],
      rotation: GlossMotdRotation(mode: 'first'),
    );
    final MotdPreviewRequest ping = request('1970-01-01T00:01:00Z');
    expect(simulateMotdRequest(value, ping, sequence: 3).selectedIndex, 1);
    value.rotation!.mode = 'sequence';
    expect(simulateMotdRequest(value, ping, sequence: 3).selectedIndex, 2);
    value.rotation!.mode = 'time';
    value.rotation!.intervalSeconds = 60;
    expect(simulateMotdRequest(value, ping).selectedIndex, 2);
  });
  test(
    'weighted samples are reproducible and honor strongly weighted entries',
    () {
      final GlossMotdDoc value = GlossMotdDoc(
        entries: <GlossMotdEntry>[
          GlossMotdEntry(lines: <String>['One'], weight: 1),
          GlossMotdEntry(lines: <String>['Two'], weight: 1000000),
        ],
      );
      final MotdPreviewRequest ping = request('2026-10-09T19:00:00Z');
      expect(
        simulateMotdRequest(value, ping, randomSeed: 17).selectedIndex,
        simulateMotdRequest(value, ping, randomSeed: 17).selectedIndex,
      );
      expect(
        <int>[
          for (int seed = 0; seed < 50; seed++)
            simulateMotdRequest(value, ping, randomSeed: seed).selectedIndex!,
        ].where((int index) => index == 1).length,
        greaterThan(45),
      );
    },
  );
  test('icon precedence and rotation share the response position', () {
    final GlossMotdDoc value = doc();
    value.entries.single.icons = <String>['one.png', 'two.png'];
    expect(
      simulateMotdRequest(
        value,
        request('2026-10-09T19:00:00Z'),
        sequence: 1,
      ).icon,
      'two.png',
    );
    value.entries.single.icons = <String>[];
    value.entries.single.favicon = 'entry.png';
    expect(value.iconsFor(value.entries.single), <String>['entry.png']);
    value.entries.single.favicon = null;
    expect(value.iconsFor(value.entries.single), <String>['default.png']);
    value.icons = <String>[];
    expect(value.iconsFor(value.entries.single), <String>['fallback.png']);
  });
  test(
    'explicit count modes override expressions and preserve Spigot limits',
    () {
      final GlossMotdEntry entry = GlossMotdEntry(
        online: '999',
        max: '1000',
        counts: GlossMotdCounts(
          onlineMode: 'offset',
          onlineValue: -30,
          maximumMode: 'fixed',
          maximumValue: 200,
        ),
      );
      expect(glossMotdPlayerCount(entry, realOnline: 17), '0/200');
      expect(
        glossMotdPlayerCount(entry, platform: MotdPreviewPlatform.spigot),
        '17/200',
      );
      entry.counts!.hide = true;
      expect(glossMotdPlayerCount(entry), '???');
      expect(
        glossMotdPlayerCount(entry, platform: MotdPreviewPlatform.spigot),
        '17/200',
      );
      entry.counts = null;
      entry.online = '{{ server.online }}';
      expect(glossMotdPlayerCount(entry, realOnline: 31), '31/1000');
      entry.online = 'Infinity';
      expect(glossMotdPlayerCount(entry), '17/1000');
    },
  );
  test(
    'sample modes distinguish inherited, empty replacement and hidden samples',
    () {
      final GlossMotdEntry entry = GlossMotdEntry(sample: <String>['Custom']);
      expect(
        glossMotdSampleLines(entry, original: <String>['Original']),
        <String>['Custom'],
      );
      entry.sampleMode = 'inherit';
      expect(
        glossMotdSampleLines(entry, original: <String>['Original']),
        <String>['Original'],
      );
      entry.sampleMode = 'replace';
      entry.sample.clear();
      expect(
        glossMotdSampleLines(entry, original: <String>['Original']),
        isEmpty,
      );
      entry.sampleMode = 'hide';
      expect(
        glossMotdSampleLines(entry, original: <String>['Original']),
        isEmpty,
      );
      expect(
        glossMotdSampleLines(
          entry,
          original: <String>['Original'],
          platform: MotdPreviewPlatform.spigot,
        ),
        <String>['Original'],
      );
    },
  );
  test(
    'independent links remain published without MOTD or eligible responses',
    () {
      final GlossMotdDoc value = doc();
      value.serverLinks!.enabled = true;
      final MotdPreviewResult result = simulateMotdRequest(
        value,
        request('2026-10-09T19:00:00Z', enabled: false),
      );
      expect(result.selectedIndex, isNull);
      expect(result.links.single.label, 'Rules');
      value.serverLinks!.enabled = false;
      expect(value.enabledLinks(true), isEmpty);
      value.serverLinks = null;
      expect(value.enabledLinks(false), isEmpty);
      expect(value.enabledLinks(true).single.type, 'website');
    },
  );
  test('completion schema exposes document response policies', () {
    expect(
      glossMotdJsonSchema.fields.map((field) => field.key),
      containsAll(<String>[
        'rotation',
        'icons',
        'state',
        'serverLinks',
        'entries',
      ]),
    );
  });
}
