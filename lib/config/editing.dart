/// Editing step sizes shared by the canvas and the shell.
///
/// These were duplicated: the arrow-key nudge was declared in both
/// `canvas_viewport.dart` and `shortcut_sheet.dart`, and the depth step in both
/// `shell_intents.dart` (as `huiDepthStep`) and `canvas_toolbar.dart` (as
/// `huiZOrderStep`). Two surfaces that restack or nudge by different amounts is
/// a bug the user feels and nothing catches, so they live here instead.
///
/// Deliberately free of imports. The canvas half of the app pulls in
/// `package:web`, which the shell must stay clear of and which `dart test`
/// cannot load at all — a neutral file is the only home both sides can reach.
library;

/// Arrow-key nudge distance in blocks, and the Shift-modified nudge.
const double huiNudgeStep = 0.05;
const double huiNudgeStepLarge = 0.25;

/// Depth change per z-order step, in blocks.
///
/// Depth is not a layout axis: it only decides which icon draws over which
/// (`canvas_scene.dart` paints larger `z` first), and click dispatch is
/// declaration order regardless (`MenuSessionManager.java:170-203`). A
/// hundredth of a block reorders the draw without moving anything a player
/// could measure.
const double huiDepthStep = 0.01;
