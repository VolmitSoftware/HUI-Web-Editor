const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
async function exported(page) {
  await page.getByRole('button', {name: /^Export .* JSON$/}).click();
  const value = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await page.getByRole('button', {name: 'Close', exact: true}).click();
  return value;
}
async function main() {
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE} : {})});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
    await page.waitForSelector('.hui-inspector-body', {state: 'attached', timeout: 60000});
    if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
    await page.waitForSelector('.hui-inspector-body');
    const fixture = {schemaVersion: 2, on: [{trigger: 'join', do: [
      {type: 'sequence', future: {keep: true}, steps: [
        {type: 'setState', key: 'visits', value: '1', atTicks: 10, extension: 'keep'},
        {type: 'message', message: 'Welcome'},
      ]},
      {type: 'if', when: 'true', then: [{type: 'addState', key: 'visits', value: '1'}], else: []},
    ]}], state: {visits: {scope: 'player', type: 'number', default: '2', extension: {keep: true}}}, future: 'keep'};
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    const baseline = await exported(page);
    assert.deepEqual(baseline.on, fixture.on); assert.deepEqual(baseline.state, fixture.state);
    assert.equal(await page.getByText('Click trigger', {exact: true}).count(), 0);
    assert.equal(await page.getByRole('button', {name: 'Call named action', exact: true}).count(), 0);
    const state = page.locator('[data-behavior-state="visits"]');
    await state.getByRole('combobox', {name: 'Scope', exact: true}).selectOption('global');
    await page.getByLabel('state/visits/default', {exact: true}).fill('7');
    await page.getByLabel('state/visits/default', {exact: true}).press('Tab');
    await page.locator('input[aria-label$="/on/0/do/0/steps/0/value"]').fill('5');
    await page.locator('input[aria-label$="/on/0/do/0/steps/0/atTicks"]').fill('40');
    await page.locator('input[aria-label$="/on/0/do/0/steps/0/atTicks"]').press('Tab');
    await page.getByRole('button', {name: 'Add state', exact: true}).focus();
    await page.keyboard.press('Enter');
    const addedState = page.locator('[data-behavior-state="state1"]');
    await addedState.getByRole('combobox', {name: 'Type', exact: true}).selectOption('boolean');
    await addedState.getByRole('switch', {name: 'Override', exact: true}).focus();
    await page.keyboard.press('Space');
    await addedState.getByRole('switch', {name: 'Value', exact: true}).focus();
    await page.keyboard.press('Space');
    await page.setViewportSize({width: 390, height: 1000});
    await page.getByRole('button', {name: 'Open inspector', exact: true}).click();
    await page.waitForSelector('.hui-inspector.is-mobile-open');
    await page.locator('input[aria-label$="/on/0/do/1/then/0/value"]').fill('3');
    await page.locator('input[aria-label$="/on/0/do/1/then/0/value"]').press('Tab');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.getByRole('button', {name: 'Close inspector', exact: true}).click();
    await page.setViewportSize({width: 1440, height: 1000});
    const output = await exported(page);
    const expected = structuredClone(baseline);
    expected.state.visits.scope = 'global'; expected.state.visits.default = 7;
    expected.state.state1 = {scope: 'player', type: 'boolean', default: true};
    expected.on[0].do[0].steps[0].value = '5'; expected.on[0].do[0].steps[0].atTicks = 40;
    expected.on[0].do[1].then[0].value = '3';
    assert.deepEqual(output, expected);
    assert.deepEqual(errors, []);
    console.log('Behavior authoring passed: state scope/type/default, nested actions and sequence cues, keyboard/mobile edits, source preservation.');
  } finally {await browser.close();}
}
main().catch(error => {console.error(error); process.exitCode = 1;});
