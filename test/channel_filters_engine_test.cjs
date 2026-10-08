const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');
const crypto = require('node:crypto');
globalThis.RE2JS = require('../web/vendor/re2js/re2js.js');
require('../web/channel-filters.js');
const fixtures = JSON.parse(fs.readFileSync(path.join(process.env.GLOSS_REPO || '../Gloss', 'src/test/resources/chat/filter-conformance.json'), 'utf8'));
for (const fixture of fixtures) {
  test(fixture.name, () => {
    const doc = {filters: fixture.filters, filtering: fixture.filtering};
    if (fixture.invalid) assert.notEqual(GlossChannelFilters.validate(doc), null);
    else {
      assert.equal(GlossChannelFilters.validate(doc), null);
      assert.equal(GlossChannelFilters.run(doc, fixture.input, () => 0).message, fixture.expected);
    }
  });
}
test('pinned product engine matches recorded integrity', () => {
  const provenance = JSON.parse(fs.readFileSync('web/vendor/re2js/provenance.json', 'utf8'));
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync('web/vendor/re2js/re2js.js')).digest('hex'), provenance.assetSha256);
});
test('elapsed target uses explicit failure policy', () => {
  let clock = 0;
  const doc = {filters: [{match: 'cat', replace: 'dog'}, {match: 'hello', replace: 'goodbye'}], filtering: {budgetMicros: 1, onLimit: 'keep-completed'}};
  assert.equal(GlossChannelFilters.run(doc, 'cat hello', () => clock++).message, 'dog hello');
  doc.filtering.onLimit = 'drop';
  clock = 0;
  assert.equal(GlossChannelFilters.run(doc, 'cat hello', () => clock++).message, null);
});
test('missing engine is visible without an unsafe fallback', () => {
  const engine = globalThis.RE2JS;
  try {
    globalThis.RE2JS = null;
    const result = GlossChannelFilters.run({filters: [{match: 'a', replace: 'b'}]}, 'a');
    assert.equal(result.message, 'a');
    assert.match(result.notice, /unavailable/);
  } finally { globalThis.RE2JS = engine; }
});

test('behavior matching uses the same bounded RE2 compiler', () => {
  const doc = {matching: {maxPatternCharacters: 32, maxProgramSize: 64}, on: [{trigger: 'chat', pattern: '^hello$'}]};
  assert.equal(GlossChannelFilters.validateBehaviorJson(JSON.stringify(doc)), null);
  doc.on[0].pattern = '(?=a)a';
  assert.notEqual(GlossChannelFilters.validateBehaviorJson(JSON.stringify(doc)), null);
  doc.on[0].pattern = '(a{100}){100}';
  assert.match(GlossChannelFilters.validateBehaviorJson(JSON.stringify(doc)), /maxProgramSize/);
  doc.on[0].pattern = 'a'.repeat(33);
  assert.match(GlossChannelFilters.validateBehaviorJson(JSON.stringify(doc)), /maxPatternCharacters/);
});
