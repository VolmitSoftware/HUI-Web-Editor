/// The MOTD surface: a server-list mock row, the way the vanilla multiplayer
/// screen draws it.
///
/// Each simulated ping selects one eligible entry using the response policy
/// and renders its joined lines through the static text preview — functions (so
/// `|animation.<id>|`) and colours apply, PlaceholderAPI tokens stay literal
/// because a ping has no viewer. The entry chips address one entry directly.
/// The 64x64 icon slot draws the resolved favicon (the entry's own, else the
/// document's) straight from the image library; a path the library holds no
/// bytes for leaves the vanilla placeholder, exactly as a ping without an icon
/// does.
///
/// The rest of `applyExtras` draws too, through `motd_preview.dart`: the
/// counts read `online/max` when the entry authors them and the sampled figure
/// when it does not, and the hover sample uses the floating tooltip surface.
/// The preview represents a compatible client, so a version label does not
/// replace the player count or ping bars. The bars and the sampled count are
/// cosmetic. Request simulation applies the selected platform's field support.
///
/// With `gameContext` the server row mounts into the shared game-screen frame
/// as the multiplayer GUI screen it already looks like — no HUD behind it,
/// because a GUI screen replaces the world view.
///
/// Holds one sampled frame until Refresh is pressed, matching the client: an
/// already displayed server-list row is not redrawn between status pings.
library;

import '../../logic/gloss_show.dart';
import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../logic/motd_preview.dart';
import '../../model/model.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../inspector/inspector_widgets.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class MotdView extends StatefulWidget {
  const MotdView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the server row inside the shared Minecraft game-screen frame
  /// instead of the editor stage. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<MotdView> createState() => _MotdViewState();
}

