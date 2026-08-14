library;

enum RuntimeBoardFollowMode { none, player }

enum RuntimeBoardFollowRotation { fixed, yaw, full }

enum RuntimeBoardVisibilityMode { public, permission, hidden }

final class RuntimeBoardTransform {
  const RuntimeBoardTransform({
    required this.worldKey,
    required this.worldUuid,
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.scale,
  });

  final String worldKey;
  final String worldUuid;
  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;
  final double roll;
  final double scale;

  RuntimeBoardTransform copyWith({
    double? x,
    double? y,
    double? z,
    double? yaw,
    double? pitch,
    double? roll,
    double? scale,
  }) => RuntimeBoardTransform(
    worldKey: worldKey,
    worldUuid: worldUuid,
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
    yaw: yaw ?? this.yaw,
    pitch: pitch ?? this.pitch,
    roll: roll ?? this.roll,
    scale: scale ?? this.scale,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'worldKey': worldKey,
    'worldUuid': worldUuid,
    'x': x,
    'y': y,
    'z': z,
    'yaw': yaw,
    'pitch': pitch,
    'roll': roll,
    'scale': scale,
  };

  factory RuntimeBoardTransform.fromJson(Object? raw) {
    final Map<String, dynamic> value = _stringMap(raw, 'board transform');
    _requireExactKeys(value, const <String>{
      'worldKey',
      'worldUuid',
      'x',
      'y',
      'z',
      'yaw',
      'pitch',
      'roll',
      'scale',
    }, 'board transform');
    return RuntimeBoardTransform(
      worldKey: _string(value['worldKey'], 'worldKey'),
      worldUuid: _string(value['worldUuid'], 'worldUuid'),
      x: _finiteDouble(value['x'], 'x'),
      y: _finiteDouble(value['y'], 'y'),
      z: _finiteDouble(value['z'], 'z'),
      yaw: _finiteDouble(value['yaw'], 'yaw'),
      pitch: _finiteDouble(value['pitch'], 'pitch'),
      roll: _finiteDouble(value['roll'], 'roll'),
      scale: _finiteDouble(value['scale'], 'scale'),
    );
  }
}

final class RuntimeBoardFollow {
  const RuntimeBoardFollow({
    required this.mode,
    required this.targetPlayerUuid,
    required this.rotation,
  });

  final RuntimeBoardFollowMode mode;
  final String? targetPlayerUuid;
  final RuntimeBoardFollowRotation rotation;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.name,
    'targetPlayerUuid': targetPlayerUuid,
    'rotation': rotation.name,
  };

  factory RuntimeBoardFollow.fromJson(Object? raw) {
    final Map<String, dynamic> value = _stringMap(raw, 'board follow');
    _requireExactKeys(value, const <String>{
      'mode',
      'targetPlayerUuid',
      'rotation',
    }, 'board follow');
    return RuntimeBoardFollow(
      mode: _enumValue(
        RuntimeBoardFollowMode.values,
        value['mode'],
        'follow mode',
      ),
      targetPlayerUuid: _nullableString(
        value['targetPlayerUuid'],
        'targetPlayerUuid',
      ),
      rotation: _enumValue(
        RuntimeBoardFollowRotation.values,
        value['rotation'],
        'follow rotation',
      ),
    );
  }
}

final class RuntimeBoardVisibility {
  const RuntimeBoardVisibility({
    required this.mode,
    required this.viewPermission,
    required this.interactPermission,
    required this.viewRange,
    required this.interactionRange,
  });

  final RuntimeBoardVisibilityMode mode;
  final String? viewPermission;
  final String? interactPermission;
  final double viewRange;
  final double interactionRange;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.name,
    'viewPermission': viewPermission,
    'interactPermission': interactPermission,
    'viewRange': viewRange,
    'interactionRange': interactionRange,
  };

  factory RuntimeBoardVisibility.fromJson(Object? raw) {
    final Map<String, dynamic> value = _stringMap(raw, 'board visibility');
    _requireExactKeys(value, const <String>{
      'mode',
      'viewPermission',
      'interactPermission',
      'viewRange',
      'interactionRange',
    }, 'board visibility');
    return RuntimeBoardVisibility(
      mode: _enumValue(
        RuntimeBoardVisibilityMode.values,
        value['mode'],
        'visibility mode',
      ),
      viewPermission: _nullableString(
        value['viewPermission'],
        'viewPermission',
      ),
      interactPermission: _nullableString(
        value['interactPermission'],
        'interactPermission',
      ),
      viewRange: _finiteDouble(value['viewRange'], 'viewRange'),
      interactionRange: _finiteDouble(
        value['interactionRange'],
        'interactionRange',
      ),
    );
  }
}

