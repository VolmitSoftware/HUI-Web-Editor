library;

import 'dart:convert';

import '../l10n/hui_localizations.dart';
import '../services/image_library.dart';
import 'workspace.dart';

final class WorkspaceBundle {
  const WorkspaceBundle({required this.workspaceState, required this.images});

  static const int version = 1;
  static const String format = 'gloss-editor-workspace';

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
    String? error,
    this.errorResolver,
  }) : _error = error;

  final WorkspaceBundle? bundle;
  final WorkspacePortableStateCheck? workspaceCheck;
  final String? _error;
  final String Function()? errorResolver;

  String? get error =>
      errorResolver?.call() ?? (_error == null ? null : huiText(_error));
}

final class WorkspaceBundleImportResult {
  const WorkspaceBundleImportResult._({
    required this.isSuccess,
    String? error,
    this.errorResolver,
    this.compensationFailed = false,
  }) : _error = error;

  const WorkspaceBundleImportResult.success() : this._(isSuccess: true);

  const WorkspaceBundleImportResult.failure(
    String error, {
    bool compensationFailed = false,
  }) : this._(
         isSuccess: false,
         error: error,
         compensationFailed: compensationFailed,
       );

  const WorkspaceBundleImportResult.failureResolved(
    String Function() resolver, {
    bool compensationFailed = false,
  }) : this._(
         isSuccess: false,
         errorResolver: resolver,
         compensationFailed: compensationFailed,
       );

  final bool isSuccess;
  final String? _error;
  final String Function()? errorResolver;

  String? get error =>
      errorResolver?.call() ?? (_error == null ? null : huiText(_error));
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
      error: 'That is not a supported Gloss editor workspace bundle.',
    );
  }
  final Object? rawWorkspace = decoded['workspace'];
  final WorkspacePortableStateCheck check = workspace.inspectPortableState(
    rawWorkspace,
  );
  if (!check.isValid || rawWorkspace is! Map) {
    return WorkspaceBundleDecodeResult(
      workspaceCheck: check,
      errorResolver: () =>
          check.error ?? huiText('The bundled workspace is unreadable.'),
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
  final String? previousImageWorkspaceId = images?.workspaceId;
  final Object? targetWorkspaceId = bundle.workspaceState['workspaceId'];
  if (images != null && targetWorkspaceId is String) {
    await images.useWorkspace(targetWorkspaceId);
  }
  if (images != null && !images.replaceAll(bundle.images)) {
    if (previousImageWorkspaceId != null) {
      await images.useWorkspace(previousImageWorkspaceId);
    }
    return WorkspaceBundleImportResult.failureResolved(
      () =>
          images.lastError ?? huiText('The bundled images could not be saved.'),
    );
  }
  await images?.writesSettled;
  if (images?.hasUnsavedChanges ?? false) {
    if (images != null && previousImageWorkspaceId != null) {
      await images.useWorkspace(previousImageWorkspaceId);
      if (previousImages != null) images.replaceAll(previousImages);
      await images.writesSettled;
    }
    return WorkspaceBundleImportResult.failureResolved(
      () =>
          images?.lastError ??
          huiText('The bundled images could not be saved.'),
    );
  }
  if (await workspace.replacePortableState(bundle.workspaceState)) {
    return const WorkspaceBundleImportResult.success();
  }
  String workspaceFailure() =>
      workspace.lastError ??
      huiText('The bundled workspace could not be saved.');
  if (images != null && previousImages != null) {
    if (previousImageWorkspaceId != null) {
      await images.useWorkspace(previousImageWorkspaceId);
    }
    final bool restored = images.replaceAll(previousImages);
    await images.writesSettled;
    if (!restored || images.hasUnsavedChanges) {
      return WorkspaceBundleImportResult.failureResolved(
        () => huiText(
          '{workspaceFailure} The previous image library also could not be restored; export this tab before closing it.',
          <String, Object?>{'workspaceFailure': workspaceFailure()},
        ),
        compensationFailed: true,
      );
    }
  }
  return WorkspaceBundleImportResult.failureResolved(workspaceFailure);
}
