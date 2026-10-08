import '../logic/json_schema.dart';

const GlossJsonField glossDisplayRefreshField = GlossJsonField(key: 'refresh', type: GlossJsonType.object,
  title: 'Display refresh', summary: 'Independent refresh intervals; omitted fields keep the current surface cadence.',
  node: GlossJsonObject(fields: <GlossJsonField>[
    GlossJsonField(key: 'contentTicks', type: GlossJsonType.integer, title: 'Content ticks', summary: 'Text content refresh, 1 through 1200 ticks. Animation frames retain their own clock.'),
    GlossJsonField(key: 'visibilityTicks', type: GlossJsonType.integer, title: 'Visibility ticks', summary: 'Visibility and presentation conditions, 1 through 1200 ticks.'),
    GlossJsonField(key: 'motionTicks', type: GlossJsonType.integer, title: 'Motion ticks', summary: 'Motion bindings or persistent object and box refresh, 1 through 1200 ticks.'),
  ]));
