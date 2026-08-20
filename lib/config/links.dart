/// Outbound links surfaced in the help dialog and the top bar.
library;

const String huiGitHubUrl = 'https://github.com/VolmitSoftware/Gloss';
const String huiDiscordUrl =
    'https://discord.com/invite/volmit-software-189665083817852928';
const String huiDocsUrl = 'https://docs.volmit.com/gloss';
const String huiSiteUrl = 'https://www.volmit.com';

/// Where the plugin looks for menus, images and container-preview documents,
/// quoted verbatim in help copy.
const String huiPluginFolder = 'plugins/Gloss/';
const String huiMenuFolder = '${huiPluginFolder}menus/';
const String huiImageFolder = '${huiPluginFolder}images/';
const String huiPreviewFolder = '${huiPluginFolder}previews/';
const String huiHologramFolder = '${huiPluginFolder}holograms/';
const String huiAnimationFolder = '${huiPluginFolder}animations/';
const String huiScoreboardFolder = '${huiPluginFolder}boards/';
const String huiEmojiFolder = '${huiPluginFolder}emoji/';
const String huiBubbleFolder = '${huiPluginFolder}bubbles/';
const String huiMotdFile = '${huiPluginFolder}motd.json';
const String huiTablistFile = '${huiPluginFolder}tablist.json';

/// One external destination in the help dialog's link grid.
class HuiLink {
  const HuiLink({
    required this.label,
    required this.url,
    required this.description,
    required this.icon,
  });

  final String label;
  final String url;
  final String description;

  /// Name of the lucide glyph the help dialog resolves; keeping it a string
  /// keeps this file free of any UI dependency.
  final String icon;
}

const List<HuiLink> huiLinks = <HuiLink>[
  HuiLink(
    label: 'Documentation',
    url: huiDocsUrl,
    description: 'Menu format reference, commands and permissions.',
    icon: 'book',
  ),
  HuiLink(
    label: 'GitHub',
    url: huiGitHubUrl,
    description: 'Source, issue tracker and releases.',
    icon: 'github',
  ),
  HuiLink(
    label: 'Discord',
    url: huiDiscordUrl,
    description: 'Volmit Software community and support.',
    icon: 'chat',
  ),
  HuiLink(
    label: 'volmit.com',
    url: huiSiteUrl,
    description: 'The rest of the Volmit Software catalogue.',
    icon: 'globe',
  ),
];
