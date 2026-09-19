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

final class MotionDocumentType extends GlossDocumentTypeAdapter {
  const MotionDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.motion;

  @override
  String get noun => huiText('motion');

  @override
  String get createLabel => huiText('New motion');

  @override
  String get pluralLabel => huiText('Motion clips');

  @override
  int get tabOrder => 135;

  @override
  DocumentSurface get surface => DocumentSurface.motion;

  @override
  String get surfaceLabel => huiText('Clip tracks');

  @override
  String? get syncWireKind => 'motion';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.move(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossMotionDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossMotionDoc(doc as GlossMotionDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossMotion();

  @override
  bool looksLike(Object? decoded) => looksLikeMotionDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a motion document: it needs "schemaVersion" plus a '
      '"tracks" list of { bone, channel, keyframes }.';

  @override
  String get defaultDocumentName => 'breathe';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossMotionDoc) return const <HuiIssue>[];
    return validateMotionDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Motion';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'motion-breathe',
              name: 'Breathe',
              description:
                  'Shipped default',
              highlights: const <String>['Shipped default', 'Ping-pong'],
              create: (EditorStore store) {
                final String runtimeId = 'breathe';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossMotion(),
                );
              },
            ),
            DocumentTemplate(
              id: 'motion-spin',
              name: 'Spin',
              description:
                  'Shipped example',
              highlights: const <String>['Shipped', 'Yaw'],
              create: (EditorStore store) {
                final String runtimeId = 'spin';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildShowcaseGlossMotion(),
                );
              },
            ),
          ],
        ),
      ];
}
