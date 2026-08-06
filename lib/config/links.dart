/// Outbound links surfaced in the help dialog and the top bar.
///
/// Every URL is verified against the live HoloUI project. The docs host uses
/// `holoui` (no `g`); the old editor linked `hologui` in two places, which is a
/// dead path.
library;

const String huiGitHubUrl = 'https://github.com/VolmitSoftware/HoloUi';
const String huiDiscordUrl =
    'https://discord.com/invite/volmit-software-189665083817852928';
const String huiDocsUrl = 'https://docs.volmit.com/holoui';
const String huiSiteUrl = 'https://www.volmit.com';

/// Where the plugin looks for menus, images and container-preview documents,
/// quoted verbatim in help copy.
const String huiPluginFolder = 'plugins/holoui/';
const String huiMenuFolder = '${huiPluginFolder}menus/';
const String huiImageFolder = '${huiPluginFolder}images/';
const String huiPreviewFolder = '${huiPluginFolder}previews/';

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
