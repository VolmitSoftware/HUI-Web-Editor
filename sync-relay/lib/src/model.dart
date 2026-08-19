library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

enum RelayPublicationState { pending, applied, conflict, rejected }

const int relayMaximumSafeInteger = 9007199254740991;

/// Protocol v2 caps the uniform `documents` collection; per-document budgets
/// beyond this are plugin policy, bounded here only by the snapshot size.
const int relayMaximumDocuments = 512;

/// The open protocol-v2 kind slug grammar. The relay validates ONLY this
/// pattern — kinds are never interpreted, so new kinds need no relay change.
final RegExp relayKindSlug = RegExp(r'^[a-z][a-z0-9-]{0,31}$');
const int relaySnapshotReservationEnvelopeBytes = 256 * 1024;
const int relayMinimumReservedSessionBytes =
    relaySnapshotReservationEnvelopeBytes + (2 * 1024);
const int relayMaximumReservedSessionBytes = (64 * 1024 * 1024) + (256 * 1024);

final class RelayAck {
  const RelayAck({
    required this.status,
    required this.message,
    required this.serverRevision,
    required this.acknowledgedAt,
  });

  final RelayPublicationState status;
  final String message;
  final String? serverRevision;
  final DateTime acknowledgedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'message': message,
    'serverRevision': serverRevision,
    'acknowledgedAt': acknowledgedAt.toUtc().toIso8601String(),
  };

  static RelayAck fromJson(Object? raw) {
    final Map<String, Object?> object = requireObject(raw, 'ack');
    requireExactKeys(object, const <String>{
      'status',
      'message',
      'serverRevision',
      'acknowledgedAt',
    });
    final RelayPublicationState status = requirePublicationState(
      object,
      'status',
    );
    final String message = requireString(object, 'message', allowEmpty: true);
    final Object? rawServerRevision = object['serverRevision'];
    if (status == RelayPublicationState.pending || message.length > 2048) {
      throw const FormatException('stored acknowledgement is invalid');
    }
    final bool promotes =
        status == RelayPublicationState.applied ||
        status == RelayPublicationState.conflict;
    final String? serverRevision;
    if (promotes) {
      serverRevision = requireRevision(object, 'serverRevision');
    } else {
      if (rawServerRevision != null) {
        throw const FormatException(
          'stored rejected acknowledgement revision is invalid',
        );
      }
      serverRevision = null;
    }
    return RelayAck(
      status: status,
      message: message,
      serverRevision: serverRevision,
      acknowledgedAt: DateTime.parse(requireString(object, 'acknowledgedAt')),
    );
  }
}

final class RelayPublication {
  const RelayPublication({
    required this.revision,
    required this.baseRevision,
    required this.snapshot,
    required this.publishedAt,
    this.state = RelayPublicationState.pending,
    this.ack,
  });

  final int revision;
  final String baseRevision;
  final Map<String, Object?> snapshot;
  final DateTime publishedAt;
  final RelayPublicationState state;
  final RelayAck? ack;

  RelayPublication acknowledge(RelayAck value) => RelayPublication(
    revision: revision,
    baseRevision: baseRevision,
    snapshot: snapshot,
    publishedAt: publishedAt,
    state: value.status,
    ack: value,
  );

  Map<String, Object?> toJson({bool includeSnapshot = true}) =>
      <String, Object?>{
        'revision': revision,
        'baseRevision': baseRevision,
        if (includeSnapshot) 'snapshot': snapshot,
        'publishedAt': publishedAt.toUtc().toIso8601String(),
        'state': state.name,
        'ack': ack?.toJson(),
      };

  static RelayPublication fromJson(Object? raw) {
    final Map<String, Object?> object = requireObject(raw, 'publication');
    requireExactKeys(object, const <String>{
      'revision',
      'baseRevision',
      'snapshot',
      'publishedAt',
      'state',
      'ack',
    });
    final Object? rawRevision = object['revision'];
    if (rawRevision is! int ||
        rawRevision < 1 ||
        rawRevision > relayMaximumSafeInteger) {
      throw const FormatException('publication revision is invalid');
    }
    final Map<String, Object?> snapshot = requireObject(
      object['snapshot'],
      'snapshot',
    );
    requireRevision(snapshot, 'baseRevision');
    final RelayPublicationState state = requirePublicationState(object);
    final RelayAck? ack = object['ack'] == null
        ? null
        : RelayAck.fromJson(object['ack']);
    if ((state == RelayPublicationState.pending) != (ack == null) ||
        (ack != null && ack.status != state)) {
      throw const FormatException('stored publication state is invalid');
    }
    final DateTime publishedAt = DateTime.parse(
      requireString(object, 'publishedAt'),
    );
    if (ack != null && ack.acknowledgedAt.isBefore(publishedAt)) {
      throw const FormatException(
        'stored acknowledgement predates publication',
      );
    }
    return RelayPublication(
      revision: rawRevision,
      baseRevision: requireRevision(object, 'baseRevision'),
      snapshot: snapshot,
      publishedAt: publishedAt,
      state: state,
      ack: ack,
    );
  }
}

