/// Shared envelope for the Gloss document kinds (hologram, animation,
/// scoreboard).
///
/// Every Gloss content document carries a schema version and revision. Most
/// kinds currently speak schema 1; bubble styles speak schema 2. A mismatched
/// version is rejected outright by the plugin, and `revision` is a server-owned
/// monotonic counter in `1..9007199254740991`. The id is the file path — never
/// a JSON key.
///
/// Decode leniency follows the editor's one rule (`json_codec.dart`): a
/// [HuiFormatException] is reserved for what makes the document unreadable as
/// this generation of the format — malformed JSON and a missing or wrong
/// `schemaVersion`. Everything else the Java parser would reject (revision out
/// of range, a blank world, an empty frame list, an unknown animation mode)
/// decodes leniently and is reported by the kind's validation as an error, so
/// the document can be opened and repaired instead of being replaced with a
/// blank one.
library;

import 'json_codec.dart';

/// `DocumentEnvelope.INITIAL_REVISION`.
const int glossInitialRevision = 1;

/// `DocumentEnvelope.MAX_SAFE_REVISION` — JavaScript's `MAX_SAFE_INTEGER`.
const int glossMaxSafeRevision = 9007199254740991;

/// The schema generation shared by every Gloss kind except bubble styles.
const int glossCurrentSchemaVersion = 1;

/// Base type for the mutable Gloss document models, so the store can hold the
/// active one in a single slot and the shared write path can snapshot it
/// without knowing which kind is open.
abstract base class GlossDoc {
  GlossDoc({required this.schemaVersion, required this.revision});

  /// The kind-specific current schema after a successful decode; kept as a
  /// field so `toJson` re-emits exactly what was read.
  int schemaVersion;

  /// Server-owned; the editor round-trips it verbatim and never invents one
  /// past [glossInitialRevision] for fresh documents (the panel model treats
  /// its runtime revision the same way).
  int revision;

  Map<String, dynamic> toJson();
}

/// Reads the envelope's `schemaVersion`, throwing for the generations this
/// editor cannot faithfully edit. Mirrors
/// `DocumentEnvelope.requireSchemaVersion` — a missing key is Gson's `0` and
/// rejects the same way (`HologramDoc.java:29-31`).
int glossReadSchemaVersion(
  Map<String, dynamic> raw,
  String kind, {
  int expected = glossCurrentSchemaVersion,
}) {
  final Object? value = raw['schemaVersion'];
  final int version = value is num ? value.toInt() : 0;
  if (version != expected) {
    throw HuiFormatException(
      'Unsupported $kind schemaVersion: ${value ?? 'missing'}. This editor '
          'speaks schemaVersion $expected.',
      r'$.schemaVersion',
    );
  }
  return version;
}

/// Reads the envelope's `revision` leniently; the range check
/// (`DocumentEnvelope.requireRevision`) is validation's job.
int glossReadRevision(Map<String, dynamic> raw) =>
    huiReadInt(raw, 'revision', fallback: 0);

/// True when [revision] would pass `DocumentEnvelope.requireRevision`.
bool glossRevisionInRange(int revision) =>
    revision >= glossInitialRevision && revision <= glossMaxSafeRevision;

/// String-list reading shared by `lines`, `frames` and `groups`.
///
/// Mirrors the Gson stack: `SingleCollectionTypeFactory` lets a scalar stand
/// in for a one-element list, Gson's string adapter coerces numbers and
/// booleans, and the record constructors map a null entry to `""` instead of
/// dropping it (`HologramDoc.copyLines`, `AnimationDoc.copyFrames`).
List<String> glossReadStringList(Object? raw) => <String>[
  for (final Object? entry in huiReadList(raw))
    entry == null
        ? ''
        : entry is String
        ? entry
        : entry.toString(),
];
