library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/tablist_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss tab-screen document (`TablistDoc.java`). Kind slug `tablist` —
/// the plugin keeps exactly one file, `plugins/Gloss/tablist.json`.
final class TablistDocumentType extends GlossDocumentTypeAdapter {
  const TablistDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.tablist;

  @override
  String get noun => 'tablist';

  @override
  String get createLabel => 'New tablist';

  @override
  List<EditorView> get availableViews => const <EditorView>[
    EditorView.tablist,
    EditorView.code,
  ];

  @override
  String? get syncWireKind => 'tablist';

  @override
  Widget railIcon() => ArcaneIcon.users(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossTablistDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossTablistDoc(doc as GlossTablistDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossTablist();

  @override
  bool looksLike(Object? decoded) => looksLikeTablistDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a tablist document: it needs "schemaVersion" plus tab '
      'keys such as "useHeaderFooter", "groupListNames" or "nameFormats".';

  @override
  String get defaultDocumentName => 'tablist';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossTablistDoc) return const <HuiIssue>[];
    return validateTablistDoc(doc, animations: state.workspaceAnimations);
  }

  @override
  String? get templatesTabLabel => 'Tablist';

  @override
  String get templatesNote =>
      'The tablist is the tab screen: a header and footer over the player '
      'grid, and per-group list-name formats with \$player and \$group '
      'tokens (operators take _op first, unlisted groups fall to default). '
      'Default is byte-identical to what the plugin ships. Every template '
      'opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection>
  get templateSections => <DocumentTemplateSection>[
    DocumentTemplateSection(
      templates: <DocumentTemplate>[
        DocumentTemplate(
          id: 'tablist-default',
          name: 'Default tablist',
          description:
              'The shipped default: Gloss header, VolmitSoftware footer, '
              'plain default names and gold operators. Exactly what '
              'plugins/Gloss/tablist.json starts with.',
          highlights: const <String>['Shipped default', '2 formats'],
          create: (EditorStore store) => store.newGlossDocument(
            this,
            name: 'tablist',
            from: buildDefaultGlossTablist(),
          ),
        ),
        DocumentTemplate(
          id: 'tablist-showcase',
          name: 'Grouped showcase',
          description:
              'A live RGB header with PAPI, ping and metrics, an animated '
              'footer, and group formats including smooth authored RGB animation.',
          highlights: const <String>[
            '3 formats',
            'PAPI + metrics',
            'Authored animation',
          ],
          create: (EditorStore store) => store.newGlossDocument(
            this,
            name: 'tablist',
            from: buildShowcaseGlossTablist(),
          ),
        ),
      ],
    ),
  ];
}
