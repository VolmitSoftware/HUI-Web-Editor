/// Shared building blocks for the editor dialogs.
///
/// Every dialog body is the same two-column shape: a heading column explaining
/// the section in plain words, and a control column. Keeping it here means the
/// stylesheet has exactly one selector to target.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../model/model.dart';
import '../common/common.dart';

class HuiDialogSection extends StatelessWidget {
  const HuiDialogSection({
    required this.title,
    required this.children,
    this.description,
    this.classes = '',
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.section(
        classes: classNames(<String?>['hui-dialog-section', classes]),
        <Widget>[
          dom.div(
            classes: 'hui-dialog-section-heading',
            <Widget>[
              dom.strong(<Widget>[Text(title)]),
              if (description != null) dom.span(<Widget>[Text(description!)]),
            ],
          ),
          dom.div(classes: 'hui-dialog-section-body', children),
        ],
      );
}

/// Monospace block used for paths, commands and JSON previews. Text goes in as
/// a raw node so `<pre>` whitespace is preserved exactly.
class HuiCodeBlock extends StatelessWidget {
  const HuiCodeBlock({
    required this.text,
    this.classes = '',
    this.scroll = false,
    super.key,
  });

  final String text;
  final String classes;
  final bool scroll;

  @override
  Widget build(BuildContext context) => dom.pre(
        classes: classNames(<String?>[
          'hui-codeblock',
          scroll ? 'is-scroll' : null,
          classes,
        ]),
        <Widget>[Component.text(text)],
      );
}

/// Numbered instruction list; the numbers are drawn by CSS counters.
class HuiSteps extends StatelessWidget {
  const HuiSteps({required this.steps, this.classes = '', super.key});

  final List<String> steps;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.ol(
        classes: classNames(<String?>['hui-steps', classes]),
        <Widget>[
          for (final String step in steps) dom.li(<Widget>[Text(step)]),
        ],
      );
}

/// Small labelled chip row, used for template highlights and format facts.
class HuiChips extends StatelessWidget {
  const HuiChips({required this.labels, this.classes = '', super.key});

  final List<String> labels;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: classNames(<String?>['hui-chips', classes]),
        <Widget>[
          for (final String label in labels)
            dom.span(classes: 'hui-chip', <Widget>[Text(label)]),
        ],
      );
}

/// Every image path the menu references, in document order.
///
/// The export dialog uses it to decide whether an images zip is needed, and the
/// image manager uses it to mark which stored images are actually in use.
Set<String> huiUsedImagePaths(HuiMenu menu) {
  final Set<String> paths = <String>{};
  void collect(HuiIcon? icon) {
    switch (icon) {
      case null:
        return;
      case final HuiTextImageIcon image:
        if (image.path.isNotEmpty) paths.add(image.path);
      case final HuiAnimatedImageIcon animated:
        for (final String frame in animated.source) {
          if (frame.isNotEmpty) paths.add(frame);
        }
      case HuiTextIcon():
      case HuiItemIcon():
      case HuiCustomItemIcon():
        return;
    }
  }

  for (final HuiComponent entry in menu.components) {
    switch (entry.data) {
      case final HuiButtonData data:
        collect(data.icon);
      case final HuiDecorationData data:
        collect(data.icon);
      case final HuiToggleData data:
        collect(data.trueIcon);
        collect(data.falseIcon);
    }
  }
  return paths;
}

/// Rewrites every reference to [from] as [to]. Returns true when something
/// changed, so callers can skip an empty undo step.
///
/// Renaming a stored image would otherwise silently orphan the icons that point
/// at it: the plugin resolves the path at open time and draws the missing-icon
/// placeholder when the file is gone.
bool huiRepointImagePaths(HuiMenu menu, String from, String to) {
  bool changed = false;
  void repoint(HuiIcon? icon) {
    switch (icon) {
      case null:
        return;
      case final HuiTextImageIcon image:
        if (image.path == from) {
          image.path = to;
          changed = true;
        }
      case final HuiAnimatedImageIcon animated:
        for (int i = 0; i < animated.source.length; i++) {
          if (animated.source[i] == from) {
            animated.source[i] = to;
            changed = true;
          }
        }
      case HuiTextIcon():
      case HuiItemIcon():
      case HuiCustomItemIcon():
        return;
    }
  }

  for (final HuiComponent entry in menu.components) {
    switch (entry.data) {
      case final HuiButtonData data:
        repoint(data.icon);
      case final HuiDecorationData data:
        repoint(data.icon);
      case final HuiToggleData data:
        repoint(data.trueIcon);
        repoint(data.falseIcon);
    }
  }
  return changed;
}

/// Human-readable byte size for quota meters and export summaries.
String huiFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final double mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 2 : 1)} MB';
}
