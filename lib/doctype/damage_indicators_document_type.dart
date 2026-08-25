library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../l10n/hui_localizations.dart';
import '../logic/damage_indicator_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class DamageIndicatorsDocumentType extends GlossDocumentTypeAdapter {
  const DamageIndicatorsDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.damageIndicators;

  @override
  String get noun => huiText('damage-indicator settings');

  @override
  String get createLabel => huiText('Damage indicators');

  @override
  String get pluralLabel => huiText('Damage indicators');

  @override
  int get tabOrder => 95;

  @override
  DocumentSurface get surface => DocumentSurface.damageIndicators;

  @override
  String get surfaceLabel => huiText('Combat stage');

  @override
  String? get syncWireKind => 'damage-indicators';

  @override
  Widget railIcon() => ArcaneIcon.crosshair(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossDamageIndicatorsDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossDamageIndicatorsDoc(doc as GlossDamageIndicatorsDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossDamageIndicators();

  @override
  bool looksLike(Object? decoded) => looksLikeDamageIndicatorsDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a damage-indicators document: it needs "schemaVersion", '
      '"limits", "damage", "healing", and "audience".';

  @override
  String get defaultDocumentName => glossDamageIndicatorsDefaultId;

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossDamageIndicatorsDoc) return const <HuiIssue>[];
    return validateDamageIndicatorsDoc(doc);
  }

  @override
  String? get templatesTabLabel => huiText('Damage indicators');

  @override
  String get templatesNote => huiText(
    'The singleton damage-indicators/default.json file controls combat '
    'number admission, conditional presentations, and viewer audience.',
  );

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'damage-indicators-default',
              name: huiText('Default combat numbers'),
              description: huiText(
                'The settings Gloss extracts on first run, with red damage '
                'and green healing trajectories.',
              ),
              highlights: <String>[
                huiText('Plugin default'),
                huiText('Damage and healing'),
                huiText('Three-second lifetime'),
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: glossDamageIndicatorsDefaultId,
                from: buildDefaultGlossDamageIndicators(),
              ),
            ),
          ],
        ),
      ];
}
