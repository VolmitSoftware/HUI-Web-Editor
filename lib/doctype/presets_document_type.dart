import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../l10n/hui_localizations.dart';
import '../logic/presets_validation.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class PresetsDocumentType extends GlossDocumentTypeAdapter {
  const PresetsDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.presets;
  @override
  String get noun => huiText('preset catalog');
  @override
  String get createLabel => huiText('New preset catalog');
  @override
  String get pluralLabel => huiText('Presets');
  @override
  int get tabOrder => 200;
  @override
  DocumentSurface get surface => DocumentSurface.presets;
  @override
  String get surfaceLabel => huiText('Presets');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'presets';
  @override
  String get fixedRuntimeId => 'presets';
  @override
  String get defaultDocumentName => 'presets';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.slidersHorizontal(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossPresetsDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossPresetsDoc(doc as GlossPresetsDoc);
  @override
  GlossDoc newBlank() => GlossPresetsDoc();
  @override
  bool looksLike(Object? decoded) => looksLikePresetsDoc(decoded);
  @override
  String get codeShapeError =>
      'A preset catalog needs schemaVersion 1, revision, defaults and presets.';
  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    return doc is GlossPresetsDoc
        ? validatePresetsDoc(doc)
        : const <HuiIssue>[];
  }
}