class _MotdViewState extends State<MotdView> {
  /// The previewed entry. Clamped on read: the inspector can shorten the
  /// list under it.
  int _entryIndex = 0;
  int _sampledAtMs = DateTime.now().millisecondsSinceEpoch;
  bool _simulate = false;
  String _hostname = 'play.example.org';
  String _protocol = '771';
  String _requestTime = DateTime.now().toUtc().toIso8601String();
  String _online = '17';
  String _maximum = '100';
  String _state = '';
  bool _motdEnabled = true;
  MotdPreviewPlatform _platform = MotdPreviewPlatform.paper;
  int _sequence = 0;
  int _randomSeed = 0;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant MotdView oldComponent) {
    super.didUpdateWidget(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _refreshSample() {
    setState(() {
      if (!_simulate) _sampledAtMs = DateTime.now().millisecondsSinceEpoch;
      _sequence++;
      _randomSeed++;
    });
  }

  void _selectEntry(int index) {
    setState(() {
      _simulate = false;
      _entryIndex = index;
      _sampledAtMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc? doc = _store.motdDoc;
    if (doc == null) {
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.screen,
          label: huiText('Server list entry in game'),
        );
      }
      return const dom.div(classes: 'hui-motd-stage is-empty', <Widget>[]);
    }
    final GlossAnimationResolver animations = _store.workspaceAnimations;
    MotdPreviewResult? result;
    MotdPreviewRequest? request;
    String? requestError;
    if (_simulate) {
      try {
        request = _request();
        _sampledAtMs = request.epochMillis;
        result = simulateMotdRequest(
          doc,
          request,
          sequence: _sequence,
          randomSeed: _randomSeed,
        );
      } on FormatException {
        requestError = huiText(
          'The request cannot be simulated. Check the UTC instant, nonnegative counts, protocol number, and document clock settings.',
        );
      }
    }
    final int shown = doc.entries.isEmpty
        ? 0
        : _entryIndex.clamp(0, doc.entries.length - 1);
    final int nowMs = _sampledAtMs;
    final GlossMotdEntry? entry = _simulate
        ? result?.selectedIndex == null
              ? null
              : doc.entries[result!.selectedIndex!]
        : doc.entries.isEmpty
        ? null
        : doc.entries[shown];
    final GlossMotdEntry? ping = _simulate
        ? entry
        : entry != null &&
              glossShowMatches(
                doc.extras['show'],
                nowMs: nowMs,
                viewerAware: false,
              ) &&
              glossShowMatches(entry.show, nowMs: nowMs, viewerAware: false)
        ? entry
        : null;
    final int realOnline = request?.online ?? glossMotdSampledOnline;
    final int realMaximum = request?.maximum ?? glossMotdSampledMax;
    final MotdPreviewPlatform platform =
        request?.platform ?? MotdPreviewPlatform.paper;
    final GlossTextExpressionSamples samples = motdExpressionSamples(
      realOnline,
      realMaximum,
    );
    final List<String> lines = ping == null
        ? const <String>[]
        : ping.lines.take(glossMotdMaxLinesPerEntry).toList();
    final List<String> sample = glossMotdSampleLines(ping, platform: platform);
    final String? favicon = _simulate
        ? result?.icon
        : ping == null
        ? null
        : doc.iconsFor(ping).isNotEmpty
        ? doc.iconsFor(ping).first
        : doc.faviconFor(ping);

    final Widget row = dom.div(classes: 'hui-motd-row', <Widget>[
      _icon(favicon),
      dom.div(classes: 'hui-motd-row-body', <Widget>[
        dom.div(classes: 'hui-motd-row-head', <Widget>[
          dom.span(classes: 'hui-motd-server-name', <Widget>[
            Text(huiText('My Server')),
          ]),
          dom.span(classes: 'hui-motd-row-status', <Widget>[
            _playerCount(
              ping,
              sample,
              animations,
              nowMs,
              realOnline,
              realMaximum,
              platform,
            ),
            dom.span(classes: 'hui-motd-ping', <Widget>[
              for (int bar = 0; bar < 5; bar++)
                dom.span(
                  classes: 'hui-motd-ping-bar${bar < 4 ? ' is-filled' : ''}',
                  const <Widget>[],
                ),
            ]),
          ]),
        ]),
        if (doc.entries.isEmpty)
          dom.div(classes: 'hui-motd-line is-blank', <Widget>[
            Text(huiText('No entries — Gloss would reject this file.')),
          ])
        else if (ping == null)
          dom.div(classes: 'hui-motd-line is-blank', <Widget>[
            Text(huiText('Original server response retained.')),
          ])
        else
          for (final String line in lines)
            dom.div(classes: 'hui-motd-line', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  line,
                  animations: animations,
                  emoji: _store.workspaceEmoji,
                  nowMs: nowMs,
                  viewerAware: false,
                  expressionSamples: samples,
                ),
              ),
            ]),
      ]),
    ]);

    if (component.gameContext) {
      return dom.div(classes: 'hui-motd-stage', <Widget>[
        _requestControls(doc, result, requestError),
        GlossGameScreen(
          anchor: GlossGameAnchor.screen,
          label: huiText('Server list entry in game'),
          controls: <Widget>[_refresh()],
          child: dom.div(classes: 'hui-motd-screen', <Widget>[row]),
        ),
      ]);
    }

    return dom.div(classes: 'hui-motd-stage', <Widget>[
      _requestControls(doc, result, requestError),
      GlossPreviewZoom(
        label: huiText('MOTD preview'),
        child: dom.div(classes: 'hui-motd-screen', <Widget>[
          row,
          dom.div(classes: 'hui-motd-controls', <Widget>[
            dom.span(classes: 'hui-motd-entry-label', <Widget>[
              Text(huiText('Preview entry')),
            ]),
            dom.div(classes: 'hui-motd-entry-chips', <Widget>[
              for (int index = 0; index < doc.entries.length; index++)
                dom.button(
                  classes:
                      'hui-motd-entry-chip${index == shown ? ' is-active' : ''}',
                  attributes: <String, String>{
                    'type': 'button',
                    'aria-label': huiText(
                      "Preview entry {value}",
                      <String, Object?>{'value': index + 1},
                    ),
                  },
                  events: <String, EventCallback>{
                    'click': (Object? _) => _selectEntry(index),
                  },
                  <Widget>[
                    Text(
                      huiText("{value}", <String, Object?>{'value': index + 1}),
                    ),
                  ],
                ),
            ]),
            _refresh(),
          ]),
        ]),
      ),
      dom.div(classes: 'hui-motd-readout', <Widget>[
        Text(
          _simulate
              ? huiText('Simulated request; Refresh samples another response.')
              : _readout(doc, entry, shown),
        ),
      ]),
    ]);
  }

  MotdPreviewRequest _request() {
    final DateTime? time = DateTime.tryParse(_requestTime);
    if (time == null ||
        !RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(_requestTime)) {
      throw const FormatException('UTC instant required');
    }
    int count(String value) {
      final int? parsed = int.tryParse(value);
      if (parsed == null || parsed < 0 || parsed > 2147483647) {
        throw const FormatException('Invalid count');
      }
      return parsed;
    }

    return MotdPreviewRequest(
      epochMillis: time.millisecondsSinceEpoch,
      hostname: _hostname,
      protocol: _protocol.trim().isEmpty ? null : count(_protocol),
      online: count(_online),
      maximum: count(_maximum),
      state: _state.isEmpty ? null : _state,
      platform: _platform,
      motdEnabled: _motdEnabled,
    );
  }

  Widget _requestControls(
    GlossMotdDoc doc,
    MotdPreviewResult? result,
    String? error,
  ) {
    Widget input(String label, String value, void Function(String) changed) =>
        HuiField(
          label: label,
          control: TextInput(
            value: value,
            fullWidth: true,
            attributes: <String, String>{'aria-label': label},
            onChanged: (String value) => setState(() => changed(value)),
          ),
        );
    return dom.div(classes: 'hui-motd-request', <Widget>[
      InspectorSection(
        title: huiText('Status request simulator'),
        sectionKey: 'motd.request',
        children: <Widget>[
          HuiSwitchRow(
            label: huiText('Simulate request selection'),
            value: _simulate,
            onChanged: (bool value) => setState(() => _simulate = value),
          ),
          if (_simulate) ...<Widget>[
            ArcaneSelect(
              value: _platform.name,
              label: huiText('Server platform'),
              options: <ArcaneSelectOption>[
                for (final MotdPreviewPlatform platform
                    in MotdPreviewPlatform.values)
                  ArcaneSelectOption(
                    value: platform.name,
                    label: platform.name,
                  ),
              ],
              onChanged: (String value) => setState(
                () => _platform = MotdPreviewPlatform.values.byName(value),
              ),
            ),
            input(
              huiText('Requested hostname'),
              _hostname,
              (String value) => _hostname = value,
            ),
            input(
              huiText('Client protocol number'),
              _protocol,
              (String value) => _protocol = value,
            ),
            input(
              huiText('Request instant'),
              _requestTime,
              (String value) => _requestTime = value,
            ),
            input(
              huiText('Real online count'),
              _online,
              (String value) => _online = value,
            ),
            input(
              huiText('Real maximum count'),
              _maximum,
              (String value) => _maximum = value,
            ),
            input(
              huiText('Simulated server state'),
              _state,
              (String value) => _state = value,
            ),
            HuiSwitchRow(
              label: huiText('MOTD feature enabled'),
              value: _motdEnabled,
              onChanged: (bool value) => setState(() => _motdEnabled = value),
            ),
            HuiNote(
              huiText(
                'Use an ISO instant with Z or an explicit UTC offset. Blank state uses the document state. Blank protocol means unavailable metadata. Spigot does not expose protocol selectors, player samples, online-count overrides or server links.',
              ),
            ),
            if (error != null)
              dom.p(
                attributes: const <String, String>{'role': 'alert'},
                <Widget>[Text(error)],
              ),
            if (result != null) ...<Widget>[
              dom.p(
                attributes: const <String, String>{
                  'data-motd-request-result': 'true',
                  'aria-live': 'polite',
                },
                <Widget>[
                  Text(
                    result.selectedIndex == null
                        ? huiText(
                            'No eligible response; the original ping is retained.',
                          )
                        : huiText(
                            'Selected entry {index}; {count} eligible responses.',
                            <String, Object?>{
                              'index': result.selectedIndex! + 1,
                              'count': result.eligible.length,
                            },
                          ),
                  ),
                ],
              ),
              HuiNote(
                huiText(
                  'Sequence position {position}. Weighted samples are reproducible in this preview; a live server uses its own random source.',
                  <String, Object?>{'position': _sequence},
                ),
              ),
              HuiNote(
                huiText('Resolved icon: {icon}', <String, Object?>{
                  'icon': result.icon ?? huiText('Original server icon'),
                }),
              ),
              dom.p(<Widget>[
                Text(
                  huiText('Published server links: {count}', <String, Object?>{
                    'count': result.links.length,
                  }),
                ),
              ]),
              for (final GlossMotdLink link in result.links)
                dom.p(<Widget>[
                  Text(
                    '${link.isLabelled ? link.label : link.type}: ${link.url}',
                  ),
                ]),
            ],
          ] else
            HuiNote(
              huiText(
                'Entry inspection bypasses request selectors. Enable simulation to test the response policy.',
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _playerCount(
    GlossMotdEntry? entry,
    List<String> sample,
    GlossAnimationResolver animations,
    int nowMs,
    int realOnline,
    int realMaximum,
    MotdPreviewPlatform platform,
  ) {
    final Widget count = dom.span(
      classes: 'hui-motd-count',
      attributes: <String, String>{if (sample.isNotEmpty) 'tabindex': '0'},
      <Widget>[
        dom.span(classes: 'hui-motd-players', <Widget>[
          Text(
            glossMotdPlayerCount(
              entry,
              animations: animations,
              emoji: _store.workspaceEmoji,
              nowMs: nowMs,
              realOnline: realOnline,
              realMaximum: realMaximum,
              platform: platform,
            ),
          ),
        ]),
      ],
    );
    if (sample.isEmpty) return count;
    return ArcaneTooltip.custom(
      position: FloatingPosition.bottomEnd,
      child: count,
      content: dom.div(classes: 'hui-motd-sample', <Widget>[
        for (final String line in sample)
          dom.div(classes: 'hui-motd-sample-line', <Widget>[
            GlossTextLine(
              render: renderGlossLine(
                line,
                animations: animations,
                emoji: _store.workspaceEmoji,
                nowMs: nowMs,
                viewerAware: false,
                expressionSamples: motdExpressionSamples(
                  realOnline,
                  realMaximum,
                ),
              ),
            ),
          ]),
      ]),
    );
  }

  /// The 64x64 server-list slot. The image library already holds every
  /// uploaded and synced asset as a data URI, so the resolved icon draws for
  /// real; a path the library has no bytes for keeps the vanilla placeholder,
  /// which is what the client shows when the server sends no icon.
  Widget _icon(String? favicon) {
    final StoredImage? stored = favicon == null
        ? null
        : _store.images?.byPath(favicon);
    if (stored == null) {
      return const dom.div(classes: 'hui-motd-icon', <Widget>[
        dom.span(classes: 'hui-motd-icon-glyph', <Widget>[Text('▚')]),
      ]);
    }
    return dom.div(classes: 'hui-motd-icon has-favicon', <Widget>[
      dom.img(
        src: stored.dataUri,
        alt: stored.path,
        styles: const dom.Styles(
          raw: <String, String>{'image-rendering': 'pixelated'},
        ),
      ),
    ]);
  }

  Widget _refresh() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _refreshSample,
    attributes: <String, String>{
      'aria-label': huiText('Refresh'),
      'title': huiText('Refresh'),
    },
    icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
  );

  String _readout(GlossMotdDoc doc, GlossMotdEntry? entry, int shown) {
    final List<String> parts = <String>[
      doc.entries.isEmpty
          ? huiText('no entries')
          : huiText('Inspecting entry {current} of {total}', <String, Object?>{
              'current': shown + 1,
              'total': doc.entries.length,
            }),
      if (entry != null && entry.sample.isNotEmpty)
        huiText('hover the count to read the sample'),
      if (entry != null && entry.lines.length > glossMotdMaxLinesPerEntry)
        huiPlural(
          'motd.readout.excess-lines',
          entry.lines.length,
          oneEnglish: 'entry has {count} line; Gloss rejects past {maximum}',
          otherEnglish: 'entry has {count} lines; Gloss rejects past {maximum}',
          arguments: <String, Object?>{'maximum': glossMotdMaxLinesPerEntry},
        ),
      huiText('placeholders stay literal (a ping has no viewer)'),
    ];
    return parts.join(' · ');
  }
}
