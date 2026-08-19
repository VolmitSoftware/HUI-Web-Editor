library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/hologram_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss world-anchored hologram document (`HologramDoc.java`): a text
/// line stack rendered as one `TextDisplay` at an anchor.
final class HologramDocumentType extends GlossDocumentTypeAdapter {
  const HologramDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.hologram;

  @override
  String get noun => 'hologram';

  @override
  String get createLabel => 'New hologram';

  @override
  List<EditorView> get availableViews => const <EditorView>[
    EditorView.hologram,
    EditorView.code,
  ];

  @override
  String? get syncWireKind => 'hologram';

  @override
  Widget railIcon() => ArcaneIcon.sparkles(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossHologramDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossHologramDoc(doc as GlossHologramDoc);

  @override
  GlossDoc newBlank() => buildBlankGlossHologram();

  @override
  bool looksLike(Object? decoded) => looksLikeHologramDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a hologram document: it needs "schemaVersion" and an '
      '"anchor" object.';

  @override
  String get defaultDocumentName => 'new-hologram';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossHologramDoc) return const <HuiIssue>[];
    return validateHologramDoc(doc, animations: state.workspaceAnimations);
  }

  @override
  String? get templatesTabLabel => 'Hologram';

  @override
  String get templatesNote =>
      'A hologram is one TextDisplay at a world anchor; each line runs '
      'through the Gloss text pipeline (animations, placeholders, colours). '
      'Blank is byte-identical to the baseline the plugin creates from. '
      'Every template opens as a new document, so your current one is '
      'untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'hologram-blank',
              name: 'Blank hologram',
              description:
                  'The plugin baseline: one pink line at the world origin. '
                  'The same bytes /gloss hologram create starts from.',
              highlights: const <String>['Plugin baseline', '1 line'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'new-hologram',
                from: buildBlankGlossHologram(),
              ),
            ),
            DocumentTemplate(
              id: 'hologram-showcase',
              name: 'Welcome showcase',
              description:
                  'Four lines showing bracket hex, legacy colours, a PAPI '
                  'placeholder chip and a playing |animation.rainbow| line.',
              highlights: const <String>[
                '4 lines',
                'Animated line',
                'Placeholder',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'welcome-hologram',
                from: buildShowcaseGlossHologram(),
              ),
            ),
          ],
        ),
      ];
}
