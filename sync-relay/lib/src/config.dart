library;

import 'dart:io';

import 'model.dart';

final class RelayConfig {
  static const int maximumProtocolProjectBytes = 32 * 1024 * 1024;
  static const int protocolEnvelopeBytes = 256 * 1024;
  static const int defaultMaximumSnapshotBytes = 8 * 1024 * 1024;
  static const int defaultMaximumStoredBytesPerPrincipal = 130 * 1024 * 1024;
  static const int maximumCreateTokens = 4096;
  static const int maximumProtocolRequestBytes =
      maximumProtocolProjectBytes + protocolEnvelopeBytes;
  static const int maximumProtocolResponseBytes =
      (maximumProtocolProjectBytes * 2) + protocolEnvelopeBytes;

  RelayConfig({
    required this.dataDirectory,
    this.bindAddress = '127.0.0.1',
    this.port = 8080,
    this.apiPrefix = '/v2',
    this.maximumSnapshotBytes = defaultMaximumSnapshotBytes,
    int? maximumRequestBytes,
    int? maximumResponseBytes,
    this.maximumStoredBytes = 1024 * 1024 * 1024,
    this.maximumActiveSessions = 10000,
    this.maximumRetainedSessionsPerPrincipal = 8,
    this.maximumActiveSessionsPerPrincipal = 8,
    this.maximumStoredBytesPerPrincipal = defaultMaximumStoredBytesPerPrincipal,
    this.maximumSessionsPerAddressPerMinute = 30,
    this.maximumSessionsPerPrincipalPerMinute = 10,
    this.maximumRateLimitAddresses = 10000,
    this.minimumTtl = const Duration(minutes: 5),
    this.maximumTtl = const Duration(hours: 24),
    Set<String> allowedOrigins = const <String>{
      'https://gloss.volmitsoftware.com',
    },
    this.trustProxy = false,
    Set<String> createTokenHashes = const <String>{},
    this.allowAnonymousCreate = false,
  }) : assert(
         maximumSnapshotBytes >= 1024 &&
             maximumSnapshotBytes <= maximumProtocolProjectBytes,
       ),
       assert(
         maximumRequestBytes == null ||
             (maximumRequestBytes >= 1 &&
                 maximumRequestBytes <=
                     maximumSnapshotBytes + protocolEnvelopeBytes),
       ),
       assert(
         maximumResponseBytes == null ||
             (maximumResponseBytes >= protocolEnvelopeBytes &&
                 maximumResponseBytes <=
                     (maximumSnapshotBytes * 2) + protocolEnvelopeBytes),
       ),
       assert(maximumStoredBytes >= 4 * 1024 * 1024),
       assert(maximumActiveSessions > 0),
       assert(maximumRetainedSessionsPerPrincipal > 0),
       assert(maximumActiveSessionsPerPrincipal > 0),
       assert(maximumStoredBytesPerPrincipal >= 1024 * 1024),
       assert(maximumSessionsPerAddressPerMinute > 0),
       assert(maximumSessionsPerPrincipalPerMinute > 0),
       assert(maximumRateLimitAddresses > 0),
       assert(minimumTtl > Duration.zero),
       assert(maximumTtl >= minimumTtl),
       maximumRequestBytes =
           maximumRequestBytes ?? maximumSnapshotBytes + protocolEnvelopeBytes,
       maximumResponseBytes =
           maximumResponseBytes ??
           (maximumSnapshotBytes * 2) + protocolEnvelopeBytes,
       allowedOrigins = Set<String>.unmodifiable(allowedOrigins),
       createTokenHashes = Set<String>.unmodifiable(createTokenHashes) {
    if (this.createTokenHashes.length > maximumCreateTokens ||
        this.createTokenHashes.any(
          (String value) => !RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
        )) {
      throw ArgumentError.value(
        this.createTokenHashes,
        'createTokenHashes',
        'must contain at most 4096 lowercase SHA-256 digests',
      );
    }
    if (allowAnonymousCreate && this.createTokenHashes.isNotEmpty) {
      throw ArgumentError(
        'anonymous create and token admission are mutually exclusive',
      );
    }
  }

