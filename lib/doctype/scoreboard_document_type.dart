library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/scoreboard_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss sidebar scoreboard document (`BoardDoc.java`). Kind slug
/// `scoreboard` — deliberately not `board`, which this editor already spent
/// on the legacy name of the world-panel kind.
final class ScoreboardDocumentType extends GlossDocumentTypeAdapter {
  const ScoreboardDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.scoreboard;

  @override
  String get noun => huiText('scoreboard');

  @override
  String get createLabel => huiText('New scoreboard');

  @override
  String get pluralLabel => huiText('Scoreboards');

  @override
  int get tabOrder => 60;

  @override
  DocumentSurface get surface => DocumentSurface.scoreboard;

  @override
  String get surfaceLabel => huiText('Sidebar');

  @override
  String? get syncWireKind => 'scoreboard';

  @override
  Widget railIcon() => ArcaneIcon.panelRight(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossScoreboardDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossScoreboardDoc(doc as GlossScoreboardDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossScoreboard();

  @override
  bool looksLike(Object? decoded) => looksLikeScoreboardDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a scoreboard document: it needs "schemaVersion", '
      '"select", "presentation" and "variants".';

  @override
  String get defaultDocumentName => 'new-scoreboard';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossScoreboardDoc) return const <HuiIssue>[];
    return validateScoreboardDoc(
      doc,
      animations: state.workspaceAnimations,
    );
  }

  @override
  String? get templatesTabLabel => 'Scoreboard';

  @override
  String get templatesNote =>
      'A scoreboard is the right-hand sidebar: a title, up to 15 rendered '
      'lines, document selection and complete conditional variants. Default is '
      'byte-identical to what the plugin ships. Every template opens as a '
      'new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'scoreboard-default',
              name: 'Default board',
              description:
                  'The shipped default: three welcome lines and an always-true '
                  'selection rule. Exactly what plugins/Gloss/boards/ starts '
                  'with.',
              highlights: const <String>['Shipped default', '3 lines'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'default',
                from: buildDefaultGlossScoreboard(),
              ),
            ),
            DocumentTemplate(
              id: 'scoreboard-showcase',
              name: 'Server showcase',
              description:
                  'A conditional sidebar with authored RGB, PAPI, numeric '
                  'math, live metrics and a low-health presentation.',
              highlights: const <String>[
                'Authored code',
                'PAPI + math',
                'Conditional variant',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'showcase',
                from: buildShowcaseGlossScoreboard(),
              ),
            ),
            DocumentTemplate(
              id: 'scoreboard-animation-showcase',
              name: 'Animation showcase',
              description:
                  'One scoreboard line for each shipped text-animation '
                  'effect, ready to preview and edit.',
              highlights: const <String>[
                'Animations',
                'Authored code',
                'Live preview',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'animation-showcase',
                from: buildAnimationShowcaseGlossScoreboard(),
              ),
            ),
          ],
        ),
      ];
}
