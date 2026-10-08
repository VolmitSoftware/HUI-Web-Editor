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
    await page.waitForSelector('#hui-library-new-document', {timeout: 60000});
    if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
    const source = {schemaVersion: 2, revision: 19, matching: {maxInputCharacters: 4096},
      on: [{trigger: 'chat', pattern: '^hello$', permission: 'example.greeting',
        do: [{type: 'sequence', actions: [{type: 'message', message: 'Welcome'}]}]}],
      state: {visits: {scope: 'player', type: 'number', default: 0}}, custom: {retained: true}};
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(source));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.getByLabel('maxInputCharacters', {exact: true}).fill('2048');
    await page.getByLabel('Chat pattern 1', {exact: true}).fill('(?=a)a');
    await page.locator('.hui-status-chip.is-error').waitFor();
    await page.getByLabel('Chat pattern 1', {exact: true}).fill('^welcome$');
    await page.getByLabel('Chat pattern 1', {exact: true}).press('Tab');
    await page.getByRole('button', {name: 'No validation issues', exact: true}).waitFor();
    await page.setViewportSize({width: 390, height: 1000});
    await page.getByRole('button', {name: 'Open inspector', exact: true}).click();
    await page.getByLabel('maxWorkUnits', {exact: true}).fill('75000');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.setViewportSize({width: 1440, height: 1000});
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(output.revision, source.revision);
    assert.equal(output.matching.maxInputCharacters, 2048);
    assert.equal(output.matching.maxWorkUnits, 75000);
    assert.equal(output.on[0].pattern, '^welcome$');
    assert.deepEqual(output.on[0].do, source.on[0].do);
    assert.deepEqual(output.state, source.state);
    assert.deepEqual(output.custom, source.custom);
    assert.deepEqual(errors, []);
    console.log('Behavior browser passed: typed matching edits, RE2 rejection/recovery, keyboard and mobile editing, preserved actions/state/unknown keys.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
