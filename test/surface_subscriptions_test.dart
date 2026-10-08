import 'dart:convert';

import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/surface_validation.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/model/gloss_surface.dart';
import 'package:gloss_editor/model/gloss_surface_subscription.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:test/test.dart';

void main() {
  Map<String, Object?> source(Object? on) => <String, Object?>{
    'schemaVersion': 1,
    'revision': 4,
    'surface': 'actionbar',
    'select': <String, Object?>{'priority': 0, 'when': 'false'},
    'presentation': <String, Object?>{'text': 'Hello'},
    'variants': <Object?>[],
    'on': on,
    'extension': <String, Object?>{'kept': true},
  };
  test(
    'typed subscriptions preserve omitted defaults and nested extensions',
    () {
      final Map<String, Object?> raw = source(<Object?>[
        <String, Object?>{
          'trigger': 'join',
          'future': <String, Object?>{
            'list': <int>[1, 2],
          },
        },
        <String, Object?>{
          'trigger': 'interval',
          'everyTicks': 40,
          'delayTicks': null,
          'when': null,
        },
      ]);
      final GlossSurfaceDoc doc = GlossSurfaceDoc.fromJson(raw);
      expect(doc.on!.first.trigger, 'join');
      expect(doc.on!.first.delayTicks, isNull);
      expect(doc.toJson(), raw);
      final GlossSurfaceDoc copy = doc.copy();
      (copy.on!.first.extras['future']! as Map<String, dynamic>)['list'] =
          <int>[3];
      expect(doc.toJson(), raw);
      expect(copy.toJson(), isNot(raw));
    },
  );
  test('omitted, null and empty subscriptions retain their authored shape', () {
    for (final Object? value in <Object?>[null, <Object?>[]]) {
      final Map<String, Object?> raw = source(value);
      expect(GlossSurfaceDoc.fromJson(raw).copy().toJson(), raw);
    }
    final Map<String, Object?> raw = source(null)..remove('on');
    expect(GlossSurfaceDoc.fromJson(raw).copy().toJson(), raw);
  });
  test('malformed imports remain raw and survive unrelated changes', () {
    for (final Object? value in <Object?>[
      'invalid',
      <Object?>[null],
      <Object?>[
        <String, Object?>{'trigger': 'interval', 'everyTicks': 2.5},
      ],
      <Object?>[
        <String, Object?>{'trigger': 'join', 'when': false},
      ],
    ]) {
      final GlossSurfaceDoc doc = GlossSurfaceDoc.fromJson(source(value));
      expect(doc.hasMalformedSubscriptions, isTrue);
      doc.presentation.text = 'Changed';
      expect(doc.copy().toJson()['on'], value);
      expect(
        validateSurfaceDoc(doc).any((issue) => issue.path.startsWith(r'$.on')),
        isTrue,
      );
    }
  });
  test(
    'event changes enforce the interval-only field without losing extensions',
    () {
      final GlossSurfaceSubscription entry = GlossSurfaceSubscription(
        trigger: 'join',
        extras: <String, Object?>{'future': 7},
      );
      entry.setTrigger('interval');
      expect(entry.everyTicks, 20);
      entry.everyTicks = 80;
      entry.setTrigger('interval');
      expect(entry.everyTicks, 80);
      entry.setTrigger('world_change');
      expect(entry.toJson(), <String, Object?>{
        'trigger': 'world_change',
        'future': 7,
      });
    },
  );
  test('subscription changes, reorder and deletion restore with undo', () {
    final EditorStore store = EditorStore();
    store.importJson(
      'surface.json',
      jsonEncode(
        source(<Object?>[
          <String, Object?>{'trigger': 'join', 'future': 1},
          <String, Object?>{'trigger': 'interval', 'everyTicks': 60},
        ]),
      ),
    );
    final Map<String, dynamic> baseline = store.surfaceDoc!.toJson();
    store.mutateSurface(
      'change subscription',
      (GlossSurfaceDoc next) => next.on!.first.delayTicks = 12,
    );
    expect(store.performUndo(), isTrue);
    expect(store.surfaceDoc!.toJson(), baseline);
    expect(store.performRedo(), isTrue);
    expect(store.surfaceDoc!.on!.first.delayTicks, 12);
    store.mutateSurface(
      'move subscription',
      (GlossSurfaceDoc next) => next.on!.insert(0, next.on!.removeAt(1)),
    );
    expect(store.surfaceDoc!.on!.first.everyTicks, 60);
    store.mutateSurface(
      'remove subscription',
      (GlossSurfaceDoc next) => next.on!.removeAt(0),
    );
    expect(store.performUndo(), isTrue);
    expect(store.surfaceDoc!.on!.length, 2);
    expect(store.surfaceDoc!.on!.last.extras['future'], 1);
  });
  test(
    'typed values still receive backend bounds and condition validation',
    () {
      final GlossSurfaceDoc doc = GlossSurfaceDoc.fromJson(
        source(<Object?>[
          <String, Object?>{
            'trigger': 'interval',
            'everyTicks': 1728001,
            'delayTicks': -1,
            'when': '(',
          },
          <String, Object?>{'trigger': 'join', 'everyTicks': 20},
        ]),
      );
      final List<String> paths = validateSurfaceDoc(
        doc,
      ).map((issue) => issue.path).toList();
      expect(
        paths,
        containsAll(<String>[
          r'$.on[0].everyTicks',
          r'$.on[0].delayTicks',
          r'$.on[0].when',
          r'$.on[1].everyTicks',
        ]),
      );
      doc.on = List<GlossSurfaceSubscription>.generate(
        65,
        (int index) => GlossSurfaceSubscription(trigger: 'join'),
      );
      expect(
        validateSurfaceDoc(doc).any((issue) => issue.path == r'$.on'),
        isTrue,
      );
    },
  );
  test('completion exposes all four subscription fields', () {
    final GlossJsonArray events =
        glossSurfaceJsonSchema.fields
                .firstWhere((GlossJsonField field) => field.key == 'on')
                .node!
            as GlossJsonArray;
    final GlossJsonObject event = events.item! as GlossJsonObject;
    expect(event.fields.map((GlossJsonField field) => field.key), <String>[
      'trigger',
      'everyTicks',
      'delayTicks',
      'when',
    ]);
  });
}
