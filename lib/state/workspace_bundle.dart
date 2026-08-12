library;

import 'dart:convert';

import '../services/image_library.dart';
import 'workspace.dart';

final class WorkspaceBundle {
  const WorkspaceBundle({required this.workspaceState, required this.images});

  static const int version = 1;
  static const String format = 'holoui-editor-workspace';

  final Map<String, dynamic> workspaceState;
  final List<StoredImage> images;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': format,
    'version': version,
    'workspace': workspaceState,
    'images': images.map((StoredImage image) => image.toJson()).toList(),
  };
}

final class WorkspaceBundleDecodeResult {
  const WorkspaceBundleDecodeResult({
    this.bundle,
    this.workspaceCheck,
    this.error,
  });

  final WorkspaceBundle? bundle;
  final WorkspacePortableStateCheck? workspaceCheck;
  final String? error;
}

final class WorkspaceBundleImportResult {
  const WorkspaceBundleImportResult._({
    required this.isSuccess,
    this.error,
    this.compensationFailed = false,
  });

  const WorkspaceBundleImportResult.success() : this._(isSuccess: true);

  const WorkspaceBundleImportResult.failure(
    String error, {
    bool compensationFailed = false,
  }) : this._(
         isSuccess: false,
         error: error,
         compensationFailed: compensationFailed,
       );

  final bool isSuccess;
  final String? error;
  final bool compensationFailed;
}

String encodeWorkspaceBundle(Workspace workspace, ImageLibrary? images) =>
    const JsonEncoder.withIndent('  ').convert(
      WorkspaceBundle(
        workspaceState: workspace.exportPortableState(),
        images: images == null
            ? const <StoredImage>[]
            : List<StoredImage>.of(images.images),
      ).toJson(),
    );

WorkspaceBundleDecodeResult decodeWorkspaceBundle(
  String raw,
  Workspace workspace,
) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const WorkspaceBundleDecodeResult(
      error: 'That file is not valid JSON.',
    );
  }
  if (decoded is! Map ||
      decoded['format'] != WorkspaceBundle.format ||
      decoded['version'] != WorkspaceBundle.version) {
    return const WorkspaceBundleDecodeResult(
      error: 'That is not a supported HoloUI editor workspace bundle.',
    );
  }
  final Object? rawWorkspace = decoded['workspace'];
  final WorkspacePortableStateCheck check = workspace.inspectPortableState(
    rawWorkspace,
  );
  if (!check.isValid || rawWorkspace is! Map) {
    return WorkspaceBundleDecodeResult(
      workspaceCheck: check,
      error: check.error ?? 'The bundled workspace is unreadable.',
    );
  }
  final Object? rawImages = decoded['images'];
  if (rawImages is! List) {
    return const WorkspaceBundleDecodeResult(
      error: 'The bundled image library is missing.',
    );
  }
  final List<StoredImage> images = <StoredImage>[];
  final Set<String> paths = <String>{};
  for (final Object? entry in rawImages) {
    final StoredImage? image = StoredImage.fromJson(entry);
    if (image == null ||
        validateImagePath(image.path) != null ||
        !paths.add(image.path) ||
        !isValidStoredImageData(image)) {
      return const WorkspaceBundleDecodeResult(
        error: 'The bundled image library contains an invalid entry.',
      );
    }
    images.add(image);
  }
  return WorkspaceBundleDecodeResult(
    bundle: WorkspaceBundle(
      workspaceState: Map<String, dynamic>.from(rawWorkspace),
      images: List<StoredImage>.unmodifiable(images),
    ),
    workspaceCheck: check,
  );
}

Future<WorkspaceBundleImportResult> importWorkspaceBundle(
  WorkspaceBundle bundle,
  Workspace workspace,
  ImageLibrary? images,
) async {
  final List<StoredImage>? previousImages = images == null
      ? null
      : List<StoredImage>.of(images.images);
  if (images != null && !images.replaceAll(bundle.images)) {
    return WorkspaceBundleImportResult.failure(
      images.lastError ?? 'The bundled images could not be saved.',
    );
  }
  if (await workspace.replacePortableState(bundle.workspaceState)) {
    return const WorkspaceBundleImportResult.success();
  }
  final String workspaceFailure =
      workspace.lastError ?? 'The bundled workspace could not be saved.';
  if (images != null && previousImages != null) {
    final bool restored = images.replaceAll(previousImages);
    if (!restored) {
      return WorkspaceBundleImportResult.failure(
        '$workspaceFailure The previous image library also could not be '
        'restored; export this tab before closing it.',
        compensationFailed: true,
      );
    }
  }
  return WorkspaceBundleImportResult.failure(workspaceFailure);
}
