library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

class RealDropAnimationInspector extends StatelessWidget {
  const RealDropAnimationInspector({required this.store, super.key});

  final EditorStore store;

  GlossRealDropSettingsDoc? get _doc => store.realDropSettingsDoc;

  @override
  Widget build(BuildContext context) {
    final GlossRealDropAnimation? animation = _doc?.animation;
    return InspectorSection(
      title: 'Animation authoring',
      sectionKey: 'realDrops.animation',
      description:
          'Material profiles select trigger clips. Typed tracks animate '
          'display transforms, visibility, physics gating, glow and light.',
      trailing: const HuiFieldHelp('realDrops.animation'),
      children: <Widget>[
        HuiSwitchRow(
          label: 'Run animation profiles',
          value: animation?.enabled ?? false,
          onChanged: (bool value) => _mutate(
            'drop animation',
            (GlossRealDropAnimation edited) => edited.enabled = value,
          ),
        ),
        _materialProperties(animation),
        _profiles(animation),
      ],
    );
  }

  Widget _materialProperties(GlossRealDropAnimation? animation) {
    final List<MapEntry<String, Map<String, GlossRealDropMaterialProperties>>>
    maps = animation?.materialProperties.entries.toList() ?? const [];
    return dom.div(classes: 'hui-drop-animation-group', <Widget>[
      const dom.div(classes: 'hui-drop-subhead', <Widget>[
        Text('Material properties'),
        HuiFieldHelp('realDrops.animation.materialProperties'),
      ]),
      for (int mapIndex = 0; mapIndex < maps.length; mapIndex++)
        _propertyMap(maps, mapIndex),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: () => _mutate('add material property map', (
          GlossRealDropAnimation edited,
        ) {
          final String name = _freshName(
            'properties',
            edited.materialProperties.keys,
          );
          edited.materialProperties[name] =
              <String, GlossRealDropMaterialProperties>{
                '*': GlossRealDropMaterialProperties(),
              };
        }),
        child: const Text('Add property map'),
      ),
    ]);
  }

  Widget _propertyMap(
    List<MapEntry<String, Map<String, GlossRealDropMaterialProperties>>> maps,
    int mapIndex,
  ) {
    final MapEntry<String, Map<String, GlossRealDropMaterialProperties>> map =
        maps[mapIndex];
    final List<MapEntry<String, GlossRealDropMaterialProperties>> entries = map
        .value
        .entries
        .toList();
    return dom.details(classes: 'hui-drop-animation-card', <Widget>[
      dom.summary(<Widget>[Text('${map.key} · ${entries.length} materials')]),
      dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
        _text(
          'Map name',
          map.key,
          (String value) => _mutate('rename material property map', (
            GlossRealDropAnimation edited,
          ) {
            final Map<String, GlossRealDropMaterialProperties>? moved = edited
                .materialProperties
                .remove(map.key);
            if (moved != null) edited.materialProperties[value.trim()] = moved;
          }),
        ),
        for (int entryIndex = 0; entryIndex < entries.length; entryIndex++)
          _propertyEntry(map.key, entries, entryIndex),
        dom.div(classes: 'hui-drop-animation-actions', <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => _mutate('add material property', (
              GlossRealDropAnimation edited,
            ) {
              final Map<String, GlossRealDropMaterialProperties> target =
                  edited.materialProperties[map.key]!;
              target[_freshName('MATERIAL', target.keys)] =
                  GlossRealDropMaterialProperties();
            }),
            child: const Text('Add material'),
          ),
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            onPressed: () => _mutate(
              'remove material property map',
              (GlossRealDropAnimation edited) =>
                  edited.materialProperties.remove(map.key),
            ),
            child: const Text('Remove map'),
          ),
        ]),
      ]),
    ]);
  }

  Widget _propertyEntry(
    String mapName,
    List<MapEntry<String, GlossRealDropMaterialProperties>> entries,
    int entryIndex,
  ) {
    final MapEntry<String, GlossRealDropMaterialProperties> entry =
        entries[entryIndex];
    return dom.div(classes: 'hui-drop-animation-row is-material', <Widget>[
      _text(
        'Material glob',
        entry.key,
        (String value) => _mutate('edit material property glob', (
          GlossRealDropAnimation edited,
        ) {
          final Map<String, GlossRealDropMaterialProperties> target =
              edited.materialProperties[mapName]!;
          final GlossRealDropMaterialProperties? moved = target.remove(
            entry.key,
          );
          if (moved != null) target[value.trim()] = moved;
        }),
      ),
      _number(
        'Glow ARGB',
        entry.value.glow,
        (double value) => _mutate(
          'edit material glow',
          (GlossRealDropAnimation edited) =>
              edited.materialProperties[mapName]![entry.key]!.glow = value,
        ),
      ),
      _number(
        'Light 0..15',
        entry.value.lightLevel,
        (double value) => _mutate(
          'edit material light',
          (GlossRealDropAnimation edited) =>
              edited.materialProperties[mapName]![entry.key]!.lightLevel =
                  value,
        ),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => _mutate(
          'remove material property',
          (GlossRealDropAnimation edited) =>
              edited.materialProperties[mapName]!.remove(entry.key),
        ),
        child: const Text('Remove'),
      ),
    ]);
  }

  Widget _profiles(GlossRealDropAnimation? animation) {
    final List<GlossRealDropAnimationProfile> profiles =
        animation?.profiles ?? const <GlossRealDropAnimationProfile>[];
    return dom.div(classes: 'hui-drop-animation-group', <Widget>[
      const dom.div(classes: 'hui-drop-subhead', <Widget>[
        Text('Profiles and clips'),
        HuiFieldHelp('realDrops.animation.profiles'),
      ]),
      for (int profileIndex = 0; profileIndex < profiles.length; profileIndex++)
        _profile(profiles[profileIndex], profileIndex),
      dom.div(classes: 'hui-drop-animation-actions', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _mutate('add hover release sequence', (
            GlossRealDropAnimation edited,
          ) {
            final String id = _freshName(
              'hover-showcase',
              edited.profiles.map(
                (GlossRealDropAnimationProfile profile) => profile.id,
              ),
            );
            edited.enabled = true;
            edited.profiles.add(_hoverReleaseProfile(id));
          }),
          child: const Text('Add hover/release sequence'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _mutate(
            'add animation profile',
            (GlossRealDropAnimation edited) => edited.profiles.add(
              GlossRealDropAnimationProfile(
                id: _freshName(
                  'profile',
                  edited.profiles.map(
                    (GlossRealDropAnimationProfile profile) => profile.id,
                  ),
                ),
              ),
            ),
          ),
          child: const Text('Add profile'),
        ),
      ]),
    ]);
  }

  Widget _profile(
    GlossRealDropAnimationProfile profile,
    int profileIndex,
  ) => dom.details(classes: 'hui-drop-animation-card', <Widget>[
    dom.summary(<Widget>[Text('${profile.id} · priority ${profile.priority}')]),
    dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
      _text(
        'Profile id',
        profile.id,
        (String value) => _editProfile(
          profileIndex,
          'rename animation profile',
          (GlossRealDropAnimationProfile edited) => edited.id = value,
        ),
      ),
      _number(
        'Priority',
        profile.priority.toDouble(),
        (double value) => _editProfile(
          profileIndex,
          'edit animation profile priority',
          (GlossRealDropAnimationProfile edited) =>
              edited.priority = value.round(),
        ),
      ),
      _text(
        'Material globs',
        profile.materials.join(', '),
        (String value) => _editProfile(
          profileIndex,
          'edit animation profile materials',
          (GlossRealDropAnimationProfile edited) =>
              edited.materials = _split(value),
        ),
      ),
      for (int clipIndex = 0; clipIndex < profile.clips.length; clipIndex++)
        _clip(profile.clips[clipIndex], profileIndex, clipIndex),
      dom.div(classes: 'hui-drop-animation-actions', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _editProfile(
            profileIndex,
            'add animation clip',
            (GlossRealDropAnimationProfile edited) =>
                edited.clips.add(GlossRealDropAnimationClip(durationTicks: 20)),
          ),
          child: const Text('Add clip'),
        ),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          onPressed: () => _mutate(
            'remove animation profile',
            (GlossRealDropAnimation edited) =>
                edited.profiles.removeAt(profileIndex),
          ),
          child: const Text('Remove profile'),
        ),
      ]),
    ]),
  ]);

  Widget _clip(
    GlossRealDropAnimationClip clip,
    int profileIndex,
    int clipIndex,
  ) => dom.details(classes: 'hui-drop-animation-card is-clip', <Widget>[
    dom.summary(<Widget>[
      Text('${clip.trigger.wire} · ${clip.durationTicks} ticks'),
    ]),
    dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
      _select(
        'Trigger',
        clip.trigger.wire,
        <String>[
          for (final GlossRealDropAnimationTrigger value
              in GlossRealDropAnimationTrigger.values)
            value.wire,
        ],
        (String value) => _editClip(
          profileIndex,
          clipIndex,
          'edit animation trigger',
          (GlossRealDropAnimationClip edited) =>
              edited.trigger = GlossRealDropAnimationTrigger.parse(value),
        ),
      ),
      _number(
        'Duration ticks',
        clip.durationTicks,
        (double value) => _editClip(
          profileIndex,
          clipIndex,
          'edit animation duration',
          (GlossRealDropAnimationClip edited) => edited.durationTicks = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Loop clip',
        value: clip.loop,
        onChanged: (bool value) => _editClip(
          profileIndex,
          clipIndex,
          'toggle animation loop',
          (GlossRealDropAnimationClip edited) => edited.loop = value,
        ),
      ),
      for (int trackIndex = 0; trackIndex < clip.tracks.length; trackIndex++)
        _track(clip.tracks[trackIndex], profileIndex, clipIndex, trackIndex),
      dom.div(classes: 'hui-drop-animation-actions', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _editClip(
            profileIndex,
            clipIndex,
            'add animation track',
            (GlossRealDropAnimationClip edited) => edited.tracks.add(
              GlossRealDropAnimationTrack(
                keyframes: <GlossRealDropAnimationKeyframe>[
                  GlossRealDropAnimationKeyframe(),
                  GlossRealDropAnimationKeyframe(tick: edited.durationTicks),
                ],
              ),
            ),
          ),
          child: const Text('Add track'),
        ),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          onPressed: () => _editProfile(
            profileIndex,
            'remove animation clip',
            (GlossRealDropAnimationProfile edited) =>
                edited.clips.removeAt(clipIndex),
          ),
          child: const Text('Remove clip'),
        ),
      ]),
    ]),
  ]);

  Widget _track(
    GlossRealDropAnimationTrack track,
    int profileIndex,
    int clipIndex,
    int trackIndex,
  ) => dom.details(classes: 'hui-drop-animation-card is-track', <Widget>[
    dom.summary(<Widget>[Text('${track.target.wire} · ${track.blend.wire}')]),
    dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
      _select(
        'Target',
        track.target.wire,
        <String>[
          for (final GlossRealDropAnimationTarget value
              in GlossRealDropAnimationTarget.values)
            value.wire,
        ],
        (String value) => _editTrack(
          profileIndex,
          clipIndex,
          trackIndex,
          'edit animation target',
          (GlossRealDropAnimationTrack edited) =>
              edited.target = GlossRealDropAnimationTarget.parse(value),
        ),
      ),
      _select(
        'Blend',
        track.blend.wire,
        <String>[
          for (final GlossRealDropAnimationBlend value
              in GlossRealDropAnimationBlend.values)
            value.wire,
        ],
        (String value) => _editTrack(
          profileIndex,
          clipIndex,
          trackIndex,
          'edit animation blend',
          (GlossRealDropAnimationTrack edited) =>
              edited.blend = GlossRealDropAnimationBlend.parse(value),
        ),
      ),
      for (
        int frameIndex = 0;
        frameIndex < track.keyframes.length;
        frameIndex++
      )
        _keyframe(
          track.keyframes[frameIndex],
          profileIndex,
          clipIndex,
          trackIndex,
          frameIndex,
        ),
      dom.div(classes: 'hui-drop-animation-actions', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _editTrack(
            profileIndex,
            clipIndex,
            trackIndex,
            'add animation keyframe',
            (GlossRealDropAnimationTrack edited) =>
                edited.keyframes.add(GlossRealDropAnimationKeyframe()),
          ),
          child: const Text('Add keyframe'),
        ),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          onPressed: () => _editClip(
            profileIndex,
            clipIndex,
            'remove animation track',
            (GlossRealDropAnimationClip edited) =>
                edited.tracks.removeAt(trackIndex),
          ),
          child: const Text('Remove track'),
        ),
      ]),
    ]),
  ]);

  Widget _keyframe(
    GlossRealDropAnimationKeyframe frame,
    int profileIndex,
    int clipIndex,
    int trackIndex,
    int frameIndex,
  ) => dom.div(classes: 'hui-drop-animation-row is-keyframe', <Widget>[
    _number(
      'Tick',
      frame.tick,
      (double value) => _editFrame(
        profileIndex,
        clipIndex,
        trackIndex,
        frameIndex,
        'edit animation keyframe tick',
        (GlossRealDropAnimationKeyframe edited) => edited.tick = value,
      ),
    ),
    _number(
      'Value',
      frame.value,
      (double value) => _editFrame(
        profileIndex,
        clipIndex,
        trackIndex,
        frameIndex,
        'edit animation keyframe value',
        (GlossRealDropAnimationKeyframe edited) => edited.value = value,
      ),
    ),
    _select(
      'Easing',
      frame.easing.wire,
      <String>[
        for (final GlossRealDropAnimationEasing value
            in GlossRealDropAnimationEasing.values)
          value.wire,
      ],
      (String value) => _editFrame(
        profileIndex,
        clipIndex,
        trackIndex,
        frameIndex,
        'edit animation keyframe easing',
        (GlossRealDropAnimationKeyframe edited) =>
            edited.easing = GlossRealDropAnimationEasing.parse(value),
      ),
    ),
    _text(
      'Material map',
      frame.materialMap,
      (String value) => _editFrame(
        profileIndex,
        clipIndex,
        trackIndex,
        frameIndex,
        'edit animation material map',
        (GlossRealDropAnimationKeyframe edited) =>
            edited.materialMap = value.trim(),
      ),
    ),
    Button(
      variant: ButtonVariant.ghost,
      size: ButtonSize.sm,
      onPressed: () => _editTrack(
        profileIndex,
        clipIndex,
        trackIndex,
        'remove animation keyframe',
        (GlossRealDropAnimationTrack edited) =>
            edited.keyframes.removeAt(frameIndex),
      ),
      child: const Text('Remove'),
    ),
  ]);

  Widget _text(
    String label,
    String value,
    void Function(String value) changed,
  ) => HuiField(
    label: label,
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      onInput: changed,
    ),
  );

  Widget _number(
    String label,
    double value,
    void Function(double value) changed,
  ) => HuiField(
    label: label,
    control: HuiNumberField(
      value: value,
      step: 0.05,
      decimals: 2,
      onChanged: changed,
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> values,
    void Function(String value) changed,
  ) => HuiField(
    label: label,
    control: ArcaneSelect(
      value: value,
      fullWidth: true,
      size: ComponentSize.sm,
      onChange: changed,
      options: <ArcaneSelectOption>[
        for (final String option in values)
          ArcaneSelectOption(label: option, value: option),
      ],
    ),
  );

  void _mutate(
    String label,
    void Function(GlossRealDropAnimation animation) change,
  ) => store.mutateRealDropSettings(
    label,
    (GlossRealDropSettingsDoc doc) =>
        change(doc.animation ??= GlossRealDropAnimation()),
  );

  void _editProfile(
    int profile,
    String label,
    void Function(GlossRealDropAnimationProfile profile) change,
  ) => _mutate(
    label,
    (GlossRealDropAnimation animation) => change(animation.profiles[profile]),
  );

  void _editClip(
    int profile,
    int clip,
    String label,
    void Function(GlossRealDropAnimationClip clip) change,
  ) => _editProfile(
    profile,
    label,
    (GlossRealDropAnimationProfile edited) => change(edited.clips[clip]),
  );

  void _editTrack(
    int profile,
    int clip,
    int track,
    String label,
    void Function(GlossRealDropAnimationTrack track) change,
  ) => _editClip(
    profile,
    clip,
    label,
    (GlossRealDropAnimationClip edited) => change(edited.tracks[track]),
  );

  void _editFrame(
    int profile,
    int clip,
    int track,
    int frame,
    String label,
    void Function(GlossRealDropAnimationKeyframe frame) change,
  ) => _editTrack(
    profile,
    clip,
    track,
    label,
    (GlossRealDropAnimationTrack edited) => change(edited.keyframes[frame]),
  );

  static List<String> _split(String value) => value
      .split(',')
      .map((String entry) => entry.trim())
      .where((String entry) => entry.isNotEmpty)
      .toList();

  static String _freshName(String prefix, Iterable<String> existing) {
    final Set<String> names = existing.toSet();
    for (int index = 1; ; index++) {
      final String name = '$prefix$index';
      if (!names.contains(name)) return name;
    }
  }

  static GlossRealDropAnimationProfile _hoverReleaseProfile(
    String id,
  ) => GlossRealDropAnimationProfile(
    id: id,
    priority: 100,
    materials: <String>['*'],
    clips: <GlossRealDropAnimationClip>[
      GlossRealDropAnimationClip(
        trigger: GlossRealDropAnimationTrigger.spawn,
        durationTicks: 60,
        tracks: <GlossRealDropAnimationTrack>[
          _showcaseScaleTrack(GlossRealDropAnimationTarget.scaleX),
          _showcaseScaleTrack(GlossRealDropAnimationTarget.scaleY),
          _showcaseScaleTrack(GlossRealDropAnimationTarget.scaleZ),
          GlossRealDropAnimationTrack(
            target: GlossRealDropAnimationTarget.offsetY,
            blend: GlossRealDropAnimationBlend.add,
            keyframes: <GlossRealDropAnimationKeyframe>[
              GlossRealDropAnimationKeyframe(tick: 0, value: 0),
              GlossRealDropAnimationKeyframe(
                tick: 8,
                value: 2,
                easing: GlossRealDropAnimationEasing.easeOut,
              ),
              GlossRealDropAnimationKeyframe(
                tick: 36,
                value: 2,
                easing: GlossRealDropAnimationEasing.hold,
              ),
              GlossRealDropAnimationKeyframe(
                tick: 60,
                value: 0,
                easing: GlossRealDropAnimationEasing.easeIn,
              ),
            ],
          ),
          GlossRealDropAnimationTrack(
            target: GlossRealDropAnimationTarget.physics,
            blend: GlossRealDropAnimationBlend.replace,
            keyframes: <GlossRealDropAnimationKeyframe>[
              GlossRealDropAnimationKeyframe(
                tick: 0,
                value: 0,
                easing: GlossRealDropAnimationEasing.hold,
              ),
              GlossRealDropAnimationKeyframe(
                tick: 36,
                value: 0,
                easing: GlossRealDropAnimationEasing.hold,
              ),
              GlossRealDropAnimationKeyframe(tick: 37, value: 1),
            ],
          ),
          _showcaseRotationTrack(GlossRealDropAnimationTarget.rotationX, 1080),
          _showcaseRotationTrack(GlossRealDropAnimationTarget.rotationY, 1440),
        ],
      ),
    ],
  );

  static GlossRealDropAnimationTrack _showcaseScaleTrack(
    GlossRealDropAnimationTarget target,
  ) => GlossRealDropAnimationTrack(
    target: target,
    blend: GlossRealDropAnimationBlend.multiply,
    keyframes: <GlossRealDropAnimationKeyframe>[
      GlossRealDropAnimationKeyframe(tick: 0, value: 4),
      GlossRealDropAnimationKeyframe(
        tick: 6,
        value: 0.15,
        easing: GlossRealDropAnimationEasing.easeIn,
      ),
      GlossRealDropAnimationKeyframe(
        tick: 12,
        value: 4,
        easing: GlossRealDropAnimationEasing.backOut,
      ),
      GlossRealDropAnimationKeyframe(
        tick: 20,
        value: 1,
        easing: GlossRealDropAnimationEasing.easeOut,
      ),
    ],
  );

  static GlossRealDropAnimationTrack _showcaseRotationTrack(
    GlossRealDropAnimationTarget target,
    double degrees,
  ) => GlossRealDropAnimationTrack(
    target: target,
    blend: GlossRealDropAnimationBlend.add,
    keyframes: <GlossRealDropAnimationKeyframe>[
      GlossRealDropAnimationKeyframe(tick: 0, value: 0),
      GlossRealDropAnimationKeyframe(
        tick: 60,
        value: degrees,
        easing: GlossRealDropAnimationEasing.easeInOut,
      ),
    ],
  );
}
