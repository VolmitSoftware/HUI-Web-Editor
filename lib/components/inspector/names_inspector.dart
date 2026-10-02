import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'inspector_widgets.dart';

class NamesInspector extends StatelessWidget {
  const NamesInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossDoc? active = store.glossDoc;
    if (active is! GlossNamesDoc) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      InspectorSection(
        title: huiText('Names'),
        children: <Widget>[
          HuiRevisionRow(revision: active.revision),
          for (final GlossNameCategory category in GlossNameCategory.values)
            ExtrasEditor(
              title: glossNameCategoryLabel(category),
              extensionKeys: false,
              stringsOnly: true,
              extras: Map<String, Object?>.of(
                active.categories[category] ?? const <String, String>{},
              ),
              onChanged: (String label, Map<String, dynamic> next) =>
                  store.mutateGloss(label, (GlossDoc doc) {
                    if (doc is GlossNamesDoc) {
                      doc.categories[category] = GlossNamesDoc.readNames(
                        next,
                        '\$.${category.name}',
                      );
                    }
                  }),
            ),
        ],
      ),
    ]);
  }
}

String glossNameCategoryLabel(GlossNameCategory category) => switch (category) {
  GlossNameCategory.materials => huiText('Materials'),
  GlossNameCategory.entities => huiText('Entities'),
  GlossNameCategory.worlds => huiText('World'),
  GlossNameCategory.gameModes => huiText('Game modes'),
  GlossNameCategory.dimensions => huiText('Dimensions'),
  GlossNameCategory.damageCauses => huiText('Damage causes'),
  GlossNameCategory.effects => huiText('Effects'),
  GlossNameCategory.groups => huiText('Groups'),
};

class NamesView extends StatelessWidget {
  const NamesView({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossNamesCatalog catalog = store.workspaceNames;
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      for (final GlossNameCategory category in GlossNameCategory.values)
        InspectorSection(
          title: glossNameCategoryLabel(category),
          children: <Widget>[
            for (final MapEntry<String, String> entry
                in (catalog.categories[category] ?? const <String, String>{})
                    .entries)
              HuiField(label: entry.key, control: Text(entry.value)),
          ],
        ),
    ]);
  }
}
