/// Inspector body for a Gloss animation document: mode, interval (with the
/// plugin's silent clamp surfaced), and the reorderable frame list with
/// per-frame pipeline previews.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class AnimationInspector extends StatelessWidget {
  const AnimationInspector({required this.store, super.key});

  final EditorStore store;

  GlossAnimationDoc? get _doc => store.animationDoc;

  List<HuiIssue> _issuesFor(String path) => store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossAnimationDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-animation', <Widget>[
      _header(doc),
      _playback(doc),
      _frames(doc),
    ]);
  }

  Widget _header(GlossAnimationDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-animation', <Widget>[
          HuiEyebrow(huiText('Animation')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(store.menuId),
            ]),
            const HuiFieldHelp('animation.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              "Other documents play this through |animation.{menuId}|.",
              <String, Object?>{'menuId': store.menuId},
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  Widget _playback(GlossAnimationDoc doc) => InspectorSection(
    title: huiText('Playback'),
    children: <Widget>[
      HuiField(
        label: huiText('Mode'),
        required: true,
        trailing: const HuiFieldHelp('animation.mode'),
        help: huiText('How the frame index walks the list.'),
        control: dom.div(<Widget>[
          HuiSegmented(
            value: doc.normalizedMode ?? doc.mode,
            segments: <HuiSegment>[
              HuiSegment(value: 'ascend', label: huiText('Ascend')),
              HuiSegment(value: 'descend', label: huiText('Descend')),
              HuiSegment(
                value: 'ascend_descend',
                label: huiText('Ping-pong'),
                hint: huiText('ascend_descend: up the list, then back down'),
              ),
              HuiSegment(value: 'random', label: huiText('Random')),
            ],
            onChanged: (String value) => store.mutateAnimation(
              'animation mode',
              (GlossAnimationDoc edited) => edited.mode = value,
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.mode')),
        ]),
      ),
      HuiField(
        label: huiText('Frame interval'),
        required: true,
        trailing: const HuiFieldHelp('animation.frameIntervalMs'),
        help: huiText(
          'Milliseconds per frame. Gloss silently clamps this into '
          '1..60000.',
        ),
        control: dom.div(<Widget>[
          HuiDurationField(
            value: doc.frameIntervalMs.toDouble(),
            unit: HuiDurationUnit.milliseconds,
            step: 50,
            perLabel: huiText('per frame'),
            onChanged: (double value) => store.mutateAnimation(
              'animation interval',
              (GlossAnimationDoc edited) =>
                  edited.frameIntervalMs = value.round(),
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.frameIntervalMs')),
        ]),
      ),
    ],
  );

  Widget _frames(GlossAnimationDoc doc) => HuiLineListSection(
    title: huiText('Frames'),
    docKey: 'animation.frames',
    addLabel: huiText('Add frame'),
    itemCount: doc.frames.length,
    issues: _issuesFor(r'$.frames'),
    emptyTone: HuiNoteTone.danger,
    emptyBody: huiText(
      'Gloss rejects an animation with no frames, so nothing that '
      'references this document renders either. One frame is legal and '
      'simply holds.',
    ),
    onAdd: () => store.mutateAnimation(
      'add frame',
      (GlossAnimationDoc edited) => edited.frames.add(''),
    ),
    onReorder: (int from, int to) =>
        store.mutateAnimation('reorder frame', (GlossAnimationDoc edited) {
          final String moved = edited.frames.removeAt(from);
          edited.frames.insert(to, moved);
        }),
    itemBuilder: (int index) => _frameRow(doc, index),
  );

  Widget _frameRow(GlossAnimationDoc doc, int index) {
    final String frame = doc.frames[index];
    return HuiLineRow(
      value: frame,
      placeholder: huiText('&cFrame text'),
      removeLabel: huiText('Delete frame {number}', <String, Object?>{
        'number': index + 1,
      }),
      preview: GlossTextLine(
        render: renderGlossLine(frame, emoji: store.workspaceEmoji),
      ),
      onChanged: (String value) =>
          store.mutateAnimation('edit frame', (GlossAnimationDoc edited) {
            if (index < edited.frames.length) edited.frames[index] = value;
          }),
      onRemove: () =>
          store.mutateAnimation('delete frame', (GlossAnimationDoc edited) {
            if (index < edited.frames.length) edited.frames.removeAt(index);
          }),
    );
  }
}
