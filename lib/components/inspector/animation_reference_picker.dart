/// Cross-kind reference picker: the workspace's animation documents, offered
/// as `|animation.<id>|` insertions.
///
/// The list is the same resolver the surfaces render through
/// ([EditorStore.workspaceAnimations]), so a document listed here is by
/// definition one whose reference will play rather than warn.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class AnimationReferencePicker extends StatefulWidget {
  const AnimationReferencePicker({
    required this.store,
    required this.onPicked,
    this.label,
    super.key,
  });

  final EditorStore store;

  /// Receives the raw reference token, e.g. `|animation.rainbow|`.
  final void Function(String reference) onPicked;
  final String? label;

  @override
  State<AnimationReferencePicker> createState() =>
      _AnimationReferencePickerState();
}

class _AnimationReferencePickerState extends State<AnimationReferencePicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final String label = component.label ?? huiText('Animations');
    final GlossAnimationResolver animations =
        component.store.workspaceAnimations;
    final List<String> ids = animations.ids;
    return ArcanePopover(
      isOpen: _open,
      onOpenChange: (bool open) => setState(() => _open = open),
      position: FloatingPosition.bottom,
      trigger: Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.film(size: IconSize.sm),
        attributes: <String, String>{
          'aria-label': label,
          'aria-expanded': _open ? 'true' : 'false',
          // See placeholder_picker.dart: opts the popover out of the legacy
          // accordion binder that would fight the floating container.
          'data-arcane-interactive': 'true',
        },
        child: Text(label),
      ),
      content: dom.div(classes: 'hui-placeholder-list', <Widget>[
        HuiEyebrow(huiText('Animations')),
        if (ids.isEmpty)
          dom.p(classes: 'hui-placeholder-empty', <Widget>[
            Text(
              huiText(
                'This workspace has no animation documents yet. Create one '
                'from the library rail; its |animation.<id>| reference will '
                'appear here.',
              ),
            ),
          ])
        else
          for (final String id in ids) _row(id, animations.byId(id)),
        dom.p(classes: 'hui-placeholder-foot', <Widget>[
          Text(
            huiText(
              'A reference plays the animation\'s current frame wherever the '
              'line renders. Deleting or renaming the animation later leaves '
              'the reference showing literally.',
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _row(String id, GlossAnimationDoc? doc) => dom.button(
    classes: 'hui-placeholder-row',
    attributes: <String, String>{
      'type': 'button',
      'aria-label': huiText("Insert |animation.{id}|", <String, Object?>{
        'id': id,
      }),
    },
    events: <String, EventCallback>{
      'click': (_) {
        setState(() => _open = false);
        component.onPicked('|animation.$id|');
      },
    },
    <Widget>[
      dom.span(classes: 'hui-placeholder-key', <Widget>[
        Text(huiText("|animation.{id}|", <String, Object?>{'id': id})),
      ]),
      dom.span(classes: 'hui-placeholder-desc', <Widget>[
        Text(
          doc == null
              ? huiText('unreadable document')
              : huiPlural(
                  'animation.reference.frame_summary',
                  doc.frames.length,
                  oneEnglish: '{count} frame · {interval} ms · {mode}',
                  otherEnglish: '{count} frames · {interval} ms · {mode}',
                  arguments: <String, Object?>{
                    'interval': doc.effectiveFrameIntervalMs,
                    'mode': doc.normalizedMode ?? doc.mode,
                  },
                ),
        ),
      ]),
    ],
  );
}
