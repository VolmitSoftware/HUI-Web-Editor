library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/real_drop_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class RealDropDocumentType extends GlossDocumentTypeAdapter {
  const RealDropDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.realDrops;

  @override
  String get noun => 'real-drop settings';

  @override
  String get createLabel => 'Real drops';

  @override
  String get pluralLabel => 'Real drops';

  @override
  int get tabOrder => 110;

  @override
  DocumentSurface get surface => DocumentSurface.realDrops;

  @override
  String get surfaceLabel => 'Drop stage';

  @override
  String? get syncWireKind => 'real-drops';

  @override
  Widget railIcon() => ArcaneIcon.package(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossRealDropSettingsDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossRealDropSettingsDoc(doc as GlossRealDropSettingsDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossRealDrops();

  @override
  bool looksLike(Object? decoded) => looksLikeRealDropSettingsDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a real-drop settings document: it needs "schemaVersion", '
      '"limits", "scale", "motion", "landing", "labels", and "filters".';

  @override
  String get defaultDocumentName => 'default';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossRealDropSettingsDoc) return const <HuiIssue>[];
    return validateRealDropSettingsDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Real drops';

  @override
  String get templatesNote =>
      'This file controls the native dropped-item models, motion, landing, '
      'labels, limits, and filters. Export it as real-drops/default.json.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'real-drops-default',
              name: 'Default real drops',
              description:
                  'The byte-identical settings Gloss extracts on first run.',
              highlights: const <String>[
                'Plugin default',
                'Fast tumble',
                'Visible labels',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'default',
                from: buildDefaultGlossRealDrops(),
              ),
            ),
          ],
        ),
      ];
}
