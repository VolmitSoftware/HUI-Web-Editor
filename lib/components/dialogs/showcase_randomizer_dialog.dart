library;

import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../l10n/hui_localizations.dart';
import '../../services/showcase_randomizer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';

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

  @override
  void initState() {
    super.initState();
    _seed = component.seed;
  }

  void _generate(bool next) {
    final int seed = next ? (_seed + 1) % 2147483648 : _seed;
    if (!randomizeShowcaseDocument(
      component.store,
      component.documentId,
      random: math.Random(seed),
    )) {
      return;
    }
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
        label: huiText('Next seed'),
        variant: ButtonVariant.outline,
        onPressed: () => _generate(true),
      ),
      Button(
        label: huiText('Generate'),
        variant: ButtonVariant.primary,
        onPressed: () => _generate(false),
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
            max: 2147483647,
            ariaLabel: huiText('Seed'),
            onChanged: (double value) =>
                setState(() => _seed = value.round().clamp(0, 2147483647)),
          ),
        ],
      ),
    ],
  );
}
