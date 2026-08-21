/// Factory defaults for new documents, components, icons and actions, plus the
/// id sanitizers the store and the export dialog share.
///
/// Every default here is chosen so that a freshly created object already
/// validates clean against `validateHuiMenu`: a new document must never open
/// with red issues the user did not cause.
library;

import '../model/model.dart';

/// Fallback file base name. The plugin names the menu after the file, so this
/// is also the id used by `/gloss menu open <id>` and `gloss.open.<id>`.
const String huiDefaultMenuId = 'my-menu';

/// `MenuDefinitionData` default for a new document: 1.7 blocks up is roughly
/// eye level, 2.5 blocks forward puts the menu at arm's length.
const double huiDefaultMenuHeight = 1.7;
const double huiDefaultMenuDistance = 2.5;

/// The Java API clamps `highlightModifier` to 0..1; 0.05 is the value every
/// shipped example uses.
const double huiDefaultHighlightModifier = 0.05;
const double huiDefaultHitboxWidth = 1.0;
const double huiDefaultHitboxHeight = 0.5;

/// Ticks per animated frame. 2 ticks = 100 ms, which reads as animation without
/// strobing; anything below 1 is rejected by validation.
const int huiDefaultAnimationSpeed = 2;

/// What the runtime uses for a text icon that omits `refreshTicks`: ten ticks,
/// or twice a second (`TextMenuIcon.java:69-81`). Not an editor preference —
/// this is the value the server picks, so the inspector shows it as the
/// default rather than writing it into new icons.
const int huiRuntimeDefaultTextRefreshTicks = 10;

/// What the runtime uses for a player head that omits `refreshTicks`: twenty
/// ticks, or once a second (`PlayerHeadIconData.java:16`). Like the text
/// refresh above, this is the server's value and not an editor preference, so
/// the inspector shows it as the default instead of writing it into new icons.
const int huiRuntimeDefaultPlayerHeadRefreshTicks = 20;

/// Whose head a new `playerHead` icon draws. The three viewer tokens are
/// answered by Gloss itself rather than by PlaceholderAPI
/// (`PlayerHeadMenuIcon.java:34-41`), so a fresh icon shows the person looking
/// at the menu their own head on a bare server with nothing else installed —
/// a literal username would need a Mojang lookup nobody has configured yet,
/// and an empty name is the one value the plugin refuses outright.
const String huiDefaultPlayerHeadSource = '%player_name%';

/// Neutral, always-present material for a new item icon.
const String huiDefaultItemMaterial = 'stone';
const String huiDefaultBlockMaterial = 'minecraft:stone';
const String huiDefaultEntityType = 'minecraft:parrot';

/// Gloss's own placeholder: it always resolves to `true`, so a brand new
/// toggle is valid and visibly demonstrates the condition mechanism.
const String huiDefaultToggleCondition = '%gloss_available%';
const String huiDefaultToggleExpectedValue = 'true';

/// One-line descriptions for the "add component" menu.
const Map<String, String> huiComponentTypeDescriptions = <String, String>{
  'button': 'Clickable. Runs its ordered action list when a player clicks it.',
  'decoration': 'Display only. Draws an icon but cannot be clicked.',
  'toggle':
      'Two states. Picks an icon from a placeholder value checked once at open.',
};

const Map<String, String> huiIconTypeDescriptions = <String, String>{
  'text': 'Minecraft-formatted text, one text display per line.',
  'textImage': 'A stored image drawn one character per pixel.',
  'animatedTextImage': 'A list of images cycled at a fixed tick interval.',
  'item': 'A floating item stack.',
  'block': 'A packet-only block display using its default block state.',
  'customItem': 'An item from a custom-item plugin, resolved by the server.',
  'entity': 'A packet-only living entity with an authored click footprint.',
  'playerHead':
      'An account\'s head on an item display, resolved by the server.',
};

/// Authoring hints for one custom-item provider.
///
/// No two of these plugins agree on an id shape, and the editor cannot ask the
/// server, so the format is spelled out per provider instead of guessed at.
class HuiItemProviderInfo {
  const HuiItemProviderInfo({
    required this.label,
    required this.idFormat,
    required this.example,
  });

