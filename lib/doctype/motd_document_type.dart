library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/motd_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss server-list MOTD document (`MotdDoc.java`). Kind slug `motd`.
/// The plugin keeps exactly one file (`plugins/Gloss/motd.json`) and picks a
/// random entry per ping.
final class MotdDocumentType extends GlossDocumentTypeAdapter {
  const MotdDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.motd;

  @override
  String get noun => 'MOTD';

  @override
  String get createLabel => 'New MOTD';

  @override
  List<EditorView> get availableViews => const <EditorView>[
    EditorView.motd,
    EditorView.code,
  ];

  @override
  String? get syncWireKind => 'motd';

  @override
  Widget railIcon() => ArcaneIcon.server(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossMotdDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossMotdDoc(doc as GlossMotdDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossMotd();

  @override
  bool looksLike(Object? decoded) => looksLikeMotdDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a MOTD document: it needs "schemaVersion" plus an '
      '"entries" list of {"lines": [...]} objects.';

  @override
  String get defaultDocumentName => 'motd';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossMotdDoc) return const <HuiIssue>[];
    return validateMotdDoc(doc, animations: state.workspaceAnimations);
  }

  @override
  String? get templatesTabLabel => 'MOTD';

  @override
  String get templatesNote =>
      'The MOTD is the server-list text: one file, a pool of entries, and a '
      'random pick per ping. Each entry is one or two lines rendered without '
      'a viewer — colours and |animation| functions work, PlaceholderAPI '
      'tokens stay literal. Default is byte-identical to what the plugin '
      'ships. Every template opens as a new document, so your current one is '
      'untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'motd-default',
              name: 'Default MOTD',
              description:
                  'The shipped default: one entry, one pink line. Exactly '
                  'what plugins/Gloss/motd.json starts with.',
              highlights: const <String>['Shipped default', '1 entry'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'motd',
                from: buildDefaultGlossMotd(),
              ),
            ),
            DocumentTemplate(
              id: 'motd-showcase',
              name: 'Rotating showcase',
              description:
                  'Three entries the ping randomizes over: a hex-coloured '
                  'headline, a two-line event notice with a playing '
                  '|animation.rainbow| line, and a one-liner.',
              highlights: const <String>[
                '3 entries',
                'Two-line entries',
                'Animated line',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'motd',
                from: buildShowcaseGlossMotd(),
              ),
            ),
          ],
        ),
      ];
}
