library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

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
  String get noun => huiText('bubble style');

  @override
  String get createLabel => huiText('New bubble style');

  @override
  String get pluralLabel => huiText('Bubble styles');

  @override
  int get tabOrder => 90;

  @override
  DocumentSurface get surface => DocumentSurface.bubble;

  @override
  String get surfaceLabel => huiText('Bubbles');

  @override
  String? get syncWireKind => 'bubble-style';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.messageCircle(size: IconSize.sm);

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
      'bubble keys such as "wordWrapChars", "maxAliveMs" or "motion".';

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
      'wrap, lifetime and mathematical translation, scale, rotation and '
      'opacity over the block lifetime, plus one delayed whole-block shine '
      'sweep and a second departure sweep. Out-of-range values are clamped by '
      'the server and shown honestly by the preview. Default is '
      'byte-identical to what the '
      'plugin ships. Every template opens as a new document, so your current '
      'one is untouched.';

  @override
  List<DocumentTemplateSection>
  get templateSections => <DocumentTemplateSection>[
    DocumentTemplateSection(
      templates: <DocumentTemplate>[
        DocumentTemplate(
          id: 'bubble-default',
          name: 'Default style',
          description:
              'The shipped default: grey prefix, one block above the '
              'eyes, 32-visible-character wrap, and the legacy fly-away '
              'curve authored as an expression, with one white shine band '
              'crossing the complete wrapped message twice. '
              'Exactly what plugins/Gloss/bubbles/default.json starts with — '
              'and the file name "default" is the fallback id.',
          highlights: const <String>[
            'Shipped default',
            'Fallback style',
            'Original shine band',
          ],
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
              'A formatted, animated, fading arc that auto-applies to '
              'a typed world-and-group condition at priority 10, with a '
              'wide pink shimmer sweeping the whole wrapped block.',
          highlights: const <String>[
            'Select rule',
            'Typed condition',
            'Anchored',
            'Expression motion',
            'Custom shimmer',
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
