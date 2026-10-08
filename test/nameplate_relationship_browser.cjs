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
    const fixture = {schemaVersion: 1, revision: 9, select: {when: 'true', priority: 0},
      presentation: {lines: [{text: 'RELATIONSHIP {bar}', show: true}], healthSegments: 13,
        hideSneaking: true, hideInvisible: true, hideSpectator: true, includeNpcs: false, showSelf: false,
        custom: 'preserved'}, variants: []};
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.waitForSelector('.hui-identity-billboard');
    await page.getByLabel('Health segments', {exact: true}).fill('23');
    await page.getByLabel('Health segments', {exact: true}).press('Tab');
    await page.getByRole('switch', {name: 'Show own plate', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.getByRole('button', {name: 'Other viewer', exact: true}).click();
    await page.waitForFunction(() => document.querySelector('.hui-identity-billboard')?.textContent.includes('RELATIONSHIP'));
    await page.getByRole('button', {name: 'Visible player', exact: true}).click();
    await page.getByText('Hidden for this preview player', {exact: true}).waitFor();
    await page.getByRole('switch', {name: 'Hide invisible players', exact: true}).click();
    await page.waitForFunction(() => document.querySelector('.hui-identity-billboard')?.textContent.includes('RELATIONSHIP'));
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(output.presentation.healthSegments, 23);
    assert.equal(output.presentation.showSelf, true);
    assert.equal(output.presentation.hideInvisible, false);
    assert.equal(output.presentation.includeNpcs, false);
    assert.equal(output.presentation.custom, 'preserved');
    assert.equal(output.revision, 9);
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Nameplate relationship browser passed: typed health controls, keyboard visibility, preview states, lossless export, desktop/mobile widths.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
