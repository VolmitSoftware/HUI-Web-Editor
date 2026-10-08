const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function main() {
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE} : {})});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
    await page.waitForSelector('#hui-library-new-document');
    if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
    const fixture = {schemaVersion: 3, revision: 7, show: true,
      headerFooter: {enabled: true, presentation: {header: 'Roster', footer: 'Footer'}, variants: []},
      listNames: {enabled: true, presentation: {format: '$player'}, variants: []},
      layout: {enabled: true, show: true, entries: 20,
        slots: [{column: 0, row: 0, text: 'Welcome {{ viewer.name }}', skin: 'brand', ping: 77, hat: true, custom: 'cell-retained'}],
        sections: [{id: 'players', column: 0, row: 1, columns: 1, rows: 3, filter: 'true',
          format: '$player', sort: [{expression: 'subject.name', type: 'text', direction: 'descending'}],
          overflow: 'count', overflowFormat: '+{count} more', includeNpcs: false, skin: 'brand', hat: false}],
        skins: {brand: {value: 'synthetic-texture', signature: 'synthetic-signature', custom: 'skin-retained'}},
        variants: [{id: 'event', priority: 30, when: 'false', presentation: {entries: 20,
          slots: [{column: 0, row: 0, text: 'EVENT ACTIVE', hat: true}], sections: [], skins: {}}}]}};
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.waitForSelector('.hui-tablist-grid');
    await page.getByLabel('Base layout cell 1 text', {exact: true}).fill('Updated {{ viewer.name }}');
    await page.getByLabel('Base layout cell 1 text', {exact: true}).press('Tab');
    await page.getByRole('switch', {name: 'Base layout cell 1 hat', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.getByLabel('Base layout roster 1 overflow format', {exact: true}).fill('Remaining {count}');
    await page.getByLabel('Base layout roster 1 overflow format', {exact: true}).press('Tab');
    await page.getByLabel('Layout variant 1 condition', {exact: true}).fill('true');
    await page.getByLabel('Layout variant 1 condition', {exact: true}).press('Tab');
    await page.waitForFunction(() => document.querySelector('.hui-tablist-grid')?.textContent.includes('EVENT ACTIVE'));
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(output.schemaVersion, 3);
    assert.equal(output.revision, 7);
    assert.equal(output.layout.entries, 20);
    assert.equal(output.layout.slots[0].text, 'Updated {{ viewer.name }}');
    assert.equal(output.layout.slots[0].hat, false);
    assert.equal(output.layout.slots[0].ping, 77);
    assert.equal(output.layout.slots[0].custom, 'cell-retained');
    assert.deepEqual(output.layout.skins.brand, fixture.layout.skins.brand);
    assert.deepEqual(output.layout.sections[0].sort, fixture.layout.sections[0].sort);
    assert.equal(output.layout.sections[0].overflowFormat, 'Remaining {count}');
    assert.equal(output.layout.sections[0].hat, false);
    assert.equal(output.layout.variants[0].when, 'true');
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Tablist browser: schema3 import, typed cell/section edits, keyboard hat toggle, conditional preview, lossless export and viewport checks passed.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
