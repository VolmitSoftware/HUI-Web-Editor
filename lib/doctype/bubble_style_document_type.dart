library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/bubble_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss chat-bubble style document (`BubbleStyleDoc.java`). Kind slug
/// `bubble-style` — one style per file under `plugins/Gloss/bubbles/`, with
/// `default.json` as the fallback every unmatched player gets.
final class BubbleStyleDocumentType extends GlossDocumentTypeAdapter {
  const BubbleStyleDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.bubbleStyle;

  @override
  String get noun => 'bubble style';

  @override
  String get createLabel => 'New bubble style';

  @override
  List<EditorView> get availableViews => const <EditorView>[
    EditorView.bubble,
    EditorView.code,
  ];

  @override
  String? get syncWireKind => 'bubble-style';

  @override
  Widget railIcon() => ArcaneIcon.messageCircle(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossBubbleStyleDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossBubbleStyleDoc(doc as GlossBubbleStyleDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossBubbleStyle();

  @override
  bool looksLike(Object? decoded) => looksLikeBubbleStyleDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a bubble-style document: it needs "schemaVersion" plus '
      'bubble keys such as "wordWrapChars", "maxAliveMs" or "flyAway".';

  @override
  String get defaultDocumentName => 'new-bubble-style';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossBubbleStyleDoc) return const <HuiIssue>[];
    return validateBubbleStyleDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Bubbles';

  @override
  String get templatesNote =>
      'A bubble style shapes chat bubbles: prefix colour, eye offset, word '
      'wrap, per-line stagger, lifetime and the fly-away launch. Out-of-range '
      'numbers are clamped silently by the server — the editor warns with '
      'the effective value instead. Default is byte-identical to what the '
      'plugin ships. Every template opens as a new document, so your current '
      'one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'bubble-default',
              name: 'Default style',
              description:
                  'The shipped default: grey prefix, one block above the '
                  'eyes, 32-character wrap, fly-away on. Exactly what '
                  'plugins/Gloss/bubbles/default.json starts with — and the '
                  'file name "default" is the fallback id.',
              highlights: const <String>['Shipped default', 'Fallback style'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'default',
                from: buildDefaultGlossBubbleStyle(),
              ),
            ),
            DocumentTemplate(
              id: 'bubble-showcase',
              name: 'VIP overworld',
              description:
                  'A gold, tight-wrapped, anchored style that auto-applies '
                  'to the vip group in world* worlds at priority 10.',
              highlights: const <String>[
                'Select rule',
                'World glob',
                'Anchored',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'vip',
                from: buildShowcaseGlossBubbleStyle(),
              ),
            ),
          ],
        ),
      ];
}
