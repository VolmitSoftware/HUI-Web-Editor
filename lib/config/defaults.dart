/// Factory defaults for new documents, components, icons and actions, plus the
/// id sanitizers the store and the export dialog share.
///
/// Every default here is chosen so that a freshly created object already
/// validates clean against `validateHuiMenu`: a new document must never open
/// with red issues the user did not cause.
library;

import '../model/model.dart';

/// Fallback file base name. The plugin names the menu after the file, so this
/// is also the id used by `/holoui open <id>` and `holoui.open.<id>`.
const String huiDefaultMenuId = 'my-menu';

/// `MenuDefinitionData` default for a new document: 1.7 blocks up is roughly
/// eye level, 2.5 blocks forward puts the menu at arm's length.
const double huiDefaultMenuHeight = 1.7;
const double huiDefaultMenuDistance = 2.5;

/// The Java API clamps `highlightModifier` to 0..1; 0.05 is the value every
/// shipped example uses.
const double huiDefaultHighlightModifier = 0.05;

/// Ticks per animated frame. 2 ticks = 100 ms, which reads as animation without
/// strobing; anything below 1 is rejected by validation.
const int huiDefaultAnimationSpeed = 2;

/// Neutral, always-present material for a new item icon.
const String huiDefaultItemMaterial = 'stone';

/// HoloUI's own placeholder: it always resolves to `true`, so a brand new
/// toggle is valid and visibly demonstrates the condition mechanism.
const String huiDefaultToggleCondition = '%holoui_available%';
const String huiDefaultToggleExpectedValue = 'true';

/// One-line descriptions for the "add component" menu.
const Map<String, String> huiComponentTypeDescriptions = <String, String>{
  'button': 'Clickable. Runs commands and plays sounds when a player clicks it.',
  'decoration': 'Display only. Draws an icon but cannot be clicked.',
  'toggle':
      'Two states. Picks an icon from a placeholder value checked once at open.',
};

const Map<String, String> huiIconTypeDescriptions = <String, String>{
  'text': 'Minecraft-formatted text, one text display per line.',
  'textImage': 'A stored image drawn one character per pixel.',
  'animatedTextImage': 'A list of images cycled at a fixed tick interval.',
  'item': 'A floating item stack.',
};

/// The starting document: menu at eye level, one visible title so the canvas is
/// never empty.
HuiMenu createDefaultMenu() => HuiMenu(
      offset: Vec3(0, huiDefaultMenuHeight, huiDefaultMenuDistance),
      lockPosition: false,
      followPlayer: true,
      closeOnDeath: true,
      closeOnTeleport: true,
      components: <HuiComponent>[
        HuiComponent(
          'title',
          Vec3(0, 0.85, 0),
          HuiDecorationData(HuiTextIcon('&6&lMy Menu')),
        ),
      ],
    );

/// Default icon for [iconType]; unknown types fall back to a text icon.
HuiIcon createDefaultIcon(String iconType, {String text = '&fNew text'}) {
  switch (iconType) {
    case 'textImage':
      return HuiTextImageIcon();
    case 'animatedTextImage':
      return HuiAnimatedImageIcon(<String>[], huiDefaultAnimationSpeed);
    case 'item':
      return HuiItemIcon(huiDefaultItemMaterial, 1, 0);
    case 'text':
    default:
      return HuiTextIcon(text);
  }
}

/// Default action for [actionType]; unknown types fall back to a command.
HuiAction createDefaultAction(String actionType) {
  switch (actionType) {
    case 'sound':
      return HuiSoundAction('ui.button.click', 'master', 1, 1);
    case 'command':
    default:
      return HuiCommandAction('', 'player');
  }
}

/// Default payload for [type]; unknown types fall back to a decoration.
HuiComponentData createDefaultComponentData(String type) {
  switch (type) {
    case 'button':
      return HuiButtonData(
        huiDefaultHighlightModifier,
        <HuiAction>[],
        HuiTextIcon('&fNew button'),
      );
    case 'toggle':
      return HuiToggleData(
        huiDefaultHighlightModifier,
        huiDefaultToggleCondition,
        huiDefaultToggleExpectedValue,
        <HuiAction>[],
        <HuiAction>[],
        HuiTextIcon('&aOn'),
        HuiTextIcon('&cOff'),
      );
    case 'decoration':
    default:
      return HuiDecorationData(HuiTextIcon('&fNew text'));
  }
}