  final String label;
  final String idFormat;
  final String example;
}

/// Keyed by the provider ids in `huiCustomItemProviders`. Every id has an
/// entry; the inspector degrades to no hint if one is ever missing.
const Map<String, HuiItemProviderInfo> huiItemProviderInfo =
    <String, HuiItemProviderInfo>{
      'craftengine': HuiItemProviderInfo(
        label: 'CraftEngine',
        idFormat: 'namespace:id, or a bare id searched across namespaces',
        example: 'default:ruby_sword',
      ),
      'itemsadder': HuiItemProviderInfo(
        label: 'ItemsAdder',
        idFormat: 'namespace:id, lowercase',
        example: 'myitems:ruby',
      ),
      'oraxen': HuiItemProviderInfo(
        label: 'Oraxen',
        idFormat: 'bare id (the yml key), case-sensitive',
        example: 'ruby_sword',
      ),
      'nexo': HuiItemProviderInfo(
        label: 'Nexo',
        idFormat: 'bare id (the yml key), case-sensitive',
        example: 'ruby_sword',
      ),
      'mmoitems': HuiItemProviderInfo(
        label: 'MMOItems',
        idFormat: 'TYPE:ID, both conventionally uppercase',
        example: 'SWORD:CUTLASS',
      ),
      'executableitems': HuiItemProviderInfo(
        label: 'ExecutableItems',
        idFormat: 'bare id (the config file name), case-sensitive',
        example: 'MagicWand',
      ),
      'ecoitems': HuiItemProviderInfo(
        label: 'EcoItems',
        idFormat: 'bare id, or ecoitems:id',
        example: 'ecoitems:my_item',
      ),
      'slimefun': HuiItemProviderInfo(
        label: 'Slimefun',
        idFormat: 'bare id in UPPER_SNAKE_CASE, case-sensitive',
        example: 'MAGIC_WORKBENCH',
      ),
      'mythicmobs': HuiItemProviderInfo(
        label: 'MythicMobs',
        idFormat: 'bare item name from your item config',
        example: 'SkeletonKing_Sword',
      ),
      'headdatabase': HuiItemProviderInfo(
        label: 'HeadDatabase',
        idFormat: 'the numeric head id',
        example: '7129',
      ),
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
    case 'block':
      return HuiBlockIcon(huiDefaultBlockMaterial);
    case 'customItem':
      // No id can be defaulted: it belongs to a plugin the editor cannot see.
      // The empty id is flagged as an error until the user types one.
      return HuiCustomItemIcon(huiAutoItemProvider, '', 1);
    case 'entity':
      return HuiEntityIcon(huiDefaultEntityType, 0.5, 0.9);
    case 'playerHead':
      // refreshTicks is left off: 20 is what the runtime uses for an omitted
      // key, so writing it would only add a line that says nothing.
      return HuiPlayerHeadIcon(huiDefaultPlayerHeadSource);
    case 'text':
    default:
      return HuiTextIcon(text);
  }
}

HuiIconStyle createDefaultIconStyle() => HuiIconStyle();

/// Default action for [actionType]; unknown types fall back to a command.
HuiAction createDefaultAction(String actionType) {
  switch (actionType) {
    case 'sound':
      return HuiSoundAction('ui.button.click', 'master', 1, 1);
    case 'navigate':
      return HuiNavigateAction('', 'push');
    case 'message':
      return HuiMessageAction('<gold>Hello %player%</gold>');
    case 'teleport':
      return HuiTeleportAction('minecraft:overworld', 0, 64, 0, 0, 0);
    case 'connect':
      return HuiConnectAction('lobby');
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
}) => HuiComponent(
  uniqueComponentId(type, takenIds),
  offset ?? Vec3.zero(),
  createDefaultComponentData(type),
);

/// One-line descriptions for the preview element list's "add" menu.
const Map<String, String> previewElementTypeDescriptions = <String, String>{
  'panel': 'A flat rectangle. Needs width, height and color.',
  'cell':
      'A small square well, the building block of a grid. Needs size and '
      'color.',
  'slot': 'Draws one inventory item. Needs size and the slot index to read.',
  'label':
      'Minecraft-formatted text. Needs an expression that returns a '
      'string.',
};

