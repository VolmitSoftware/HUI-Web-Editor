library;

import 'workspace_repository_contract.dart';

WorkspaceRepository createPlatformWorkspaceRepository() =>
    const LocalStorageWorkspaceRepository();