/// A ready-to-insert component with a readable unique id.
HuiComponent createDefaultComponent({
  required String type,
  required Set<String> takenIds,
  Vec3? offset,
}) =>
    HuiComponent(
      uniqueComponentId(type, takenIds),
      offset ?? Vec3.zero(),
      createDefaultComponentData(type),
    );

/// `button`, then `button-2`, `button-3`... Readable ids matter: they are what
/// the Java API addresses and what the rail shows.
String uniqueComponentId(String base, Set<String> taken) {
  final String root = sanitizeComponentId(base);
  if (!taken.contains(root)) return root;
  for (int i = 2; i < 100000; i++) {
    final String candidate = '$root-$i';
    if (!taken.contains(candidate)) return candidate;
  }
  return '$root-${DateTime.now().millisecondsSinceEpoch}';
}

/// Component ids are addressed by the Java API, which sanitizes to
/// `[A-Za-z0-9_.-]` and truncates at 64 characters. Case is preserved.
String sanitizeComponentId(String raw) =>
    _sanitize(raw, _componentIdAllowed, 64, 'component');

/// Menu ids double as file base names and permission nodes
/// (`holoui.open.<id>`), so they are lowercased and kept to `[a-z0-9_-]`.
String sanitizeMenuId(String raw) =>
    _sanitize(raw.toLowerCase(), _menuIdAllowed, 64, huiDefaultMenuId);

/// Strips a trailing `.json` before sanitizing, for imported file names.
String menuIdFromFileName(String fileName) {
  String base = fileName.trim();
  final int slash = base.lastIndexOf('/');
  if (slash >= 0) base = base.substring(slash + 1);
  if (base.toLowerCase().endsWith('.json')) {
    base = base.substring(0, base.length - 5);
  }
  return sanitizeMenuId(base);
}

final RegExp _componentIdAllowed = RegExp(r'[A-Za-z0-9_.-]');
final RegExp _menuIdAllowed = RegExp(r'[a-z0-9_-]');

String _sanitize(String raw, RegExp allowed, int maxLength, String fallback) {
  final StringBuffer buffer = StringBuffer();
  bool lastWasSeparator = false;
  for (final String character in raw.trim().split('')) {
    if (allowed.hasMatch(character)) {
      buffer.write(character);
      lastWasSeparator = false;
    } else if (!lastWasSeparator) {
      buffer.write('-');
      lastWasSeparator = true;
    }
  }
  String out = buffer.toString();
  while (out.startsWith('-')) {
    out = out.substring(1);
  }
  while (out.endsWith('-')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.length > maxLength) {
    out = out.substring(0, maxLength);
    while (out.endsWith('-')) {
      out = out.substring(0, out.length - 1);
    }
  }
  return out.isEmpty ? fallback : out;
}

/// Vertical step between auto-placed components, in blocks. Matches the default
/// snap grid so auto-placed components land on it.
const double huiPlacementStep = 0.25;

/// Horizontal step used once a column is full.
const double huiPlacementColumnStep = 0.75;

/// First slot in a top-down column that no component already occupies, so
/// "add component" never stacks two icons on the same spot.
Vec3 nextFreeOffset(
  HuiMenu menu, {
  double startY = 0.5,
  double step = huiPlacementStep,
  double columnStep = huiPlacementColumnStep,
  int rows = 12,
  int columns = 8,
}) {
  for (int column = 0; column < columns; column++) {
    final double x = column * columnStep;
    for (int row = 0; row < rows; row++) {
      final double y = startY - row * step;
      if (!_occupied(menu, x, y)) return Vec3(x, y, 0);
    }
  }
  return Vec3(0, startY, 0);
}

bool _occupied(HuiMenu menu, double x, double y) {
  for (final HuiComponent component in menu.components) {
    if ((component.offset.x - x).abs() < 0.02 &&
        (component.offset.y - y).abs() < 0.02) {
      return true;
    }
  }
  return false;
}
