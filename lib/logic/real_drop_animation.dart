library;

import 'dart:math' as math;

import '../model/gloss_real_drop_animation.dart';

final class RealDropActiveAnimationClip {
  const RealDropActiveAnimationClip(this.trigger, this.elapsedTicks);

  final GlossRealDropAnimationTrigger trigger;
  final double elapsedTicks;
}

final class RealDropAnimationSample {
  const RealDropAnimationSample({
    required this.profileId,
    required this.offsetX,
    required this.offsetY,
    required this.offsetZ,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.glowArgb,
    required this.visible,
    required this.physics,
    required this.lightLevel,
  });

  static const RealDropAnimationSample neutral = RealDropAnimationSample(
    profileId: '',
    offsetX: 0,
    offsetY: 0,
    offsetZ: 0,
    rotationX: 0,
    rotationY: 0,
    rotationZ: 0,
    scaleX: 1,
    scaleY: 1,
    scaleZ: 1,
    glowArgb: 0,
    visible: true,
    physics: true,
    lightLevel: 0,
  );

  final String profileId;
  final double offsetX;
  final double offsetY;
  final double offsetZ;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double scaleX;
  final double scaleY;
  final double scaleZ;
  final int glowArgb;
  final bool visible;
  final bool physics;
  final int lightLevel;
}

final class RealDropAnimationPlan {
  RealDropAnimationPlan(GlossRealDropAnimation? animation)
    : _animation = animation,
      _profiles = _sortedProfiles(animation?.profiles ?? const []);

  final GlossRealDropAnimation? _animation;
  final List<_IndexedProfile> _profiles;

  bool get enabled => _animation?.enabled ?? false;

  String profileId(String material) => _profile(material)?.profile.id ?? '';

  RealDropAnimationSample sample(
    String material,
    List<RealDropActiveAnimationClip> activeClips,
  ) {
    if (!enabled || activeClips.isEmpty) return RealDropAnimationSample.neutral;
    final _IndexedProfile? selected = _profile(material);
    if (selected == null) return RealDropAnimationSample.neutral;
    final List<double> values = <double>[0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0];
    final String normalized = _normalizeMaterial(material);
    for (final RealDropActiveAnimationClip active in activeClips) {
      for (final GlossRealDropAnimationClip clip in selected.profile.clips) {
        if (clip.trigger != active.trigger) continue;
        _applyClip(clip, normalized, active.elapsedTicks, values);
      }
    }
    return RealDropAnimationSample(
      profileId: selected.profile.id,
      offsetX: values[GlossRealDropAnimationTarget.offsetX.index],
      offsetY: values[GlossRealDropAnimationTarget.offsetY.index],
      offsetZ: values[GlossRealDropAnimationTarget.offsetZ.index],
      rotationX: values[GlossRealDropAnimationTarget.rotationX.index],
      rotationY: values[GlossRealDropAnimationTarget.rotationY.index],
      rotationZ: values[GlossRealDropAnimationTarget.rotationZ.index],
      scaleX: values[GlossRealDropAnimationTarget.scaleX.index].clamp(0, 16),
      scaleY: values[GlossRealDropAnimationTarget.scaleY.index].clamp(0, 16),
      scaleZ: values[GlossRealDropAnimationTarget.scaleZ.index].clamp(0, 16),
      glowArgb: values[GlossRealDropAnimationTarget.glow.index]
          .round()
          .toUnsigned(32),
      visible: values[GlossRealDropAnimationTarget.visible.index] >= 0.5,
      physics: values[GlossRealDropAnimationTarget.physics.index] >= 0.5,
      lightLevel: values[GlossRealDropAnimationTarget.lightLevel.index]
          .clamp(0, 15)
          .round(),
    );
  }

  _IndexedProfile? _profile(String material) {
    final String normalized = _normalizeMaterial(material);
    for (final _IndexedProfile profile in _profiles) {
      for (final String pattern in profile.profile.materials) {
        if (_glob(pattern).hasMatch(normalized)) return profile;
      }
    }
    return null;
  }

  void _applyClip(
    GlossRealDropAnimationClip clip,
    String material,
    double elapsedTicks,
    List<double> values,
  ) {
    double tick = math.max(0, elapsedTicks);
    if (clip.loop && clip.durationTicks > 0) {
      tick %= clip.durationTicks;
    } else {
      tick = math.min(clip.durationTicks, tick);
    }
    for (final GlossRealDropAnimationTrack track in clip.tracks) {
      if (track.keyframes.isEmpty) continue;
      final double value = _trackValue(track, material, tick);
      final int index = track.target.index;
      values[index] = switch (track.blend) {
        GlossRealDropAnimationBlend.add => values[index] + value,
        GlossRealDropAnimationBlend.replace => value,
        GlossRealDropAnimationBlend.multiply => values[index] * value,
      };
    }
  }

