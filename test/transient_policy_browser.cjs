const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function importDocument(page, source) {
  await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
  await page.locator('textarea:visible').last().fill(JSON.stringify(source));
  await page.getByRole('button', {name: /Replace document$/}).click();
}
async function exported(page) {
  await page.getByRole('button', {name: /^Export .* JSON$/}).click();
  const source = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await page.getByRole('button', {name: 'Close', exact: true}).click();
  return source;
}
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
    const bubble = JSON.parse(fs.readFileSync('../Gloss/src/main/resources/defaults/bubbles/default.json', 'utf8'));
    await importDocument(page, bubble);
    await page.getByRole('combobox').filter({hasText: 'Replace oldest'}).selectOption('reject-new');
    await page.getByRole('switch', {name: 'Override Content interval', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.getByLabel('Content ticks', {exact: true}).fill('20');
    await page.getByLabel('Content ticks', {exact: true}).press('Tab');
    await page.getByRole('switch', {name: 'Override Motion interval', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.getByLabel('Motion ticks', {exact: true}).fill('4');
    await page.getByLabel('Motion ticks', {exact: true}).press('Tab');
    const changedBubble = await exported(page);
    assert.equal(changedBubble.overflow, 'reject-new');
    assert.deepEqual(changedBubble.motion, bubble.motion);
    assert.deepEqual(changedBubble.refresh, {contentTicks: 20, motionTicks: 4});
    const indicator = JSON.parse(fs.readFileSync('../Gloss/src/main/resources/defaults/damage-indicators/default.json', 'utf8'));
    await importDocument(page, indicator);
    const initialIndicator = await exported(page);
    await page.getByLabel('Aggregation ticks', {exact: true}).fill('8');
    await page.getByLabel('Maximum pending samples', {exact: true}).fill('48');
    await page.getByLabel('Maximum pending samples', {exact: true}).press('Tab');
    const changed = await exported(page);
    assert.equal(changed.limits.aggregationTicks, 8);
    assert.equal(changed.limits.maxPendingSamples, 48);
    assert.deepEqual(changed.damage, initialIndicator.damage);
    assert.deepEqual(changed.healing, initialIndicator.healing);
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Transient policy browser passed: bubble overflow, indicator aggregation and capacity, independent content/motion cadence, preserved styles, mobile width.');
  } finally { await browser.close(); }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
