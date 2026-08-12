library;

import 'workspace_repository_factory_stub.dart'
    if (dart.library.js_interop) 'workspace_repository_factory_web.dart';

export 'workspace_repository_contract.dart';

import 'workspace_repository_contract.dart';

WorkspaceRepository createDefaultWorkspaceRepository() =>
    createPlatformWorkspaceRepository();
