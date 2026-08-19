library;

import 'dart:io';

final String glossRepositoryPath =
    Platform.environment['GLOSS_REPOSITORY'] ?? '../Gloss';

String glossRepositoryFilePath(String relativePath) =>
    '$glossRepositoryPath/$relativePath';
