/// Mirror of `BoardService.selectBoardId` — which board a given viewer gets.
///
/// Three ordered passes over the boards, each pass scanning the whole list
/// before the next one starts (`BoardService.java:82-102`):
///
///  1. the viewer's primary group, if they have one: the first board whose
///     `groups` contains it AND that the viewer is permitted to see;
///  2. permission: the first board that IS gated and whose
///     `gloss.board.<permission>` node the viewer holds — an ungated board can
///     never win this pass;
///  3. primary: the first board flagged `primary` that the viewer is
///     permitted to see.
///
/// "Permitted" is `BoardService.permitted`: an ungated board always, a gated
/// board only with its node. Nothing matching means no sidebar at all.
///
/// The scan order is `BoardService.boards()`, which is sorted by board id, so
/// "first" means lowest id — not authoring order. The group comparison is
/// exact against the ALREADY-NORMALIZED (trimmed, lowercased) group list, so a
/// permissions plugin reporting `VIP` does not match a board listing `vip`.
///
/// DOM-free and store-free so the rules are testable on the VM.
library;

import '../../model/gloss_scoreboard.dart';

/// One board in the selection scan.
final class GlossBoardCandidate {
  const GlossBoardCandidate({
    required this.id,
    required this.primary,
    required this.permission,
    required this.groups,
  });

  /// Built from a decoded document; [id] is the runtime id (the file name),
  /// which is what `GlossBoardMeta` is keyed by.
  factory GlossBoardCandidate.fromDoc(String id, GlossScoreboardDoc doc) =>
      GlossBoardCandidate(
        id: id,
        primary: doc.primary,
        permission: doc.effectivePermission,
        groups: doc.effectiveGroups,
      );

  final String id;
  final bool primary;

  /// Already normalized: `default` means unrestricted.
  final String permission;

  /// Already normalized: trimmed, lowercased, deduplicated.
  final List<String> groups;

  /// `GlossBoardMeta.permissionGated`.
  bool get permissionGated => permission != glossBoardUnrestrictedPermission;

  /// `GlossBoardMeta.permissionNode`.
  String get permissionNode => '$glossBoardPermissionNodePrefix$permission';
}

/// Which pass of the scan picked the winner.
enum GlossBoardSelectionPass {
  /// The viewer's primary group listed the board.
  group,

  /// The viewer holds the board's permission node.
  permission,

  /// The board volunteers as the default.
  primary,

  /// Nothing matched; the viewer sees no sidebar.
  none,
}

/// The outcome of one simulated selection.
final class GlossBoardSelection {
  const GlossBoardSelection({required this.boardId, required this.pass});

  static const GlossBoardSelection empty = GlossBoardSelection(
    boardId: null,
    pass: GlossBoardSelectionPass.none,
  );

  /// The winning board id, or null when the viewer gets no sidebar.
  final String? boardId;

  final GlossBoardSelectionPass pass;
}

/// `BoardService.selectBoardId`. [boards] must already be in the service's
/// id-sorted order; [permissionTest] answers `player.hasPermission(node)`.
GlossBoardSelection glossSelectBoard({
  required String? primaryGroup,
  required List<GlossBoardCandidate> boards,
  required bool Function(String node) permissionTest,
}) {
  bool permitted(GlossBoardCandidate board) =>
      !board.permissionGated || permissionTest(board.permissionNode);

  if (primaryGroup != null && primaryGroup.trim().isNotEmpty) {
    for (final GlossBoardCandidate board in boards) {
      if (board.groups.contains(primaryGroup) && permitted(board)) {
        return GlossBoardSelection(
          boardId: board.id,
          pass: GlossBoardSelectionPass.group,
        );
      }
    }
  }
  for (final GlossBoardCandidate board in boards) {
    if (board.permissionGated && permissionTest(board.permissionNode)) {
      return GlossBoardSelection(
        boardId: board.id,
        pass: GlossBoardSelectionPass.permission,
      );
    }
  }
  for (final GlossBoardCandidate board in boards) {
    if (board.primary && permitted(board)) {
      return GlossBoardSelection(
        boardId: board.id,
        pass: GlossBoardSelectionPass.primary,
      );
    }
  }
  return GlossBoardSelection.empty;
}
