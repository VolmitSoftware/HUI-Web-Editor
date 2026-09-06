/// Username to skin through Mojang's public profile chain, with the client
/// injected so the test never touches the network.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

final class ResolvedSkin {
  const ResolvedSkin({
    required this.username,
    required this.uuid,
    required this.slim,
    required this.skinPng,
    this.capePng,
  });

  final String username;
  final String uuid;
  final bool slim;
  final Uint8List skinPng;
  final Uint8List? capePng;
}

Future<ResolvedSkin> resolveSkin(String username, http.Client client) async {
  final http.Response profile = await client.get(
    Uri.parse('https://api.mojang.com/users/profiles/minecraft/$username'),
  );
  if (profile.statusCode != 200) {
    throw StateError('profile lookup for $username: HTTP ${profile.statusCode}');
  }
  final Map<String, Object?> profileJson =
      jsonDecode(profile.body) as Map<String, Object?>;
  final String uuid = profileJson['id'] as String;
  final http.Response session = await client.get(
    Uri.parse('https://sessionserver.mojang.com/session/minecraft/profile/$uuid'),
  );
  if (session.statusCode != 200) {
    throw StateError('session profile for $uuid: HTTP ${session.statusCode}');
  }
  final Map<String, Object?> sessionJson =
      jsonDecode(session.body) as Map<String, Object?>;
  final List<Object?> properties = sessionJson['properties'] as List<Object?>;
  final Map<String, Object?> texturesProperty = properties
      .cast<Map<String, Object?>>()
      .firstWhere((Map<String, Object?> p) => p['name'] == 'textures');
  final Map<String, Object?> decoded = jsonDecode(
    utf8.decode(base64.decode(texturesProperty['value'] as String)),
  ) as Map<String, Object?>;
  final Map<String, Object?> textures = decoded['textures'] as Map<String, Object?>;
  final Map<String, Object?> skin = textures['SKIN'] as Map<String, Object?>;
  final Map<String, Object?>? metadata = skin['metadata'] as Map<String, Object?>?;
  final bool slim = metadata?['model'] == 'slim';
  final http.Response skinPng = await client.get(Uri.parse(skin['url'] as String));
  if (skinPng.statusCode != 200) {
    throw StateError('skin download for $username: HTTP ${skinPng.statusCode}');
  }
  Uint8List? capePng;
  final Map<String, Object?>? cape = textures['CAPE'] as Map<String, Object?>?;
  if (cape != null) {
    final http.Response capeResponse = await client.get(Uri.parse(cape['url'] as String));
    if (capeResponse.statusCode == 200) capePng = capeResponse.bodyBytes;
  }
  return ResolvedSkin(
    username: username,
    uuid: uuid,
    slim: slim,
    skinPng: skinPng.bodyBytes,
    capePng: capePng,
  );
}
