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
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    const fixture = {schemaVersion: 2, revision: 9, channel: {name: 'global'}, format: '{{ message }}',
      mentions: {enabled: false}, filters: [{match: '(?i)hello', replace: '$1\\literal'}],
      filtering: {maxMatches: 16, budgetMicros: 100000, onLimit: 'keep-completed', custom: 'retained'}};
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.waitForSelector('.hui-inspector-body.is-channel');
    await page.getByLabel('Preview chat message').fill('Hello');
    await page.waitForFunction(() => document.querySelector('.hui-connections-line')?.textContent === '$1\\literal');
    await page.getByLabel('Maximum matches', {exact: true}).fill('17');
    await page.getByLabel('Maximum matches', {exact: true}).press('Tab');
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(output.schemaVersion, 2);
    assert.equal(output.revision, 9);
    assert.equal(output.filtering.maxMatches, 17);
    assert.equal(output.filtering.budgetMicros, 100000);
    assert.equal(output.filtering.onLimit, 'keep-completed');
    assert.equal(output.filtering.custom, 'retained');
    assert.equal(output.filters[0].replace, '$1\\literal');
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    await page.getByLabel('RE2 pattern', {exact: true}).fill('(?<=a)b');
    await page.waitForFunction(() => document.body.textContent.includes('invalid named capture') || document.body.textContent.includes('invalid or unsupported Perl syntax'));
    await page.getByLabel('RE2 pattern', {exact: true}).fill('(?i)hello');
    await page.getByRole('button', {name: 'Add variant', exact: true}).click();
    await page.getByRole('switch', {name: 'Override Filter policy', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.getByLabel('Maximum matches', {exact: true}).last().fill('3');
    await page.getByLabel('Maximum matches', {exact: true}).last().press('Tab');
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const variantOutput = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(variantOutput.variants[0].filtering.maxMatches, 3);
    assert.equal(variantOutput.variants[0].filtering.budgetMicros, 100000);
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    await page.evaluate(() => {globalThis.savedChannelEngine = globalThis.GlossChannelFilters; globalThis.GlossChannelFilters = null;});
    await page.getByLabel('Preview chat message').fill('Hello again');
    await page.getByRole('status').filter({hasText: 'RE2 preview engine is unavailable'}).waitFor();
    await page.evaluate(() => {globalThis.GlossChannelFilters = globalThis.savedChannelEngine; delete globalThis.savedChannelEngine;});
    await page.getByLabel('Preview chat message').fill('Hello');
    await page.waitForFunction(() => document.querySelector('.hui-connections-line')?.textContent === '$1\\literal');
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Channel browser: preview, literal replacement, policy export, variant override, RE2 error, engine recovery and viewport checks passed.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