final class RelaySession {
  const RelaySession({
    required this.id,
    required this.createPrincipalHash,
    required this.reservedBytes,
    required this.editorTokenHash,
    required this.serverTokenHash,
    required this.createdAt,
    required this.expiresAt,
    required this.baseRevision,
    required this.snapshot,
    required this.nextPublicationRevision,
    this.revokedAt,
    this.publication,
  });

  final String id;
  final String createPrincipalHash;
  final int reservedBytes;
  final String editorTokenHash;
  final String serverTokenHash;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String baseRevision;
  final Map<String, Object?> snapshot;
  final int nextPublicationRevision;
  final RelayPublication? publication;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
  bool get isRevoked => revokedAt != null;

  String get status {
    final RelayPublication? current = publication;
    if (current == null) return 'open';
    return current.state.name;
  }

  RelaySession publish(RelayPublication value) =>
      copyWith(publication: value, nextPublicationRevision: value.revision + 1);

  RelaySession acknowledge(
    RelayPublication value, {
    Map<String, Object?>? promotedSnapshot,
    String? promotedRevision,
  }) => copyWith(
    publication: value,
    snapshot: promotedSnapshot,
    baseRevision: promotedRevision,
  );

  RelaySession revoke(DateTime now) => copyWith(revokedAt: now);

  RelaySession copyWith({
    DateTime? revokedAt,
    String? baseRevision,
    Map<String, Object?>? snapshot,
    int? nextPublicationRevision,
    RelayPublication? publication,
  }) => RelaySession(
    id: id,
    createPrincipalHash: createPrincipalHash,
    reservedBytes: reservedBytes,
    editorTokenHash: editorTokenHash,
    serverTokenHash: serverTokenHash,
    createdAt: createdAt,
    expiresAt: expiresAt,
    revokedAt: revokedAt ?? this.revokedAt,
    baseRevision: baseRevision ?? this.baseRevision,
    snapshot: snapshot ?? this.snapshot,
    nextPublicationRevision:
        nextPublicationRevision ?? this.nextPublicationRevision,
    publication: publication ?? this.publication,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 2,
    'id': id,
    'createPrincipalHash': createPrincipalHash,
    'reservedBytes': reservedBytes,
    'editorTokenHash': editorTokenHash,
    'serverTokenHash': serverTokenHash,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
    'baseRevision': baseRevision,
    'snapshot': snapshot,
    'nextPublicationRevision': nextPublicationRevision,
    'publication': publication?.toJson(),
  };

