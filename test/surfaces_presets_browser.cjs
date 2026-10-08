const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function ready(browser) {
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
  await page.waitForSelector('#hui-library-new-document');
  if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
  return {page, errors};
}
async function importDocument(page, fixture) {
  await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
  await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
  await page.getByRole('button', {name: /Replace document$/}).click();
}
async function exportDocument(page) {
  await page.getByRole('button', {name: /^Export .* JSON$/}).click();
  const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await page.getByRole('button', {name: 'Close', exact: true}).click();
  return output;
}
async function responsive(page) {
  for (const width of [1440, 390]) {
    await page.setViewportSize({width, height: 1000});
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  }
}
async function main() {
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE} : {})});
  try {
    const hud = await ready(browser);
    const fixture = {schemaVersion: 1, revision: 19, surface: 'bossbar', group: 'event', automatic: false,
      select: {when: 'true'}, show: true,
      delivery: {mode: 'queue', preempt: 'higher', maxPending: 8, overflow: 'reject', cooldownTicks: 40,
        deduplicate: 'purpose', expireTicks: 300},
      on: [{trigger: 'join', delayTicks: 20, when: 'true'}],
      presentation: {title: 'Event', progress: '0.5', color: 'purple', style: 'solid', flags: ['create_fog'], ttlTicks: 80}};
    await importDocument(hud.page, fixture);
    await hud.page.getByLabel('Bossbar group', {exact: true}).fill('quest');
    await hud.page.getByLabel('maxPending', {exact: true}).fill('12');
    await hud.page.getByRole('switch', {name: 'darken_sky', exact: true}).focus();
    await hud.page.keyboard.press('Space');
    const output = await exportDocument(hud.page);
    assert.equal(output.revision, 19);
    assert.equal(output.group, 'quest');
    assert.equal(output.automatic, false);
    assert.deepEqual(output.on, fixture.on);
    assert.deepEqual(output.delivery, {...fixture.delivery, maxPending: 12});
    assert.deepEqual(new Set(output.presentation.flags), new Set(['create_fog', 'darken_sky']));
    await responsive(hud.page);
    assert.deepEqual(hud.errors, []);
    await hud.page.close();

    const presets = await ready(browser);
    const catalog = {schemaVersion: 1, revision: 27, defaults: {boards: {title: 'Base'}},
      presets: {boards: {base: {values: {lines: ['First']}}, event: {extends: 'base', values: {title: 'Event'}}},
        behaviors: {welcome: {values: {trigger: 'join'}}}}};
    await importDocument(presets.page, catalog);
    await presets.page.getByRole('button', {name: 'Default values', exact: true}).click();
    await presets.page.locator('.is-presets .hui-extras-row input').first().fill('Shared');
    await presets.page.getByLabel('New preset name', {exact: true}).fill('season');
    await presets.page.getByRole('button', {name: 'Add preset', exact: true}).click();
    await presets.page.getByLabel('Parent preset', {exact: true}).fill('event');
    await presets.page.getByLabel('Parent preset', {exact: true}).press('Tab');
    const edited = await exportDocument(presets.page);
    assert.equal(edited.revision, 27);
    assert.deepEqual(edited.defaults, {boards: {title: 'Shared'}});
    assert.deepEqual(edited.presets.behaviors, catalog.presets.behaviors);
    assert.deepEqual(edited.presets.boards.base, catalog.presets.boards.base);
    assert.deepEqual(edited.presets.boards.event, catalog.presets.boards.event);
    assert.deepEqual(edited.presets.boards.season, {extends: 'event', values: {}});
    await responsive(presets.page);
    assert.deepEqual(presets.errors, []);
    console.log('Surface and preset browser: group, queue, keyboard flags, ancestry edits, lossless export and mobile widths passed.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
