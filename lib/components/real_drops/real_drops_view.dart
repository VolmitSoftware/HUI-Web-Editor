library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';

class RealDropsView extends StatefulWidget {
  const RealDropsView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  State<RealDropsView> createState() => _RealDropsViewState();
}

class _RealDropsViewState extends State<RealDropsView> {
  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant RealDropsView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GlossRealDropSettingsDoc? doc = _store.realDropSettingsDoc;
    if (doc == null) {
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: 'Real drops in game',
        );
      }
      return const dom.div(
        classes: 'hui-real-drops-stage is-empty',
        <Widget>[],
      );
    }

    final int count = doc.limits.maxVisualsPerStack.clamp(1, 5).toInt();
    final double speed = doc.motion.speedMultiplier.clamp(0.1, 4).toDouble();
    final Widget scene = dom.div(classes: 'hui-real-drops-scene', <Widget>[
      if (doc.labels.enabled)
        dom.div(
          classes: doc.labels.seeThrough
              ? 'hui-real-drops-label is-see-through'
              : 'hui-real-drops-label',
          styles: dom.Styles(
            raw: <String, String>{
              'bottom': '${90 + doc.labels.yOffset * 48}px',
              'transform': 'translateX(-50%) scale(${doc.labels.scale})',
              if (doc.labels.shadow)
                'text-shadow': '0 2px 2px rgba(0, 0, 0, .9)',
              if (doc.labels.background)
                'background':
                    'rgba(${doc.labels.backgroundRed}, ${doc.labels.backgroundGreen}, '
                    '${doc.labels.backgroundBlue}, '
                    '${(doc.labels.backgroundAlpha / 255).toStringAsFixed(3)})',
            },
          ),
          const <Widget>[Text('20x Cobblestone')],
        ),
      for (int index = 0; index < count; index++)
        dom.div(
          classes:
              'hui-real-drops-model '
              '${doc.motion.tumble ? 'is-tumbling ' : ''}'
              'is-${doc.landing.mode.toLowerCase()}',
          styles: dom.Styles(
            raw: <String, String>{
              'left':
                  'calc(50% + ${(index - (count - 1) / 2) * doc.limits.spread * 150}px)',
              'width': '${54 * doc.scale.defaultScale / 0.4}px',
              'height': '${54 * doc.scale.defaultScale / 0.4}px',
              'animation-duration': '${(1.8 / speed).toStringAsFixed(3)}s',
              'animation-delay': '-${index * 0.19}s',
            },
          ),
          const <Widget>[],
        ),
      const dom.div(classes: 'hui-real-drops-ground', <Widget>[]),
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: 'Real drops in game',
        child: scene,
      );
    }

    return dom.div(classes: 'hui-real-drops-stage', <Widget>[
      scene,
      dom.div(classes: 'hui-real-drops-readout', <Widget>[
        Text(
          '${doc.motion.tumble ? 'Tumble' : 'Static'} ${speed.toStringAsFixed(2)}x · '
          '${doc.landing.mode.toLowerCase()} landing · $count models · '
          '${doc.limits.updateIntervalTicks}-tick updates',
        ),
      ]),
    ]);
  }
}