final class RuntimeBoardDefinition {
  const RuntimeBoardDefinition({
    required this.schemaVersion,
    required this.id,
    required this.uuid,
    required this.revision,
    required this.rootMenuId,
    required this.transform,
    required this.follow,
    required this.visibility,
  });

  final int schemaVersion;
  final String id;
  final String uuid;
  final int revision;
  final String rootMenuId;
  final RuntimeBoardTransform transform;
  final RuntimeBoardFollow follow;
  final RuntimeBoardVisibility visibility;

  RuntimeBoardDefinition copyWith({
    String? rootMenuId,
    RuntimeBoardTransform? transform,
    RuntimeBoardFollow? follow,
    RuntimeBoardVisibility? visibility,
  }) => RuntimeBoardDefinition(
    schemaVersion: schemaVersion,
    id: id,
    uuid: uuid,
    revision: revision,
    rootMenuId: rootMenuId ?? this.rootMenuId,
    transform: transform ?? this.transform,
    follow: follow ?? this.follow,
    visibility: visibility ?? this.visibility,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'id': id,
    'uuid': uuid,
    'revision': revision,
    'rootMenuId': rootMenuId,
    'transform': transform.toJson(),
    'follow': follow.toJson(),
    'visibility': visibility.toJson(),
  };

  factory RuntimeBoardDefinition.fromJson(Map<String, dynamic> raw) {
    _requireExactKeys(raw, const <String>{
      'schemaVersion',
      'id',
      'uuid',
      'revision',
      'rootMenuId',
      'transform',
      'follow',
      'visibility',
    }, 'board definition');
    return RuntimeBoardDefinition(
      schemaVersion: _integer(raw['schemaVersion'], 'schemaVersion'),
      id: _string(raw['id'], 'id'),
      uuid: _string(raw['uuid'], 'uuid'),
      revision: _integer(raw['revision'], 'revision'),
      rootMenuId: _string(raw['rootMenuId'], 'rootMenuId'),
      transform: RuntimeBoardTransform.fromJson(raw['transform']),
      follow: RuntimeBoardFollow.fromJson(raw['follow']),
      visibility: RuntimeBoardVisibility.fromJson(raw['visibility']),
    );
  }
}

Map<String, dynamic> _stringMap(Object? raw, String label) {
  if (raw is! Map) throw FormatException('$label must be an object.');
  final Map<String, dynamic> value = <String, dynamic>{};
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    if (entry.key is! String) {
      throw FormatException('$label keys must be strings.');
    }
    value[entry.key! as String] = entry.value;
  }
  return value;
}

void _requireExactKeys(
  Map<String, dynamic> value,
  Set<String> keys,
  String label,
) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw FormatException('$label has unsupported or missing fields.');
  }
}

String _string(Object? raw, String label) {
  if (raw is! String) throw FormatException('$label must be a string.');
  return raw;
}

String? _nullableString(Object? raw, String label) {
  if (raw == null) return null;
  return _string(raw, label);
}

int _integer(Object? raw, String label) {
  if (raw is! num || !raw.isFinite || raw.toInt() != raw) {
    throw FormatException('$label must be an integer.');
  }
  return raw.toInt();
}

double _finiteDouble(Object? raw, String label) {
  if (raw is! num || !raw.isFinite) {
    throw FormatException('$label must be a finite number.');
  }
  return raw.toDouble();
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String label) {
  if (raw is String) {
    for (final T value in values) {
      if (value.name == raw) return value;
    }
  }
  throw FormatException('$label is not supported.');
}
