library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

String _animationTriggerLabel(GlossRealDropAnimationTrigger trigger) =>
    switch (trigger) {
      GlossRealDropAnimationTrigger.spawn => huiText('Spawn'),
      GlossRealDropAnimationTrigger.airborne => huiText('Airborne'),
      GlossRealDropAnimationTrigger.rebounding => huiText('Rebounding'),
      GlossRealDropAnimationTrigger.rolling => huiText('Rolling'),
      GlossRealDropAnimationTrigger.sliding => huiText('Sliding'),
      GlossRealDropAnimationTrigger.settling => huiText('Settling'),
      GlossRealDropAnimationTrigger.settled => huiText('Settled'),
      GlossRealDropAnimationTrigger.submerged => huiText('Submerged'),
      GlossRealDropAnimationTrigger.floating => huiText('Floating'),
      GlossRealDropAnimationTrigger.impact => huiText('Impact'),
      GlossRealDropAnimationTrigger.bounce => huiText('Bounce'),
      GlossRealDropAnimationTrigger.enterFluid => huiText('Enter fluid'),
      GlossRealDropAnimationTrigger.exitFluid => huiText('Exit fluid'),
      GlossRealDropAnimationTrigger.startRoll => huiText('Start roll'),
      GlossRealDropAnimationTrigger.settle => huiText('Settle'),
      GlossRealDropAnimationTrigger.wake => huiText('Wake'),
    };

String _animationTargetLabel(GlossRealDropAnimationTarget target) =>
    switch (target) {
      GlossRealDropAnimationTarget.offsetX => huiText('Offset X'),
      GlossRealDropAnimationTarget.offsetY => huiText('Offset Y'),
      GlossRealDropAnimationTarget.offsetZ => huiText('Offset Z'),
      GlossRealDropAnimationTarget.rotationX => huiText('Rotation X'),
      GlossRealDropAnimationTarget.rotationY => huiText('Rotation Y'),
      GlossRealDropAnimationTarget.rotationZ => huiText('Rotation Z'),
      GlossRealDropAnimationTarget.scaleX => huiText('Scale X'),
      GlossRealDropAnimationTarget.scaleY => huiText('Scale Y'),
      GlossRealDropAnimationTarget.scaleZ => huiText('Scale Z'),
      GlossRealDropAnimationTarget.glow => huiText('Glow'),
      GlossRealDropAnimationTarget.visible => huiText('Visible'),
      GlossRealDropAnimationTarget.physics => huiText('Physics'),
      GlossRealDropAnimationTarget.lightLevel => huiText('Light level'),
    };

String _animationBlendLabel(GlossRealDropAnimationBlend blend) =>
    switch (blend) {
      GlossRealDropAnimationBlend.add => huiTextKey(
        'animation_blend.add',
        'Add',
      ),
      GlossRealDropAnimationBlend.replace => huiTextKey(
        'animation_blend.replace',
        'Replace',
      ),
      GlossRealDropAnimationBlend.multiply => huiTextKey(
        'animation_blend.multiply',
        'Multiply',
      ),
    };

String _animationEasingLabel(GlossRealDropAnimationEasing easing) =>
    switch (easing) {
      GlossRealDropAnimationEasing.linear => huiText('Linear'),
      GlossRealDropAnimationEasing.hold => huiText('Hold'),
      GlossRealDropAnimationEasing.easeIn => huiText('Ease in'),
      GlossRealDropAnimationEasing.easeOut => huiText('Ease out'),
      GlossRealDropAnimationEasing.easeInOut => huiText('Ease in/out'),
      GlossRealDropAnimationEasing.backOut => huiText('Back out'),
    };

class RealDropAnimationInspector extends StatelessWidget {
  const RealDropAnimationInspector({required this.store, super.key});

  final EditorStore store;

  GlossRealDropSettingsDoc? get _doc => store.realDropSettingsDoc;

  @override
  Widget build(BuildContext context) {
    final GlossRealDropAnimation? animation = _doc?.presentation.animation;
    return InspectorSection(
      title: huiText('Animation authoring'),
      sectionKey: 'realDrops.animation',
      description: huiText(
        'Material profiles select trigger clips. Typed tracks animate '
        'display transforms, visibility, physics gating, glow and light.',
      ),
      trailing: const HuiFieldHelp('realDrops.animation'),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Run animation profiles'),
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
      dom.div(classes: 'hui-drop-subhead', <Widget>[
        Text(huiText('Material properties')),
        const HuiFieldHelp('realDrops.animation.materialProperties'),
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
        child: Text(huiText('Add property map')),
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
      dom.summary(<Widget>[
        Text(
          huiText('{key} · {materials}', <String, Object?>{
            'key': map.key,
            'materials': huiPlural(
              'real_drop.material_count',
              entries.length,
              oneEnglish: '{count} material',
              otherEnglish: '{count} materials',
            ),
          }),
        ),
      ]),
      dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
        _text(
          huiText('Map name'),
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
            child: Text(huiText('Add material')),
          ),
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            onPressed: () => _mutate(
              'remove material property map',
              (GlossRealDropAnimation edited) =>
                  edited.materialProperties.remove(map.key),
            ),
            child: Text(huiText('Remove map')),
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
        huiText('Material glob'),
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
        huiText('Glow ARGB'),
        entry.value.glow,
        (double value) => _mutate(
          'edit material glow',
          (GlossRealDropAnimation edited) =>
              edited.materialProperties[mapName]![entry.key]!.glow = value,
        ),
      ),
      _number(
        huiText('Light 0..15'),
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
        child: Text(huiText('Remove')),
      ),
    ]);
  }

