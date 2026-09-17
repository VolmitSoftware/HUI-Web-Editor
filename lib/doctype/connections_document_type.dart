library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../config/gloss_templates.dart';
import '../logic/connections_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss connection-message document (`ConnectionsDoc.java`). Kind slug
/// `connections` — the plugin keeps exactly one file,
/// `plugins/Gloss/connections.json`, holding the join and leave lines a
/// standalone server broadcasts.
final class ConnectionsDocumentType extends GlossDocumentTypeAdapter {
  const ConnectionsDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.connections;

  @override
  String get noun => huiText('connection messages');

  @override
  String get createLabel => huiText('New connection messages');

  @override
  String get pluralLabel => huiText('Connection messages');

  @override
  int get tabOrder => 75;

  @override
  DocumentSurface get surface => DocumentSurface.connections;

  @override
  String get surfaceLabel => huiText('Chat lines');

  @override
  String? get syncWireKind => 'connections';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.messageSquare(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossConnectionsDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossConnectionsDoc(doc as GlossConnectionsDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossConnections();

  @override
  bool looksLike(Object? decoded) => looksLikeConnectionsDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a connections document: it needs "schemaVersion" plus a '
      '"join" or "leave" block of {"presentation": {"text": ...}}.';

  @override
  String get fixedRuntimeId => 'connections';

  @override
  String get defaultDocumentName => 'connections';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossConnectionsDoc) return const <HuiIssue>[];
    return validateConnectionsDoc(doc, animations: state.workspaceAnimations);
  }

  @override
  String? get templatesTabLabel => 'Connections';

  @override
  String get templatesNote =>
      'Connection messages are the join and leave lines: one file, one block '
      'per event, and a line rendered separately for every player who reads '
      'it. That is why the text says {{ subject.name }} for whoever connected '
      'and {{ viewer.name }} for whoever is reading. A block the file leaves '
      'out is off, so deleting a section is how you stop broadcasting it. '
      'Default is byte-identical to what the plugin ships. Every template '
      'opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'connections-default',
              name: 'Default connection messages',
              description:
                  'The shipped default: a green join line and a red leave '
                  'line, both naming the player who connected. Exactly what '
                  'plugins/Gloss/connections.json starts with.',
              highlights: const <String>['Shipped default', 'Join and leave'],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'connections',
                from: buildDefaultGlossConnections(),
              ),
            ),
            DocumentTemplate(
              id: 'connections-staff',
              name: 'Staff-aware announcements',
              description:
                  'Join and leave lines that carry the live player count, '
                  'plus a higher-priority variant that greets staff '
                  'differently. Shows how a condition replaces the base text.',
              highlights: const <String>[
                'Two variants',
                'Live counts',
                'Group condition',
              ],
              create: (EditorStore store) => store.newGlossDocument(
                this,
                name: 'connections',
                from: buildShowcaseGlossConnections(),
              ),
            ),
          ],
        ),
      ];
}
