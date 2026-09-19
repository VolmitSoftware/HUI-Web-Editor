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

final class InventoryDocumentType extends GlossDocumentTypeAdapter {
  const InventoryDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.inventory;

  @override
  String get noun => huiText('inventory');

  @override
  String get createLabel => huiText('New inventory');

  @override
  String get pluralLabel => huiText('Inventories');

  @override
  int get tabOrder => 120;

  @override
  DocumentSurface get surface => DocumentSurface.inventory;

  @override
  String get surfaceLabel => huiText('Chest window');

  @override
  String? get syncWireKind => 'inventory';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.layoutGrid(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossInventoryDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossInventoryDoc(doc as GlossInventoryDoc);

  @override
  GlossDoc newBlank() => buildBlankGlossInventory();

  @override
  bool looksLike(Object? decoded) => looksLikeInventoryDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not an inventory document: it needs "schemaVersion", a '
      '"resolution" such as 9x3, and a mask, keys or slots.';

  @override
  String get defaultDocumentName => 'new-inventory';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossInventoryDoc) return const <HuiIssue>[];
    return validateInventoryDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Inventory';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'inventory-chest',
              name: 'Empty chest',
              description:
                  'Shipped default',
              highlights: const <String>['9x3', 'Border'],
              create: (EditorStore store) {
                final String runtimeId = 'chest';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildBlankGlossInventory(),
                );
              },
            ),
            DocumentTemplate(
              id: 'inventory-shop',
              name: 'Shop',
              description:
                  'Shipped example',
              highlights: const <String>['Shipped example', '9x6', 'List'],
              create: (EditorStore store) {
                final String runtimeId = 'example';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildShowcaseGlossInventory(),
                );
              },
            ),
          ],
        ),
      ];
}
