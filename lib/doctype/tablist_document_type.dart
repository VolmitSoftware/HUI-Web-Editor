library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

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
  String get noun => huiText('tablist');

  @override
  String get createLabel => huiText('New tablist');

  @override
  String get pluralLabel => huiText('Tab lists');

  @override
  int get tabOrder => 100;

  @override
  DocumentSurface get surface => DocumentSurface.tablist;

  @override
  String get surfaceLabel => huiText('Tab screen');

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
      'That is not a tablist document: it needs "schemaVersion", '
      '"headerFooter" and "listNames".';

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
      'grid, plus conditional list-name formats with \$player and \$group '
      'tokens. Each section has a complete default and prioritized variants. '
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
              'plain default names and a conditional gold operator format. Exactly what '
              'plugins/Gloss/tablist.json starts with.',
          highlights: const <String>['Shipped default', 'Conditional names'],
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
              'footer, and conditional formats including smooth authored RGB animation.',
          highlights: const <String>[
            'Prioritized variants',
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
