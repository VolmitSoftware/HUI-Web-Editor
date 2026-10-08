import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;
import '../l10n/hui_localizations.dart';
import '../logic/behavior_validation.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import '../state/editor_store.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class BehaviorDocumentType extends GlossDocumentTypeAdapter {
  const BehaviorDocumentType();
  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.behavior;
  @override
  String get noun => huiText('Behaviors');
  @override
  String get createLabel => huiText('Behaviors');
  @override
  String get pluralLabel => huiText('Behaviors');
  @override
  int get tabOrder => 197;
  @override
  DocumentSurface get surface => DocumentSurface.behavior;
  @override
  String get surfaceLabel => huiText('Behaviors');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'behavior';
  @override
  String get defaultDocumentName => 'new-behaviors';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.slidersHorizontal(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossBehaviorDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossBehaviorDoc(doc as GlossBehaviorDoc);
  @override
  GlossDoc newBlank() => GlossBehaviorDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeBehaviorDoc(decoded);
  @override
  String get codeShapeError =>
      'A behavior document needs schemaVersion 2 and on, matching, or allowServerCommands.';
  @override
  List<HuiIssue> validate(DocumentStateView state) =>
      state.glossDoc is GlossBehaviorDoc
      ? validateBehaviorDoc(state.glossDoc! as GlossBehaviorDoc)
      : const <HuiIssue>[];
  @override
  String get templatesTabLabel => huiText('Behaviors');
  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'behavior-default',
              name: huiText('Behaviors'),
              description: huiText('Event triggers and bounded chat matching'),
              highlights: const <String>[],
              create: (EditorStore store) => store.newGlossDocument(this),
            ),
          ],
        ),
      ];
}
