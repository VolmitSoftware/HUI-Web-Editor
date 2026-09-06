/// The randomizer dialog: one Generate button. A plain press draws a fresh
/// seed every time, so nobody has to think about seeds to get variety; the
/// seed that was used is written back into the field and named in the toast
/// so a keeper can be reproduced. Holding Shift while pressing uses the seed
/// in the field instead, which is the reproducible path.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

import '../../l10n/hui_localizations.dart';
import '../../services/showcase_randomizer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';

const int _seedLimit = 2147483647;

class ShowcaseRandomizerDialog extends StatefulWidget {
  const ShowcaseRandomizerDialog({
    required this.store,
    required this.documentId,
    required this.seed,
    required this.onGenerated,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final String documentId;
  final int seed;
  final void Function(int seed) onGenerated;
  final VoidCallback onClose;

  @override
  State<ShowcaseRandomizerDialog> createState() =>
      _ShowcaseRandomizerDialogState();
}

class _ShowcaseRandomizerDialogState extends State<ShowcaseRandomizerDialog> {
  late int _seed;

  /// Whether Shift is down, read off the window so the dialog need not hold
  /// focus: the button relabels itself while the key is held.
  bool _shiftHeld = false;
  JSFunction? _keyDown;
  JSFunction? _keyUp;

  @override
  void initState() {
    super.initState();
    _seed = component.seed;
    _keyDown = ((web.Event event) => _syncShift(event, true)).toJS;
    _keyUp = ((web.Event event) => _syncShift(event, false)).toJS;
    web.window.addEventListener('keydown', _keyDown);
    web.window.addEventListener('keyup', _keyUp);
    web.window.addEventListener('blur', _keyUp);
  }

  @override
  void dispose() {
    web.window.removeEventListener('keydown', _keyDown);
    web.window.removeEventListener('keyup', _keyUp);
    web.window.removeEventListener('blur', _keyUp);
    super.dispose();
  }

  void _syncShift(web.Event event, bool down) {
    // A blur has no key; it releases Shift like a keyup would.
    final bool isShift =
        !event.isA<web.KeyboardEvent>() ||
        (event as web.KeyboardEvent).key == 'Shift';
    if (!isShift) return;
    if (down == _shiftHeld) return;
    setState(() => _shiftHeld = down);
  }

  /// [seeded] uses the field's seed; otherwise a fresh draw is taken and
  /// written back so the result can be reproduced later.
  void _generate({required bool seeded}) {
    final int seed = seeded ? _seed : math.Random().nextInt(_seedLimit);
    if (!randomizeShowcaseDocument(
      component.store,
      component.documentId,
      random: math.Random(seed),
    )) {
      return;
    }
    _seed = seed;
    component.onGenerated(seed);
    ArcaneSonner.success(
      huiText('Generated seed {seed}.', <String, Object?>{'seed': seed}),
    );
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-showcase-randomizer-dialog',
    isOpen: true,
    onClose: component.onClose,
    title: huiText('Randomize document'),
    maxWidth: 580,
    actions: <Widget>[
      Button(
        label: huiText('Cancel'),
        variant: ButtonVariant.outline,
        onPressed: component.onClose,
      ),
      Button(
        label: _shiftHeld ? huiText('Generate with seed') : huiText('Generate'),
        variant: ButtonVariant.primary,
        onPressed: () => _generate(seeded: _shiftHeld),
      ),
    ],
    children: <Widget>[
      HuiDialogSection(
        title: huiText('Seed'),
        description: huiText(
          'The same seed and workspace assets reproduce the same document. Undo restores the previous version.',
        ),
        children: <Widget>[
          HuiNumberField(
            value: _seed.toDouble(),
            integer: true,
            step: 1,
            min: 0,
            max: _seedLimit.toDouble(),
            ariaLabel: huiText('Seed'),
            onChanged: (double value) =>
                setState(() => _seed = value.round().clamp(0, _seedLimit)),
          ),
          dom.p(classes: 'hui-dialog-note', <Widget>[
            Text(
              huiText(
                'Generate draws a new seed each time. Hold Shift while pressing it to use the seed above.',
              ),
            ),
          ]),
        ],
      ),
    ],
  );
}
