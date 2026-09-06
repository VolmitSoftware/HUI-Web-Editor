/// Resource ids as the client jar spells them, with the `minecraft:` namespace
/// implicit. Model ids keep their folder (`block/stone`, `item/apple`), texture
/// ids keep theirs (`block/dirt`), item and block ids are bare lower-case keys.
library;

const String _namespace = 'minecraft:';

/// Drops a leading `minecraft:`; any other namespace is left in place.
String mcStrip(String id) =>
    id.startsWith(_namespace) ? id.substring(_namespace.length) : id;

/// A model reference as written in `parent` or an item definition.
String mcModelId(String reference) => mcStrip(reference.trim());

/// A texture reference; `#variable` references pass through untouched.
String mcTextureId(String reference) =>
    reference.startsWith('#') ? reference : mcStrip(reference.trim());

/// A bare lower-case item key, the `items/<key>.json` name.
String mcItemId(String key) => mcStrip(key.trim()).toLowerCase();

/// A bare lower-case block key, the `blockstates/<key>.json` name.
String mcBlockId(String key) => mcStrip(key.trim()).toLowerCase();
