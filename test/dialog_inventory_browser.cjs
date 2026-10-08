const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function ready(browser) {
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
  await page.waitForSelector('#hui-library-new-document', {timeout: 60000});
  if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
  return {page, errors};
}
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
async function widths(page) {
  for (const width of [1440, 390]) {
    await page.setViewportSize({width, height: 1000});
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  }
}
async function main() {
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE} : {})});
  try {
    const form = await ready(browser);
    const dialog = {type: 'dialog', title: 'Choose label', kind: 'notice', timeoutTicks: 400,
      body: [{text: 'Enter your label', width: 240}],
      inputs: [{key: 'label', type: 'text', label: 'Label', maxLength: 32}],
      buttons: [{label: 'Save', actions: [{type: 'call', action: 'save'}]}],
      unsupported: [{type: 'prompt', kind: 'chat', var: 'label', label: 'Enter a label'}]};
    const menu = {offset: [0, 1.7, 2.5], lockPosition: false, followPlayer: false,
      closeOnDeath: false, closeOnTeleport: false,
      actions: {save: [{type: 'setSession', var: 'label', value: 'input.label'}]},
      components: [{id: 'form_button', x: 0, y: 0, z: 0, data: {type: 'button',
        icon: {type: 'text', text: 'Open form'}, actions: [dialog]}}]};
    await importDocument(form.page, menu);
    await form.page.getByText('Components', {exact: true}).click();
    await form.page.locator('.hui-rail-main').filter({hasText: 'form_button'}).click();
    await form.page.getByLabel('Dialog title', {exact: true}).fill('Updated form');
    await form.page.getByLabel('Dialog timeout ticks', {exact: true}).fill('600');
    await form.page.getByRole('switch', {name: 'Close dialog with Escape', exact: true}).focus();
    await form.page.keyboard.press('Space');
    await form.page.getByRole('button', {name: 'Add inputs', exact: true}).click();
    const output = await exported(form.page);
    const result = output.components[0].data.actions[0];
    assert.equal(result.title, 'Updated form');
    assert.equal(result.timeoutTicks, 600);
    assert.equal(result.escape, false);
    assert.equal(result.inputs.length, 2);
    assert.deepEqual(result.inputs[0], dialog.inputs[0]);
    assert.deepEqual(result.buttons, dialog.buttons);
    assert.deepEqual(result.unsupported, dialog.unsupported);
    assert.deepEqual(output.actions, menu.actions);
    await widths(form.page);
    assert.deepEqual(form.errors, []);
    await form.page.close();

    const inventory = await ready(browser);
    const source = {schemaVersion: 1, revision: 19, title: 'Shop', resolution: '9x1', mask: ['A........'],
      actions: {welcome: [{type: 'message', message: 'Hello'}]},
      keys: {A: {type: 'button', icon: {type: 'text', text: 'Welcome'}, actions: [{type: 'call', action: 'welcome'}]}},
      refresh: {mode: 'dynamic', titleTicks: 20, slotsTicks: 5, conditionsTicks: 10, listTicks: 40}};
    await importDocument(inventory.page, source);
    await inventory.page.getByLabel('titleTicks', {exact: true}).fill('0');
    await inventory.page.getByLabel('slotsTicks', {exact: true}).fill('3');
    const updated = await exported(inventory.page);
    assert.equal(updated.revision, 19);
    assert.deepEqual(updated.refresh, {...source.refresh, titleTicks: 0, slotsTicks: 3});
    assert.deepEqual(updated.actions, source.actions);
    assert.deepEqual(updated.keys.A.actions, source.keys.A.actions);
    await widths(inventory.page);
    assert.deepEqual(inventory.errors, []);
    await inventory.page.close();

    const preview = await ready(browser);
    const previewSource = {match: {blocks: ['CHEST']}, elements: [{type: 'label', text: "'Contents'"}],
      contentRefreshTicks: 6, accessCheckTicks: 7, custom: {retained: true}};
    await importDocument(preview.page, previewSource);
    await preview.page.getByLabel('Content refresh ticks', {exact: true}).fill('12');
    await preview.page.getByLabel('Access check ticks', {exact: true}).fill('3');
    const previewOutput = await exported(preview.page);
    assert.equal(previewOutput.contentRefreshTicks, 12);
    assert.equal(previewOutput.accessCheckTicks, 3);
    assert.deepEqual(previewOutput.elements, previewSource.elements);
    assert.deepEqual(previewOutput.custom, previewSource.custom);
    await widths(preview.page);
    await preview.page.getByRole('button', {name: 'Open inspector', exact: true}).click();
    await preview.page.getByLabel('Content refresh ticks', {exact: true}).fill('8');
    await preview.page.getByLabel('Content refresh ticks', {exact: true}).press('Tab');
    await preview.page.setViewportSize({width: 1440, height: 1000});
    assert.equal((await exported(preview.page)).contentRefreshTicks, 8);
    assert.deepEqual(preview.errors, []);
    console.log('Dialog and inventory browser passed: form controls, keyboard Escape toggle, nested callbacks, named references, refresh rates, lossless export, mobile widths.');
    console.log('Preview browser passed: content/access refresh controls, preserved elements and custom keys, mobile widths.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