  static RelaySession fromJson(Object? raw) {
    final Map<String, Object?> object = requireObject(raw, 'session');
    requireExactKeys(object, const <String>{
      'version',
      'id',
      'createPrincipalHash',
      'reservedBytes',
      'editorTokenHash',
      'serverTokenHash',
      'createdAt',
      'expiresAt',
      'revokedAt',
      'baseRevision',
      'snapshot',
      'nextPublicationRevision',
      'publication',
    });
    if (object['version'] != 2) {
      throw const FormatException('unsupported stored session version');
    }
    final Object? rawReservedBytes = object['reservedBytes'];
    if (rawReservedBytes is! int ||
        rawReservedBytes < relayMinimumReservedSessionBytes ||
        rawReservedBytes > relayMaximumReservedSessionBytes) {
      throw const FormatException('stored session reservation is invalid');
    }
    final Object? rawNext = object['nextPublicationRevision'];
    if (rawNext is! int || rawNext < 1 || rawNext > relayMaximumSafeInteger) {
      throw const FormatException('stored publication revision is invalid');
    }
    final DateTime createdAt = DateTime.parse(
      requireString(object, 'createdAt'),
    );
    final DateTime expiresAt = DateTime.parse(
      requireString(object, 'expiresAt'),
    );
    final DateTime? revokedAt = object['revokedAt'] == null
        ? null
        : DateTime.parse(requireString(object, 'revokedAt'));
    if (!expiresAt.isAfter(createdAt) ||
        (revokedAt != null &&
            (revokedAt.isBefore(createdAt) || !expiresAt.isAfter(revokedAt)))) {
      throw const FormatException('stored session timestamps are invalid');
    }
    final String baseRevision = requireRevision(object, 'baseRevision');
    final Map<String, Object?> snapshot = requireObject(
      object['snapshot'],
      'snapshot',
    );
    if (requireRevision(snapshot, 'baseRevision') != baseRevision) {
      throw const FormatException(
        'stored session snapshot revision is invalid',
      );
    }
    final RelayPublication? publication = object['publication'] == null
        ? null
        : RelayPublication.fromJson(object['publication']);
    final int snapshotBytes = utf8.encode(jsonEncode(snapshot)).length;
    final int publicationBytes = publication == null
        ? snapshotBytes
        : utf8.encode(jsonEncode(publication.snapshot)).length;
    final int largestSnapshotBytes = snapshotBytes > publicationBytes
        ? snapshotBytes
        : publicationBytes;
    if (rawReservedBytes <
        relaySnapshotReservationEnvelopeBytes + (2 * largestSnapshotBytes)) {
      throw const FormatException('stored session reservation is too small');
    }
    if (publication != null) {
      if (publication.publishedAt.isBefore(createdAt) ||
          !expiresAt.isAfter(publication.publishedAt) ||
          (publication.ack != null &&
              !expiresAt.isAfter(publication.ack!.acknowledgedAt))) {
        throw const FormatException('stored publication timestamp is invalid');
      }
      if (rawNext != publication.revision + 1) {
        throw const FormatException('stored publication sequence is invalid');
      }
      if ((publication.state == RelayPublicationState.pending ||
              publication.state == RelayPublicationState.rejected) &&
          publication.baseRevision != baseRevision) {
        throw const FormatException('stored publication base is invalid');
      }
      if (publication.state == RelayPublicationState.rejected &&
          publication.ack?.serverRevision != null) {
        throw const FormatException('stored rejected revision is invalid');
      }
      if ((publication.state == RelayPublicationState.applied ||
              publication.state == RelayPublicationState.conflict) &&
          publication.ack?.serverRevision != baseRevision) {
        throw const FormatException('stored promoted revision is invalid');
      }
    } else if (rawNext != 1) {
      throw const FormatException('stored publication sequence is invalid');
    }
    return RelaySession(
      id: requireCapability(object, 'id'),
      createPrincipalHash: requireHash(object, 'createPrincipalHash'),
      reservedBytes: rawReservedBytes,
      editorTokenHash: requireHash(object, 'editorTokenHash'),
      serverTokenHash: requireHash(object, 'serverTokenHash'),
      createdAt: createdAt,
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      baseRevision: baseRevision,
      snapshot: snapshot,
      nextPublicationRevision: rawNext,
      publication: publication,
    );
  }
}

String tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();

bool constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  int difference = 0;
  for (int index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}

Map<String, Object?> requireObject(Object? raw, String label) {
  if (raw is! Map) throw FormatException('$label must be an object');
  final Map<String, Object?> output = <String, Object?>{};
  raw.forEach((Object? key, Object? value) {
    if (key is! String) throw FormatException('$label has a non-string key');
    output[key] = value;
  });
  return output;
}

String requireString(
  Map<String, Object?> object,
  String field, {
  bool allowEmpty = false,
}) {
  final Object? value = object[field];
  if (value is! String || (!allowEmpty && value.isEmpty)) {
    throw FormatException('$field must be a string');
  }
  return value;
}

String requireRevision(Map<String, Object?> object, String field) {
  final String value = requireString(object, field);
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$field must be a SHA-256 revision');
  }
  return value;
}

String requireCapability(Map<String, Object?> object, String field) {
  final String value = requireString(object, field);
  if (!RegExp(r'^[A-Za-z0-9_-]{22,128}$').hasMatch(value)) {
    throw FormatException('$field is invalid');
  }
  return value;
}

String requireHash(Map<String, Object?> object, String field) {
  final String value = requireString(object, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$field is invalid');
  }
  return value;
}

RelayPublicationState requirePublicationState(
  Map<String, Object?> object, [
  String field = 'state',
]) {
  try {
    return RelayPublicationState.values.byName(requireString(object, field));
  } on ArgumentError {
    throw const FormatException('publication state is invalid');
  }
}

void requireExactKeys(Map<String, Object?> object, Set<String> expected) {
  if (object.length != expected.length ||
      object.keys.any((String key) => !expected.contains(key))) {
    throw const FormatException('stored object fields are invalid');
  }
}
