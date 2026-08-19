/// Build identity shown in the status bar's version tile.
///
/// CI injects both values with --dart-define (GLOSS_VERSION from the release
/// tag or pubspec, GLOSS_COMMIT as the short commit SHA); a plain local build
/// falls back to the pubspec version and "local".
library;

const String huiBuildVersion = String.fromEnvironment(
  'GLOSS_VERSION',
  defaultValue: '4.0.0',
);

const String huiBuildCommit = String.fromEnvironment(
  'GLOSS_COMMIT',
  defaultValue: 'local',
);

const String huiBuildBadge = '$huiBuildVersion-$huiBuildCommit';
