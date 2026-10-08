const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function exported(page) {
  await page.getByRole('button', { name: /^Export .* JSON$/ }).click();
  const result = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await page.getByRole('button', { name: 'Close', exact: true }).click();
  return result;
}

async function main() {
  const browser = await chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
    await page.waitForSelector('.hui-inspector-body', { state: 'attached', timeout: 60000 });
    if (await page.getByText('Skip', { exact: true }).isVisible()) await page.getByText('Skip', { exact: true }).click();
    await page.waitForSelector('.hui-inspector-body');
    const source = {
      schemaVersion: 1, revision: 3, surface: 'actionbar', automatic: false,
      select: { priority: 0, when: 'false' }, presentation: { text: 'Event message' }, variants: [],
      on: [{ trigger: 'join', future: { retained: [1, 2] } }], extension: 'retained',
    };
    await page.getByRole('button', { name: 'Import JSON', exact: true }).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(source));
    await page.getByRole('button', { name: /Replace document$/ }).click();
    assert.deepEqual(await exported(page), source);
    await page.getByLabel('Subscription 1: Event', { exact: true }).selectOption('interval');
    await page.getByLabel('Subscription 1: Interval', { exact: true }).fill('120');
    await page.getByLabel('Subscription 1: Delay', { exact: true }).fill('10');
    await page.getByLabel('Subscription 1: Condition', { exact: true }).fill('viewer.op');
    await page.getByLabel('Subscription 1: Condition', { exact: true }).press('Tab');
    let changed = await exported(page);
    assert.deepEqual(changed.on, [{ trigger: 'interval', everyTicks: 120, delayTicks: 10, when: 'viewer.op', future: { retained: [1, 2] } }]);
    await page.getByRole('button', { name: 'Add subscription', exact: true }).focus();
    await page.keyboard.press('Enter');
    await page.getByLabel('Subscription 2: Event', { exact: true }).selectOption('world_change');
    await page.locator('[data-surface-subscription="1"]').getByRole('button', { name: 'Move up', exact: true }).click();
    changed = await exported(page);
    assert.equal(changed.on[0].trigger, 'world_change');
    assert.deepEqual(changed.on[1].future, source.on[0].future);
    await page.getByLabel('Subscription 2: Event', { exact: true }).selectOption('join');
    changed = await exported(page);
    assert.equal('everyTicks' in changed.on[1], false);
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.getByRole('button', { name: 'Open inspector', exact: true }).click();
    await page.waitForSelector('.hui-inspector.is-mobile-open');
    await page.getByLabel('Subscription 2: Delay', { exact: true }).fill('25');
    await page.getByLabel('Subscription 2: Delay', { exact: true }).press('Tab');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.getByRole('button', { name: 'Close inspector', exact: true }).click();
    await page.setViewportSize({ width: 1440, height: 1000 });
    assert.equal((await exported(page)).on[1].delayTicks, 25);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.deepEqual(errors, []);
    console.log('HUD subscription browser passed: typed event/interval/delay/condition edits, keyboard add, reorder, preserved extensions and mobile editing.');
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