/// Default payload for a freshly added preview element of [type]. Chosen so a
/// brand new element already validates clean against [validatePreviewDoc]:
/// every required field for that type is present, and every color is a valid
/// literal.
HuiPreviewElement createDefaultPreviewElement(String type) {
  const String defaultColor = '#FF2B2B33';
  switch (type) {
    case 'panel':
      return HuiPreviewElement(
        'panel',
        width: 40,
        height: 20,
        color: defaultColor,
      );
    case 'slot':
      return HuiPreviewElement('slot', size: 18, index: 0);
    case 'label':
      return HuiPreviewElement('label', text: "'Label'");
    case 'cell':
    default:
      return HuiPreviewElement('cell', size: 8, color: defaultColor);
  }
}

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

const int huiMaxMenuIdLength = 255;
const int huiMaxMenuIdSegmentLength = 64;

String sanitizeMenuId(String raw) {
  final String normalized = raw.trim().replaceAll('\\', '/');
  final List<String> segments = <String>[];
  for (final String rawSegment in normalized.split('/')) {
    if (rawSegment.isEmpty || rawSegment == '.' || rawSegment == '..') {
      continue;
    }
    String segment = _sanitize(
      rawSegment,
      _menuIdCharacter,
      huiMaxMenuIdSegmentLength,
      '',
    );
    while (segment.isNotEmpty && !_menuIdFirst.hasMatch(segment[0])) {
      segment = segment.substring(1);
    }
    if (segment.isEmpty) continue;
    final int used =
        segments.fold<int>(
          0,
          (int total, String value) => total + value.length,
        ) +
        (segments.isEmpty ? 0 : segments.length - 1);
    final int remaining =
        huiMaxMenuIdLength - used - (segments.isEmpty ? 0 : 1);
    if (remaining <= 0) break;
    segments.add(
      segment.length <= remaining ? segment : segment.substring(0, remaining),
    );
    if (remaining < segment.length) break;
  }
  return segments.isEmpty ? huiDefaultMenuId : segments.join('/');
}

String? validateMenuId(String raw) {
  if (raw.isEmpty || raw != raw.trim()) {
    return 'Menu id must not be blank or have surrounding whitespace.';
  }
  if (raw.length > huiMaxMenuIdLength) {
    return 'Menu id must be at most $huiMaxMenuIdLength characters.';
  }
  if (raw.contains('\\')) {
    return 'Menu id must use forward slashes between folders.';
  }
  for (final String segment in raw.split('/')) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      return 'Menu id contains an empty, dot, or traversal segment.';
    }
    if (segment.length > huiMaxMenuIdSegmentLength ||
        !_menuIdSegment.hasMatch(segment)) {
      return 'Each menu id segment must start with a letter or number and use '
          'only letters, numbers, dots, underscores, or hyphens.';
    }
  }
  return null;
}

bool isCanonicalMenuId(String raw) => validateMenuId(raw) == null;

/// Strips a trailing `.json` before sanitizing, for imported file names.
String menuIdFromFileName(String fileName) {
  String base = fileName.trim().replaceAll('\\', '/');
  final String lower = base.toLowerCase();
  final int menuRoot = lower.lastIndexOf('/menus/');
  if (menuRoot >= 0) {
    base = base.substring(menuRoot + '/menus/'.length);
  } else if (lower.startsWith('menus/')) {
    base = base.substring('menus/'.length);
  }
  if (base.toLowerCase().endsWith('.json')) {
    base = base.substring(0, base.length - 5);
  }
  return sanitizeMenuId(base);
}

final RegExp _componentIdAllowed = RegExp(r'[A-Za-z0-9_.-]');
final RegExp _menuIdCharacter = RegExp(r'[A-Za-z0-9._-]');
final RegExp _menuIdFirst = RegExp(r'[A-Za-z0-9]');
final RegExp _menuIdSegment = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

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