  final Directory dataDirectory;
  final String bindAddress;
  final int port;
  final String apiPrefix;
  final int maximumRequestBytes;
  final int maximumSnapshotBytes;
  final int maximumResponseBytes;
  final int maximumStoredBytes;
  final int maximumActiveSessions;
  final int maximumRetainedSessionsPerPrincipal;
  final int maximumActiveSessionsPerPrincipal;
  final int maximumStoredBytesPerPrincipal;
  final int maximumSessionsPerAddressPerMinute;
  final int maximumSessionsPerPrincipalPerMinute;
  final int maximumRateLimitAddresses;
  final Duration minimumTtl;
  final Duration maximumTtl;
  final Set<String> allowedOrigins;
  final bool trustProxy;
  final Set<String> createTokenHashes;
  final bool allowAnonymousCreate;

  factory RelayConfig.fromEnvironment(Map<String, String> environment) {
    final String rawOrigins =
        environment['GLOSS_RELAY_ALLOWED_ORIGINS'] ??
        'https://gloss.volmitsoftware.com';
    final Set<String> origins = rawOrigins
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final int minimumTtlSeconds = _integer(
      environment,
      'GLOSS_RELAY_MIN_TTL_SECONDS',
      5 * 60,
      60,
      24 * 60 * 60,
    );
    final int configuredMaximumTtlSeconds = _integer(
      environment,
      'GLOSS_RELAY_MAX_TTL_SECONDS',
      24 * 60 * 60,
      5 * 60,
      7 * 24 * 60 * 60,
    );
    final int maximumTtlSeconds =
        configuredMaximumTtlSeconds < minimumTtlSeconds
        ? minimumTtlSeconds
        : configuredMaximumTtlSeconds;
    final int maximumSnapshotBytes = _integer(
      environment,
      'GLOSS_RELAY_MAX_SNAPSHOT_BYTES',
      defaultMaximumSnapshotBytes,
      1024,
      maximumProtocolProjectBytes,
    );
    final int maximumStoredBytes = _integer(
      environment,
      'GLOSS_RELAY_MAX_STORED_BYTES',
      1024 * 1024 * 1024,
      4 * 1024 * 1024,
      1024 * 1024 * 1024 * 1024,
    );
    final int maximumActiveSessions = _integer(
      environment,
      'GLOSS_RELAY_MAX_ACTIVE_SESSIONS',
      10000,
      1,
      1000000,
    );
    final int defaultPrincipalStorage =
        maximumStoredBytes < defaultMaximumStoredBytesPerPrincipal
        ? maximumStoredBytes
        : defaultMaximumStoredBytesPerPrincipal;
    final int defaultPrincipalActive = maximumActiveSessions < 8
        ? maximumActiveSessions
        : 8;
    final Set<String> createTokenHashes = _createTokenHashes(environment);
    final bool allowAnonymousCreate = _strictBoolean(
      environment,
      'GLOSS_RELAY_ALLOW_ANONYMOUS_CREATE',
      false,
    );
    if (allowAnonymousCreate && createTokenHashes.isNotEmpty) {
      throw const FormatException(
        'anonymous create and token admission are mutually exclusive',
      );
    }
    return RelayConfig(
      dataDirectory: Directory(
        environment['GLOSS_RELAY_DATA'] ?? '/data/gloss-sync',
      ),
      bindAddress: environment['GLOSS_RELAY_BIND'] ?? '127.0.0.1',
      port: _integer(environment, 'PORT', 8080, 1, 65535),
      apiPrefix: _prefix(environment['GLOSS_RELAY_API_PREFIX'] ?? '/v2'),
      maximumSnapshotBytes: maximumSnapshotBytes,
      maximumStoredBytes: maximumStoredBytes,
      maximumActiveSessions: maximumActiveSessions,
      maximumRetainedSessionsPerPrincipal: _integer(
        environment,
        'GLOSS_RELAY_MAX_RETAINED_SESSIONS_PER_PRINCIPAL',
        8,
        1,
        1000000,
      ),
      maximumActiveSessionsPerPrincipal: _integer(
        environment,
        'GLOSS_RELAY_MAX_ACTIVE_SESSIONS_PER_PRINCIPAL',
        defaultPrincipalActive,
        1,
        maximumActiveSessions,
      ),
      maximumStoredBytesPerPrincipal: _integer(
        environment,
        'GLOSS_RELAY_MAX_STORED_BYTES_PER_PRINCIPAL',
        defaultPrincipalStorage,
        1024 * 1024,
        maximumStoredBytes,
      ),
      maximumSessionsPerAddressPerMinute: _integer(
        environment,
        'GLOSS_RELAY_CREATE_RATE',
        30,
        1,
        10000,
      ),
      maximumSessionsPerPrincipalPerMinute: _integer(
        environment,
        'GLOSS_RELAY_CREATE_RATE_PER_PRINCIPAL',
        10,
        1,
        10000,
      ),
      maximumRateLimitAddresses: _integer(
        environment,
        'GLOSS_RELAY_MAX_RATE_ADDRESSES',
        10000,
        128,
        1000000,
      ),
      minimumTtl: Duration(seconds: minimumTtlSeconds),
      maximumTtl: Duration(seconds: maximumTtlSeconds),
      allowedOrigins: origins,
      trustProxy:
          environment['GLOSS_RELAY_TRUST_PROXY']?.toLowerCase() == 'true',
      createTokenHashes: createTokenHashes,
      allowAnonymousCreate: allowAnonymousCreate,
    );
  }

