import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../l10n/hui_localizations.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import '../state/editor_store.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class NamesDocumentType extends GlossDocumentTypeAdapter {
  const NamesDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.names;
  @override
  String get noun => huiText('Names');
  @override
  String get createLabel => huiText('Names');
  @override
  String get pluralLabel => huiText('Names');
  @override
  int get tabOrder => 170;
  @override
  DocumentSurface get surface => DocumentSurface.names;
  @override
  String get surfaceLabel => huiText('Names');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'names';
  @override
  String get fixedRuntimeId => 'names';
  @override
  String get defaultDocumentName => 'names';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.bookOpen(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossNamesDoc(json);
  @override
  String encodeDoc(GlossDoc doc) => encodeGlossNamesDoc(doc as GlossNamesDoc);
  @override
  GlossDoc newBlank() => GlossNamesDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeNamesDoc(decoded);
  @override
  String get codeShapeError =>
      'A names document needs schemaVersion and a name category map.';
  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossNamesDoc) return const <HuiIssue>[];
    final List<HuiIssue> issues = <HuiIssue>[?glossRevisionIssue(doc.revision)];
    for (final MapEntry<GlossNameCategory, Map<String, String>> category
        in doc.categories.entries) {
      final Set<String> keys = <String>{};
      for (final String key in category.value.keys) {
        final String normalized = category.key.normalize(key);
        if (normalized.isEmpty || !keys.add(normalized)) {
          issues.add(
            HuiIssue(
              severity: HuiSeverity.error,
              path: '\$.${category.key.name}.$key',
              message: normalized.isEmpty
                  ? 'Give the key a name.'
                  : '{key} is already here.',
              messageArguments: <String, Object?>{'key': normalized},
            ),
          );
        }
      }
    }
    return issues;
  }

  @override
  String get templatesTabLabel => huiText('Names');
  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'names-default',
              name: huiText('Names'),
              description: huiText('Plugin default'),
              highlights: <String>[
                huiText('Materials'),
                huiText('Entities'),
                huiText('Groups'),
              ],
              create: (EditorStore store) => store.newGlossDocument(this),
            ),
          ],
        ),
      ];
}
