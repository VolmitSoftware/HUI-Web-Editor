library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

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
  String get noun => huiText('real-drop settings');

  @override
  String get createLabel => huiText('Real drops');

  @override
  String get pluralLabel => huiText('Real drops');

  @override
  int get tabOrder => 110;

  @override
  DocumentSurface get surface => DocumentSurface.realDrops;

  @override
  String get surfaceLabel => huiText('Drop stage');

  @override
  String? get syncWireKind => 'real-drops';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.package(size: IconSize.sm);

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
      '"presentation", "variants", and "audience".';

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
      'This file controls the fallback presentation, complete conditional '
      'variants, and per-viewer audience. Export it as real-drops/default.json.';

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
            DocumentTemplate(
              id: 'real-drops-palmer-house',
              name: 'Palmer House drift',
              description:
                  'Slow, upright and legible: loot you are meant to read '
                  'from across the room.',
              highlights: const <String>[
                'Upright landing',
                'Half-speed tumble',
                'Large tinted labels',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'palmer-house',
                from: buildPalmerHouseGlossRealDrops(),
              ),
            ),
            DocumentTemplate(
              id: 'real-drops-sawmill',
              name: 'Sawmill scatter',
              description:
                  'Fast, wide and messy — a mined stack thrown across the '
                  'floor, five models to a stack.',
              highlights: const <String>[
                'Natural tilt',
                'Re-rolls on bounce',
                'Player drops only',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'sawmill',
                from: buildSawmillGlossRealDrops(),
              ),
            ),
            DocumentTemplate(
              id: 'real-drops-quiet',
              name: 'Quiet woods',
              description:
                  'Small, still ground clutter: no labels, no tumble, and a '
                  'four-tick poll for the cheapest run.',
              highlights: const <String>[
                'No labels',
                'Flat landing',
                'Lowest cost',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'quiet-woods',
                from: buildQuietGlossRealDrops(),
              ),
            ),
          ],
        ),
      ];
}
