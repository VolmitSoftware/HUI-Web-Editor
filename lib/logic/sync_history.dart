/// The stored versions the server keeps for each synced document.
///
/// The sync project carries them in its `history` section, capped at twenty per
/// document. Only the index travels with the project; the bytes of one version
/// are fetched on demand through the relay's history route, so opening the
/// panel costs nothing until somebody picks a version.
library;

import '../l10n/hui_localizations.dart';

/// One stored copy of one document.
final class SyncHistoryVersion {
  const SyncHistoryVersion({
    required this.kind,
    required this.id,
    required this.version,
    required this.source,
    required this.bytes,
  });

  final String kind;
  final String id;

  /// The epoch-millisecond stamp the history request names.
  final int version;

  /// What took the copy: `watchdog`, `editor:<session>`, `pack:<id>`,
  /// `import:<source>`, `restore` or `command`.
  final String source;

  final int bytes;

  String get sourceLabel => describeSource(source);

  /// The source in words. An unrecognized source is shown verbatim rather than
  /// as "unknown": it is the server's own word for where the copy came from.
  static String describeSource(String source) {
    if (source.startsWith('editor:')) return huiText('Editor publication');
    if (source.startsWith('pack:')) {
      return huiText("Pack {id}", <String, Object?>{
        'id': source.substring('pack:'.length),
      });
    }
    if (source.startsWith('import:')) {
      return huiText("Import {source}", <String, Object?>{
        'source': source.substring('import:'.length),
      });
    }
    return switch (source) {
      'watchdog' => huiText('Edited on disk'),
      'restore' => huiText('Restore'),
      'command' => huiText('Command'),
      _ => source,
    };
  }

  static SyncHistoryVersion? decode(Object? raw) {
    if (raw is! Map) return null;
    final Object? kind = raw['kind'];
    final Object? id = raw['id'];
    final Object? version = raw['version'];
    final Object? source = raw['source'];
    final Object? bytes = raw['bytes'];
    if (kind is! String ||
        id is! String ||
        version is! int ||
        source is! String ||
        bytes is! int ||
        kind.isEmpty ||
        id.isEmpty ||
        version < 0 ||
        bytes < 0) {
      return null;
    }
    return SyncHistoryVersion(
      kind: kind,
      id: id,
      version: version,
      source: source,
      bytes: bytes,
    );
  }
}

/// One document that has stored versions.
final class SyncHistoryDocument {
  const SyncHistoryDocument({
    required this.kind,
    required this.id,
    required this.versions,
  });

  final String kind;
  final String id;
  final List<SyncHistoryVersion> versions;
}

/// The whole `history` section, indexed by document.
final class SyncHistory {
  const SyncHistory._(this._byDocument);

  static const SyncHistory empty = SyncHistory._(
    <String, List<SyncHistoryVersion>>{},
  );

  final Map<String, List<SyncHistoryVersion>> _byDocument;

  static SyncHistory of(Object? raw) {
    if (raw is! List) return empty;
    final Map<String, List<SyncHistoryVersion>> byDocument =
        <String, List<SyncHistoryVersion>>{};
    for (final Object? entry in raw) {
      final SyncHistoryVersion? version = SyncHistoryVersion.decode(entry);
      if (version == null) continue;
      byDocument
          .putIfAbsent(
            _key(version.kind, version.id),
            () => <SyncHistoryVersion>[],
          )
          .add(version);
    }
    for (final List<SyncHistoryVersion> versions in byDocument.values) {
      versions.sort(
        (SyncHistoryVersion left, SyncHistoryVersion right) =>
            right.version.compareTo(left.version),
      );
    }
    return SyncHistory._(byDocument);
  }

  /// The stored versions of one document, newest first.
  List<SyncHistoryVersion> forDocument(String kind, String id) =>
      List<SyncHistoryVersion>.unmodifiable(
        _byDocument[_key(kind, id)] ?? const <SyncHistoryVersion>[],
      );

  /// Every document that has stored versions, in kind then id order.
  List<SyncHistoryDocument> get documents {
    final List<String> keys = _byDocument.keys.toList()..sort();
    return List<SyncHistoryDocument>.unmodifiable(<SyncHistoryDocument>[
      for (final String key in keys)
        SyncHistoryDocument(
          kind: key.split(' ').first,
          id: key.split(' ').last,
          versions: List<SyncHistoryVersion>.unmodifiable(_byDocument[key]!),
        ),
    ]);
  }

  static String _key(String kind, String id) => '$kind $id';
}
