library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/gloss_templates.dart';
import '../logic/animation_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

/// The Gloss text-animation document (`AnimationDoc.java`): frames on an
/// interval, referenced from other documents as `|animation.<id>|`.
final class AnimationDocumentType extends GlossDocumentTypeAdapter {
  const AnimationDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.animation;

  @override
  String get noun => 'animation';

  @override
  String get createLabel => 'New animation';

  @override
  String get pluralLabel => 'Animations';

  @override
  int get tabOrder => 50;

  @override
  DocumentSurface get surface => DocumentSurface.animation;

  @override
  String get surfaceLabel => 'Player';

  @override
  String? get syncWireKind => 'animation';

  @override
  Widget railIcon() => ArcaneIcon.film(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossAnimationDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossAnimationDoc(doc as GlossAnimationDoc);

  @override
  GlossDoc newBlank() => buildBlankGlossAnimation();

  @override
  bool looksLike(Object? decoded) => looksLikeAnimationDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not an animation document: it needs "schemaVersion" and a '
      '"frames" list.';

  @override
  String get defaultDocumentName => 'new-animation';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossAnimationDoc) return const <HuiIssue>[];
    return validateAnimationDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Animation';

  @override
  String get templatesNote =>
      'An animation is a frame list other documents play through '
      '|animation.<id>| — the id is this document\'s file path. Rainbow is '
      'byte-identical to the default the plugin ships. Every template opens '
      'as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection>
  get templateSections => <DocumentTemplateSection>[
    DocumentTemplateSection(
      templates: <DocumentTemplate>[
        DocumentTemplate(
          id: 'animation-rainbow',
          name: 'Rainbow',
          description:
              'The shipped default: a 60-step RGB hue gradient advancing '
              'once per tick. Prefix text with |animation.rainbow| to '
              'colour it without inserting another word.',
          highlights: const <String>['Shipped default', 'Smooth RGB'],
          create: (EditorStore store) => store.newGlossDocument(
            this,
            name: 'rainbow',
            from: buildRainbowGlossAnimation(),
          ),
        ),
        DocumentTemplate(
          id: 'animation-blank',
          name: 'Blank animation',
          description:
              'The smallest file Gloss accepts: one frame, default mode '
              'and interval.',
          highlights: const <String>['1 frame', 'Starter'],
          create: (EditorStore store) => store.newGlossDocument(
            this,
            name: 'new-animation',
            from: buildBlankGlossAnimation(),
          ),
        ),
        for (final String mode in <String>[
          'descend',
          'ascend_descend',
          'random',
        ])
          DocumentTemplate(
            id: 'animation-${mode.replaceAll('_', '-')}',
            name: switch (mode) {
              'descend' => 'Descending frames',
              'ascend_descend' => 'Ping-pong frames',
              _ => 'Random frames',
            },
            description:
                'A working multi-frame example of Gloss animation mode '
                '$mode.',
            highlights: <String>['$mode mode', '4 frames', '250 ms'],
            create: (EditorStore store) => store.newGlossDocument(
              this,
              name: 'example-${mode.replaceAll('_', '-')}',
              from: GlossAnimationDoc(
                mode: mode,
                frameIntervalMs: 250,
                frames: <String>[
                  "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 3) + 1) / 2)) }}Frame one",
                  '&6&lFrame two',
                  '&a&oFrame three',
                  '&b&nFrame four',
                ],
              ),
            ),
          ),
      ],
    ),
  ];
}