  static int _integer(
    Map<String, String> environment,
    String key,
    int fallback,
    int minimum,
    int maximum,
  ) {
    final int? parsed = int.tryParse(environment[key] ?? '');
    if (parsed == null || parsed < minimum || parsed > maximum) {
      return fallback;
    }
    return parsed;
  }

  static String _prefix(String value) {
    String normalized = value.trim();
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!RegExp(
      r'^/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+$',
    ).hasMatch(normalized)) {
      return '/v2';
    }
    return normalized;
  }

  static Set<String> _createTokenHashes(Map<String, String> environment) {
    final String singular = environment['GLOSS_RELAY_CREATE_TOKEN'] ?? '';
    final String plural = environment['GLOSS_RELAY_CREATE_TOKENS'] ?? '';
    if (singular.isNotEmpty && plural.isNotEmpty) {
      throw const FormatException(
        'GLOSS_RELAY_CREATE_TOKEN and GLOSS_RELAY_CREATE_TOKENS are mutually exclusive',
      );
    }
    final String raw = plural.isNotEmpty ? plural : singular;
    if (raw.isEmpty) return const <String>{};
    final List<String> parts = plural.isNotEmpty
        ? raw.split(',').map((String value) => value.trim()).toList()
        : <String>[raw];
    if (parts.any(
      (String value) => !RegExp(r'^[A-Za-z0-9_-]{22,128}$').hasMatch(value),
    )) {
      throw const FormatException(
        'create tokens must be URL-safe 22-128 character capabilities',
      );
    }
    final Set<String> unique = parts.toSet();
    if (unique.length > maximumCreateTokens) {
      throw const FormatException('at most 4096 create tokens are allowed');
    }
    return Set<String>.unmodifiable(
      unique.map<String>((String value) => tokenHash(value)),
    );
  }

  static bool _strictBoolean(
    Map<String, String> environment,
    String key,
    bool fallback,
  ) {
    final String? raw = environment[key];
    if (raw == null || raw.isEmpty) return fallback;
    if (raw.toLowerCase() == 'true') return true;
    if (raw.toLowerCase() == 'false') return false;
    throw FormatException('$key must be true or false');
  }
}
