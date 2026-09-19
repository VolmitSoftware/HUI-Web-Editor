library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../config/gloss_templates.dart';
import '../logic/display_lane_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class DialogDocumentType extends GlossDocumentTypeAdapter {
  const DialogDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.dialog;

  @override
  String get noun => huiText('dialog');

  @override
  String get createLabel => huiText('New dialog');

  @override
  String get pluralLabel => huiText('Dialogs');

  @override
  int get tabOrder => 115;

  @override
  DocumentSurface get surface => DocumentSurface.dialog;

  @override
  String get surfaceLabel => huiText('Dialog screen');

  @override
  String? get syncWireKind => 'dialog';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.appWindow(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossDialogDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossDialogDoc(doc as GlossDialogDoc);

  @override
  GlossDoc newBlank() => buildBlankGlossDialog();

  @override
  bool looksLike(Object? decoded) => looksLikeDialogDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a dialog document: it needs "schemaVersion" plus a '
      'dialog "type" (notice, confirmation, multi_action, server_links or '
      'dialog_list).';

  @override
  String get defaultDocumentName => 'new-dialog';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossDialogDoc) return const <HuiIssue>[];
    return validateDialogDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Dialog';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'dialog-notice',
              name: 'Notice',
              description:
                  'Shipped default',
              highlights: const <String>['Notice', 'One button'],
              create: (EditorStore store) {
                final String runtimeId = 'notice';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildBlankGlossDialog(),
                );
              },
            ),
            DocumentTemplate(
              id: 'dialog-trader',
              name: 'Trader',
              description:
                  'Shipped example',
              highlights: const <String>[
                'Shipped example',
                'Inputs',
                'Fallback',
              ],
              create: (EditorStore store) {
                final String runtimeId = 'example';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildShowcaseGlossDialog(),
                );
              },
            ),
          ],
        ),
      ];
}
