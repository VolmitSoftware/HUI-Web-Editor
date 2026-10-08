import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../l10n/hui_localizations.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class GlyphInspector extends StatelessWidget {
  const GlyphInspector({required this.store, super.key});
  final EditorStore store;

  void _edit(String label, void Function(GlossGlyphDoc) edit) =>
      store.mutateGloss(label, (GlossDoc doc) {
        if (doc is GlossGlyphDoc) edit(doc);
      });

  Widget _text(
    String label,
    String value,
    void Function(GlossGlyphDoc, String) edit,
  ) => HuiField(
    label: huiText(label),
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      attributes: <String, String>{'aria-label': label},
      onChanged: (String value) =>
          _edit(label, (GlossGlyphDoc doc) => edit(doc, value)),
    ),
  );

  Widget _number(
    String label,
    num value,
    void Function(GlossGlyphDoc, double) edit,
  ) => HuiField(
    label: huiText(label),
      control: HuiNumberField(
        value: value.toDouble(),
        ariaLabel: label,
      onChanged: (double value) =>
          _edit(label, (GlossGlyphDoc doc) => edit(doc, value)),
    ),
  );

  Widget _button(String label, void Function(GlossGlyphDoc) edit) => Button(
    label: huiText(label),
    variant: ButtonVariant.outline,
    onPressed: () => _edit(label, edit),
  );

  @override
  Widget build(BuildContext context) {
    final GlossDoc? active = store.glossDoc;
    if (active is! GlossGlyphDoc) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      HuiRevisionRow(revision: active.revision),
      InspectorSection(
        title: huiText('Font'),
        children: <Widget>[
          _text(
            'Namespace',
            active.namespace,
            (GlossGlyphDoc doc, String value) => doc.namespace = value,
          ),
          _text(
            'Font',
            active.font,
            (GlossGlyphDoc doc, String value) => doc.font = value,
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Space provider'),
        children: <Widget>[
          HuiSwitchRow(
            label: huiText('Enabled'),
            value: active.space.enabled,
            onChanged: (bool value) => _edit(
              'space enabled',
              (GlossGlyphDoc doc) => doc.space.enabled = value,
            ),
          ),
          _number(
            'Minimum',
            active.space.range.firstOrNull ?? -256,
            (GlossGlyphDoc doc, double value) => doc.space.range = <int>[
              value.toInt(),
              doc.space.range.lastOrNull ?? 256,
            ],
          ),
          _number(
            'Maximum',
            active.space.range.lastOrNull ?? 256,
            (GlossGlyphDoc doc, double value) => doc.space.range = <int>[
              doc.space.range.firstOrNull ?? -256,
              value.toInt(),
            ],
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Glyphs'),
        children: <Widget>[
          if (active.glyphs.isEmpty)
            Text(
              huiText('No bitmap glyphs. Add a glyph and choose its PNG path.'),
            ),
          for (int index = 0; index < active.glyphs.length; index++)
            _glyph(active.glyphs[index], index),
          _button(
            'Add glyph',
            (GlossGlyphDoc doc) => doc.glyphs.add(
              GlossGlyph(
                id: _nextId('glyph', <String>{
                  for (final GlossGlyph glyph in doc.glyphs) glyph.id,
                  for (final GlossGlyphOverlay overlay in doc.overlays)
                    overlay.id,
                }),
              ),
            ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Overlays'),
        children: <Widget>[
          if (active.overlays.isEmpty) Text(huiText('No overlay bitmaps.')),
          for (int index = 0; index < active.overlays.length; index++)
            _overlay(active.overlays[index], index),
          _button(
            'Add overlay',
            (GlossGlyphDoc doc) => doc.overlays.add(
              GlossGlyphOverlay(
                id: _nextId('overlay', <String>{
                  for (final GlossGlyph glyph in doc.glyphs) glyph.id,
                  for (final GlossGlyphOverlay overlay in doc.overlays)
                    overlay.id,
                }),
              ),
            ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Waypoint styles'),
        children: <Widget>[
          if (active.waypointStyles.isEmpty)
            Text(huiText('No custom waypoint styles.')),
          for (int index = 0; index < active.waypointStyles.length; index++)
            _style(active.waypointStyles[index], index),
          _button(
            'Add waypoint style',
            (GlossGlyphDoc doc) => doc.waypointStyles.add(
              GlossWaypointStyleAsset(
                id: _nextId('style', <String>{
                  for (final GlossWaypointStyleAsset style
                      in doc.waypointStyles)
                    style.id,
                }),
                sprites: <GlossWaypointSprite>[GlossWaypointSprite()],
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _glyph(GlossGlyph glyph, int index) => InspectorSection(
    title: glyph.id,
    children: <Widget>[
      _text(
        'Glyph ID',
        glyph.id,
        (GlossGlyphDoc doc, String value) => doc.glyphs[index].id = value,
      ),
      _text(
        'Glyph image',
        glyph.image,
        (GlossGlyphDoc doc, String value) => doc.glyphs[index].image = value,
      ),
      _number(
        'Height',
        glyph.height,
        (GlossGlyphDoc doc, double value) =>
            doc.glyphs[index].height = value.toInt(),
      ),
      _number(
        'Ascent',
        glyph.ascent,
        (GlossGlyphDoc doc, double value) =>
            doc.glyphs[index].ascent = value.toInt(),
      ),
      _number(
        'Frames',
        glyph.frames,
        (GlossGlyphDoc doc, double value) =>
            doc.glyphs[index].frames = value.toInt(),
      ),
      _text(
        'Emoji',
        glyph.emoji,
        (GlossGlyphDoc doc, String value) => doc.glyphs[index].emoji = value,
      ),
      _text(
        'Fallback text',
        glyph.fallback,
        (GlossGlyphDoc doc, String value) => doc.glyphs[index].fallback = value,
      ),
      HuiSwitchRow(
        label: huiText('Override width'),
        value: glyph.width != null,
        onChanged: (bool value) => _edit(
          'glyph width',
          (GlossGlyphDoc doc) => doc.glyphs[index].width = value ? 8 : null,
        ),
      ),
      if (glyph.width != null)
        _number(
          'Width',
          glyph.width!,
          (GlossGlyphDoc doc, double value) =>
              doc.glyphs[index].width = value.toInt(),
        ),
      _button(
        'Remove glyph',
        (GlossGlyphDoc doc) => doc.glyphs.removeAt(index),
      ),
    ],
  );

  Widget _overlay(GlossGlyphOverlay overlay, int index) => InspectorSection(
    title: overlay.id,
    children: <Widget>[
      _text(
        'Overlay ID',
        overlay.id,
        (GlossGlyphDoc doc, String value) => doc.overlays[index].id = value,
      ),
      _text(
        'Overlay image',
        overlay.image,
        (GlossGlyphDoc doc, String value) => doc.overlays[index].image = value,
      ),
      _number(
        'Height',
        overlay.height,
        (GlossGlyphDoc doc, double value) =>
            doc.overlays[index].height = value.toInt(),
      ),
      _number(
        'Ascent',
        overlay.ascent,
        (GlossGlyphDoc doc, double value) =>
            doc.overlays[index].ascent = value.toInt(),
      ),
      HuiField(
        label: huiText('Anchor'),
        control: ArcaneSelect(
          value: overlay.anchor,
          options: const <ArcaneSelectOption>[
            ArcaneSelectOption(value: 'top', label: 'top'),
            ArcaneSelectOption(value: 'center', label: 'center'),
            ArcaneSelectOption(value: 'bottom', label: 'bottom'),
          ],
          onChanged: (String value) => _edit(
            'overlay anchor',
            (GlossGlyphDoc doc) => doc.overlays[index].anchor = value,
          ),
        ),
      ),
      _button(
        'Remove overlay',
        (GlossGlyphDoc doc) => doc.overlays.removeAt(index),
      ),
    ],
  );

  Widget _style(GlossWaypointStyleAsset style, int index) => InspectorSection(
    title: style.id,
    children: <Widget>[
      _text(
        'Style ID',
        style.id,
        (GlossGlyphDoc doc, String value) =>
            doc.waypointStyles[index].id = value,
      ),
      _number(
        'Near distance',
        style.nearDistance,
        (GlossGlyphDoc doc, double value) =>
            doc.waypointStyles[index].nearDistance = value,
      ),
      _number(
        'Far distance',
        style.farDistance,
        (GlossGlyphDoc doc, double value) =>
            doc.waypointStyles[index].farDistance = value,
      ),
      for (int sprite = 0; sprite < style.sprites.length; sprite++) ...<Widget>[
        _text(
          'Sprite ID',
          style.sprites[sprite].id,
          (GlossGlyphDoc doc, String value) =>
              doc.waypointStyles[index].sprites[sprite].id = value,
        ),
        _text(
          'Sprite image',
          style.sprites[sprite].image,
          (GlossGlyphDoc doc, String value) =>
              doc.waypointStyles[index].sprites[sprite].image = value,
        ),
        _button(
          'Remove sprite',
          (GlossGlyphDoc doc) =>
              doc.waypointStyles[index].sprites.removeAt(sprite),
        ),
      ],
      _button(
        'Add sprite',
        (GlossGlyphDoc doc) => doc.waypointStyles[index].sprites.add(
          GlossWaypointSprite(
            id: _nextId('sprite', <String>{
              for (final GlossWaypointSprite sprite
                  in doc.waypointStyles[index].sprites)
                sprite.id,
            }),
          ),
        ),
      ),
      _button(
        'Remove waypoint style',
        (GlossGlyphDoc doc) => doc.waypointStyles.removeAt(index),
      ),
    ],
  );

  String _nextId(String prefix, Set<String> ids) {
    int number = 1;
    while (ids.contains('$prefix-$number')) {
      number++;
    }
    return '$prefix-$number';
  }
}

class GlyphView extends StatelessWidget {
  const GlyphView({required this.store, super.key});
  final EditorStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (BuildContext context) {
      final GlossDoc? doc = store.glossDoc;
      if (doc is! GlossGlyphDoc) return const dom.div(<Widget>[]);
      return dom.div(classes: 'hui-inspector-body', <Widget>[
        InspectorSection(
          title: '${doc.namespace}:${doc.font}',
          children: <Widget>[
            Text(
              huiText(
                'Bitmap paths are relative to images/. Build and offer the resource pack from the server to use these assets.',
              ),
            ),
            if (doc.glyphs.isEmpty &&
                doc.overlays.isEmpty &&
                doc.waypointStyles.isEmpty)
              Text(
                huiText(
                  'This font collection has no images. Add glyphs, overlays or waypoint styles in the inspector.',
                ),
              ),
            for (final GlossGlyph glyph in doc.glyphs)
              HuiField(
                label: glyph.id,
                control: Text(
                  '${glyph.image} · ${glyph.frames} frames · ${glyph.height}px',
                ),
              ),
            for (final GlossGlyphOverlay overlay in doc.overlays)
              HuiField(
                label: overlay.id,
                control: Text('${overlay.image} · ${overlay.anchor}'),
              ),
            for (final GlossWaypointStyleAsset style in doc.waypointStyles)
              HuiField(
                label: '${doc.namespace}:${style.id}',
                control: Text(
                  '${style.sprites.length} sprites · ${style.nearDistance}–${style.farDistance}',
                ),
              ),
          ],
        ),
      ]);
    },
  );
}
