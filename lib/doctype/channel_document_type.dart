library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;
import '../logic/channel_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class ChannelDocumentType extends GlossDocumentTypeAdapter {
  const ChannelDocumentType();
  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.channel;
  @override
  String get noun => 'chat channel';
  @override
  String get createLabel => 'New chat channel';
  @override
  String get pluralLabel => 'Chat channels';
  @override
  int get tabOrder => 76;
  @override
  DocumentSurface get surface => DocumentSurface.channel;
  @override
  String get surfaceLabel => 'Chat preview';
  @override
  String? get syncWireKind => 'channel';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.messageSquare(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossChannelDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossChannelDoc(doc as GlossChannelDoc);
  @override
  GlossDoc newBlank() => GlossChannelDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeChannelDoc(decoded);
  @override
  String get codeShapeError =>
      'A chat channel needs schemaVersion, channel and format.';
  @override
  String get defaultDocumentName => 'global';
  @override
  List<HuiIssue> validate(DocumentStateView state) =>
      state.glossDoc is GlossChannelDoc
      ? validateChannelDoc(state.glossDoc! as GlossChannelDoc)
      : const <HuiIssue>[];
  @override
  String? get templatesTabLabel => 'Chat';
  @override
  List<DocumentTemplateSection>
  get templateSections => <DocumentTemplateSection>[
    DocumentTemplateSection(
      templates: <DocumentTemplate>[
        DocumentTemplate(
          id: 'channel-global',
          name: 'Global chat with mentions',
          description:
              'Yellow tagged messages and a bell for the named player.',
          highlights: const <String>['Recipient highlight', 'Mention sound'],
          create: (EditorStore store) =>
              store.newGlossDocument(this, name: 'global', from: newBlank()),
        ),
      ],
    ),
  ];
}
