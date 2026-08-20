library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/emoji_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss chat emoji document (`EmojiDoc.java`). Kind slug `emoji` — one
/// emoji per file under `plugins/Gloss/emoji/`, the file name naming the chat
/// token `:<id>:`.
final class EmojiDocumentType extends GlossDocumentTypeAdapter {
  const EmojiDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.emoji;

  @override
  String get noun => 'emoji';

  @override
  String get createLabel => 'New emoji';

  @override
  String get pluralLabel => 'Emoji';

  @override
  int get tabOrder => 80;

  @override
  DocumentSurface get surface => DocumentSurface.emoji;

  @override
  String get surfaceLabel => 'Glyphs';

  @override
  String? get syncWireKind => 'emoji';

  @override
  Widget railIcon() => ArcaneIcon.smile(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossEmojiDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossEmojiDoc(doc as GlossEmojiDoc);

  @override
  GlossDoc newBlank() => buildBlankGlossEmoji();

  @override
  bool looksLike(Object? decoded) => looksLikeEmojiDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not an emoji document: it needs "schemaVersion" plus an '
      '"emoji" value (a glyph or U+XXXX; escapes).';

  @override
  String get defaultDocumentName => 'new-emoji';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossEmojiDoc) return const <HuiIssue>[];
    return validateEmojiDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Emoji';

  @override
  String get templatesNote =>
      'An emoji is one chat substitution: the document id becomes the '
      ':token:, an optional trigger is a second spelling, and the emoji '
      'value is a glyph or U+XXXX; escapes. The plugin ships 67 of these; '
      'workspace documents override same-named shipped ones in the editor '
      'previews. Every template opens as a new document, so your current one '
      'is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'emoji-heart',
              name: 'Shipped heart',
              description:
                  'The shipped heart.json, byte for byte: U+2764; with the '
                  '<3 trigger — the one default that teaches triggers.',
              highlights: const <String>['Shipped default', 'Trigger'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'heart',
                from: buildHeartGlossEmoji(),
              ),
            ),
            DocumentTemplate(
              id: 'emoji-blank',
              name: 'Blank emoji',
              description:
                  'A valid starter: sparkles (U+2728;), no trigger, enabled. '
                  'Rename the document to pick its :token:.',
              highlights: const <String>['Starter', 'Token only'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'new-emoji',
                from: buildBlankGlossEmoji(),
              ),
            ),
          ],
        ),
      ];
}