  double _trackValue(
    GlossRealDropAnimationTrack track,
    String material,
    double tick,
  ) {
    final List<GlossRealDropAnimationKeyframe> frames =
        List<GlossRealDropAnimationKeyframe>.of(track.keyframes)..sort(
          (
            GlossRealDropAnimationKeyframe first,
            GlossRealDropAnimationKeyframe second,
          ) => first.tick.compareTo(second.tick),
        );
    final GlossRealDropAnimationKeyframe first = frames.first;
    if (tick <= first.tick || frames.length == 1) {
      return _frameValue(first, track.target, material);
    }
    GlossRealDropAnimationKeyframe previous = first;
    for (int index = 1; index < frames.length; index++) {
      final GlossRealDropAnimationKeyframe next = frames[index];
      if (tick <= next.tick) {
        final double span = next.tick - previous.tick;
        final double progress = span <= 0 ? 1 : (tick - previous.tick) / span;
        final double eased = realDropAnimationEase(next.easing, progress);
        final double from = _frameValue(previous, track.target, material);
        final double to = _frameValue(next, track.target, material);
        return from + (to - from) * eased;
      }
      previous = next;
    }
    return _frameValue(frames.last, track.target, material);
  }

  double _frameValue(
    GlossRealDropAnimationKeyframe frame,
    GlossRealDropAnimationTarget target,
    String material,
  ) {
    if (frame.materialMap.isEmpty ||
        (target != GlossRealDropAnimationTarget.glow &&
            target != GlossRealDropAnimationTarget.lightLevel)) {
      return frame.value;
    }
    final Map<String, GlossRealDropMaterialProperties>? propertyMap =
        _animation?.materialProperties[frame.materialMap];
    if (propertyMap == null) return frame.value;
    for (final MapEntry<String, GlossRealDropMaterialProperties> entry
        in propertyMap.entries) {
      if (!_glob(entry.key).hasMatch(material)) continue;
      return target == GlossRealDropAnimationTarget.glow
          ? entry.value.glow
          : entry.value.lightLevel;
    }
    return frame.value;
  }

  static List<_IndexedProfile> _sortedProfiles(
    List<GlossRealDropAnimationProfile> profiles,
  ) {
    final List<_IndexedProfile> sorted = <_IndexedProfile>[
      for (int index = 0; index < profiles.length; index++)
        _IndexedProfile(profiles[index], index),
    ];
    sorted.sort((_IndexedProfile first, _IndexedProfile second) {
      final int priority = second.profile.priority.compareTo(
        first.profile.priority,
      );
      return priority != 0 ? priority : first.order.compareTo(second.order);
    });
    return sorted;
  }
}

double realDropAnimationEase(
  GlossRealDropAnimationEasing easing,
  double progress,
) {
  final double selected = progress.clamp(0, 1);
  return switch (easing) {
    GlossRealDropAnimationEasing.hold => 0,
    GlossRealDropAnimationEasing.linear => selected,
    GlossRealDropAnimationEasing.easeIn => selected * selected * selected,
    GlossRealDropAnimationEasing.easeOut =>
      1 - math.pow(1 - selected, 3).toDouble(),
    GlossRealDropAnimationEasing.easeInOut =>
      selected < 0.5
          ? 4 * selected * selected * selected
          : 1 - math.pow(-2 * selected + 2, 3).toDouble() / 2,
    GlossRealDropAnimationEasing.backOut =>
      1 +
          2.70158 * math.pow(selected - 1, 3).toDouble() +
          1.70158 * math.pow(selected - 1, 2).toDouble(),
  };
}

String _normalizeMaterial(String material) {
  final String trimmed = material.trim();
  final int namespace = trimmed.indexOf(':');
  return (namespace >= 0 ? trimmed.substring(namespace + 1) : trimmed)
      .toUpperCase();
}

RegExp _glob(String source) {
  final String normalized = _normalizeMaterial(source);
  final StringBuffer pattern = StringBuffer('^');
  for (int index = 0; index < normalized.length; index++) {
    final String character = normalized[index];
    if (character == '*') {
      pattern.write('.*');
    } else if (character == '?') {
      pattern.write('.');
    } else {
      pattern.write(RegExp.escape(character));
    }
  }
  pattern.write(r'$');
  return RegExp(pattern.toString());
}

final class _IndexedProfile {
  const _IndexedProfile(this.profile, this.order);

  final GlossRealDropAnimationProfile profile;
  final int order;
}
