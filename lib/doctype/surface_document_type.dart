library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../config/gloss_templates.dart';
import '../logic/surface_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss HUD surface document (`SurfaceDoc.java`). Kind slug `surface` —
/// one file per document under `plugins/Gloss/surfaces/`, each one claiming a
/// single client surface: the action bar, a boss bar, or the title card.
final class SurfaceDocumentType extends GlossDocumentTypeAdapter {
  const SurfaceDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.surface;

  @override
  String get noun => huiText('surface');

  @override
  String get createLabel => huiText('New surface');

  @override
  String get pluralLabel => huiText('Surfaces');

  @override
  int get tabOrder => 65;

  @override
  DocumentSurface get surface => DocumentSurface.hud;

  @override
  String get surfaceLabel => huiText('HUD');

  @override
  String? get syncWireKind => 'surface';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.gauge(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossSurfaceDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossSurfaceDoc(doc as GlossSurfaceDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossSurface();

  @override
  bool looksLike(Object? decoded) => looksLikeSurfaceDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a surface document: it needs "schemaVersion", a "surface" '
      'of actionbar, bossbar or title, and a "presentation".';

  @override
  String get defaultDocumentName => 'new-surface';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossSurfaceDoc) return const <HuiIssue>[];
    return validateSurfaceDoc(doc, animations: state.workspaceAnimations);
  }

  @override
  String? get templatesTabLabel => 'Surface';

  @override
  String get templatesNote =>
      'A surface is one line of the HUD: the action bar above the hotbar, a '
      'boss bar across the top, or the title card in the middle. The surface '
      'you pick decides which presentation fields the server keeps — it drops '
      'the rest without a word — and a document only reaches anyone once its '
      'selection condition is true. Default is byte-identical to what the '
      'plugin ships. Every template opens as a new document, so your current '
      'one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'surface-welcome',
              name: 'Shipped welcome',
              description:
                  'The shipped default: an action-bar greeting with a short '
                  'lifetime and no selection condition, so it stays quiet '
                  'until you write one. Exactly what '
                  'plugins/Gloss/surfaces/ starts with.',
              highlights: const <String>['Shipped default', 'Action bar'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'welcome',
                from: buildDefaultGlossSurface(),
              ),
            ),
            DocumentTemplate(
              id: 'surface-actionbar-showcase',
              name: 'Status action bar',
              description:
                  'A live status line above the hotbar — world, TPS and '
                  'player count — with a louder variant that takes over when '
                  'health drops.',
              highlights: const <String>[
                'Action bar',
                'Live metrics',
                'Conditional variant',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'status-bar',
                from: buildActionbarShowcaseGlossSurface(),
              ),
            ),
            DocumentTemplate(
              id: 'surface-bossbar-showcase',
              name: 'Event boss bar',
              description:
                  'A boss bar whose fill is an expression, with a colour and '
                  'notch style that change for a VIP group.',
              highlights: const <String>[
                'Boss bar',
                'Expression fill',
                'Notch styles',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'event-bar',
                from: buildBossbarShowcaseGlossSurface(),
              ),
            ),
            DocumentTemplate(
              id: 'surface-title-showcase',
              name: 'Arrival title',
              description:
                  'A title and subtitle with the complete fade, stay and '
                  'repeat timing, plus a second card for arriving in the '
                  'Nether.',
              highlights: const <String>[
                'Title card',
                'Fade timing',
                'Repeat trigger',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'arrival',
                from: buildTitleShowcaseGlossSurface(),
              ),
            ),
          ],
        ),
      ];
}
