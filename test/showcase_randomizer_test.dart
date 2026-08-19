library;

import 'dart:math' as math;

import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

final class _FakeStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

EditorStore _store() {
  final _FakeStorage storage = _FakeStorage();
  return EditorStore(
    workspace: Workspace(read: storage.read, write: storage.write),
    autosaveDelay: Duration.zero,
  );
}

void main() {
  test('showcase choices cover every templated runtime document kind', () {
    final List<ShowcaseSelection> selections = glossShowcaseSelections();
    expect(selections, isNotEmpty);
    expect(
      selections.map((ShowcaseSelection value) => value.type.kind).toSet(),
      containsAll(<WorkspaceDocKind>{
        WorkspaceDocKind.menu,
        WorkspaceDocKind.containerPreview,
        WorkspaceDocKind.hologram,
        WorkspaceDocKind.animation,
        WorkspaceDocKind.scoreboard,
        WorkspaceDocKind.motd,
        WorkspaceDocKind.emoji,
        WorkspaceDocKind.bubbleStyle,
        WorkspaceDocKind.tablist,
      }),
    );
    expect(
      selections.any(
        (ShowcaseSelection value) =>
            value.template.id.toLowerCase().contains('blank'),
      ),
      isFalse,
    );
  });

  test('a seeded pick creates a root document and is reproducible', () {
    final EditorStore first = _store();
    final EditorStore second = _store();
    final ShowcaseSelection? a = createRandomGlossShowcase(
      first,
      random: math.Random(91),
    );
    final ShowcaseSelection? b = createRandomGlossShowcase(
      second,
      random: math.Random(91),
    );
    expect(a, isNotNull);
    expect(b?.template.id, a?.template.id);
    expect(first.workspace.active?.folderId, isNull);
    expect(first.workspace.active?.kind, a?.type.kind);
  });

  test('consecutive picks do not repeat the previous template', () {
    final EditorStore store = _store();
    final ShowcaseSelection first = createRandomGlossShowcase(
      store,
      random: math.Random(4),
    )!;
    final ShowcaseSelection second = createRandomGlossShowcase(
      store,
      random: math.Random(4),
      previousTemplateId: first.template.id,
    )!;
    expect(second.template.id, isNot(first.template.id));
  });
}