  Widget _profiles(GlossRealDropAnimation? animation) {
    final List<GlossRealDropAnimationProfile> profiles =
        animation?.profiles ?? const <GlossRealDropAnimationProfile>[];
    return dom.div(classes: 'hui-drop-animation-group', <Widget>[
      dom.div(classes: 'hui-drop-subhead', <Widget>[
        Text(huiText('Profiles and clips')),
        const HuiFieldHelp('realDrops.animation.profiles'),
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
          child: Text(huiText('Add hover/release sequence')),
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
          child: Text(huiText('Add profile')),
        ),
      ]),
    ]);
  }

  Widget _profile(GlossRealDropAnimationProfile profile, int profileIndex) =>
      dom.details(classes: 'hui-drop-animation-card', <Widget>[
        dom.summary(<Widget>[
          Text(
            huiText("{id} · priority {priority}", <String, Object?>{
              'id': profile.id,
              'priority': profile.priority,
            }),
          ),
        ]),
        dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
          _text(
            huiText('Profile id'),
            profile.id,
            (String value) => _editProfile(
              profileIndex,
              'rename animation profile',
              (GlossRealDropAnimationProfile edited) => edited.id = value,
            ),
          ),
          _number(
            huiText('Priority'),
            profile.priority.toDouble(),
            (double value) => _editProfile(
              profileIndex,
              'edit animation profile priority',
              (GlossRealDropAnimationProfile edited) =>
                  edited.priority = value.round(),
            ),
          ),
          _text(
            huiText('Material globs'),
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
                (GlossRealDropAnimationProfile edited) => edited.clips.add(
                  GlossRealDropAnimationClip(durationTicks: 20),
                ),
              ),
              child: Text(huiText('Add clip')),
            ),
            Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              onPressed: () => _mutate(
                'remove animation profile',
                (GlossRealDropAnimation edited) =>
                    edited.profiles.removeAt(profileIndex),
              ),
              child: Text(huiText('Remove profile')),
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
      Text(
        huiText("{trigger} · {durationTicks} ticks", <String, Object?>{
          'trigger': _animationTriggerLabel(clip.trigger),
          'durationTicks': clip.durationTicks,
        }),
      ),
    ]),
    dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
      _select(
        huiText('Trigger'),
        clip.trigger.wire,
        <({String label, String value})>[
          for (final GlossRealDropAnimationTrigger value
              in GlossRealDropAnimationTrigger.values)
            (label: _animationTriggerLabel(value), value: value.wire),
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
        huiText('Duration ticks'),
        clip.durationTicks,
        (double value) => _editClip(
          profileIndex,
          clipIndex,
          'edit animation duration',
          (GlossRealDropAnimationClip edited) => edited.durationTicks = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Loop clip'),
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
          child: Text(huiText('Add track')),
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
          child: Text(huiText('Remove clip')),
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
    dom.summary(<Widget>[
      Text(
        huiText("{target} · {blend}", <String, Object?>{
          'target': _animationTargetLabel(track.target),
          'blend': _animationBlendLabel(track.blend),
        }),
      ),
    ]),
    dom.div(classes: 'hui-drop-animation-card-body', <Widget>[
      _select(
        huiText('Target'),
        track.target.wire,
        <({String label, String value})>[
          for (final GlossRealDropAnimationTarget value
              in GlossRealDropAnimationTarget.values)
            (label: _animationTargetLabel(value), value: value.wire),
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
        huiText('Blend'),
        track.blend.wire,
        <({String label, String value})>[
          for (final GlossRealDropAnimationBlend value
              in GlossRealDropAnimationBlend.values)
            (label: _animationBlendLabel(value), value: value.wire),
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
          child: Text(huiText('Add keyframe')),
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
          child: Text(huiText('Remove track')),
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
      huiText('Tick'),
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
      huiText('Value'),
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
      huiText('Easing'),
      frame.easing.wire,
      <({String label, String value})>[
        for (final GlossRealDropAnimationEasing value
            in GlossRealDropAnimationEasing.values)
          (label: _animationEasingLabel(value), value: value.wire),
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
      huiText('Material map'),
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
      child: Text(huiText('Remove')),
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
      styles: huiTechnicalInputStyles,
      onInput: changed,
      attributes: huiTechnicalInputAttributes,
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
    List<({String label, String value})> options,
    void Function(String value) changed,
  ) => HuiField(
    label: label,
    control: ArcaneSelect(
      value: value,
      fullWidth: true,
      size: ComponentSize.sm,
      onChange: changed,
      options: <ArcaneSelectOption>[
        for (final ({String label, String value}) option in options)
          ArcaneSelectOption(label: option.label, value: option.value),
      ],
    ),
  );

  void _mutate(
    String label,
    void Function(GlossRealDropAnimation animation) change,
  ) => store.mutateRealDropSettings(
    label,
    (GlossRealDropSettingsDoc doc) =>
        change(doc.presentation.animation ??= GlossRealDropAnimation()),
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
