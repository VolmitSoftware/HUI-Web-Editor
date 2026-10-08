const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function main() {
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? {executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE} : {})});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', error => { errors.push(error.message); console.error(error.message); });
    await page.goto(process.env.EDITOR_URL || 'http://127.0.0.1:8107');
    await page.waitForSelector('.hui-inspector-body', {state: 'attached', timeout: 60000});
    if (await page.getByText('Skip', {exact: true}).isVisible()) await page.getByText('Skip', {exact: true}).click();
    await page.waitForSelector('.hui-inspector-body');
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    const fixture = {schemaVersion: 2, revision: 9, select: {when: 'true'}, presentation: {
      title: '', hideNumbers: true,
      lines: [{id: 'balance', text: 'Balance', value: '100', format: 'fixed', show: 'true', custom: 'retained'},
        {section: 'account', show: false}],
      layout: {sections: {account: ['Account']}, pages: [{id: 'first', show: false, lines: ['Page']}],
        refresh: {valueTicks: 2, custom: 'refresh'}, overflow: 'truncate', custom: {nested: 'layout'}}}, variants: [],
      objectives: {custom: 'objectives', belowName: {title: 'Health', value: 'subject.health', custom: 'slot'}}};
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.waitForSelector('.hui-inspector-body.is-scoreboard');
    await page.locator('.hui-inspector-body.is-scoreboard .hui-hologram-line-row input').first().fill('Credits');
    await page.locator('.hui-inspector-body.is-scoreboard summary').filter({hasText: 'Row settings'}).first().focus();
    await page.keyboard.press('Enter');
    await page.getByLabel('Value 1', {exact: true}).first().fill('200');
    await page.getByLabel('Value 1', {exact: true}).first().press('Tab');
    const layout = page.locator('.hui-scoreboard-layout').first();
    await layout.getByLabel('Section name', {exact: true}).fill('stats');
    await layout.getByRole('button', {name: 'Rename section', exact: true}).click();
    await layout.getByRole('button', {name: 'Add section', exact: true}).click();
    const extraSection = layout.locator('.hui-scoreboard-section').last();
    await extraSection.getByRole('button', {name: 'Delete section', exact: true}).click();
    let firstPage = layout.locator('.hui-scoreboard-page').first();
    await firstPage.getByLabel('Page condition', {exact: true}).fill('true');
    await firstPage.getByLabel('Page duration ticks', {exact: true}).fill('4');
    await firstPage.getByLabel('Page duration ticks', {exact: true}).press('Tab');
    await firstPage.getByRole('switch', {name: 'Inherit presentation title', exact: true}).click();
    await firstPage.getByLabel('Page title', {exact: true}).fill('First');
    await layout.getByRole('button', {name: 'Add page', exact: true}).click();
    const secondPage = layout.locator('.hui-scoreboard-page').last();
    await secondPage.getByLabel('Page ID', {exact: true}).fill('second');
    await secondPage.getByLabel('Page duration ticks', {exact: true}).fill('7');
    await secondPage.getByLabel('Page duration ticks', {exact: true}).press('Tab');
    await secondPage.getByRole('button', {name: /Add line$/}).first().click();
    await secondPage.locator('.hui-hologram-line-row input').fill('Second');
    await secondPage.getByRole('button', {name: 'Move page up', exact: true}).focus();
    await page.keyboard.press('Enter');
    await layout.getByRole('combobox', {name: 'Overflow', exact: true}).selectOption('error');
    for (const [label, ticks] of [['Title', '3'], ['Text', '4']]) {
      await layout.getByRole('switch', {name: `Override ${label} interval`, exact: true}).focus();
      await page.keyboard.press('Space');
      await layout.getByLabel(`${label} ticks`, {exact: true}).fill(ticks);
      await layout.getByLabel(`${label} ticks`, {exact: true}).press('Tab');
    }
    await page.getByLabel('Below name: Numeric value', {exact: true}).fill('subject.health * 2');
    await page.getByRole('combobox', {name: 'Below name: Score format', exact: true}).selectOption('fixed');
    await page.getByLabel('Below name: Formatted value', {exact: true}).fill('{{ subject.health }}');
    await page.getByLabel('Below name: Subject condition', {exact: true}).fill('subject.world == viewer.world');
    await page.getByRole('combobox', {name: 'Below name: Slot conflict', exact: true}).selectOption('override');
    await page.getByRole('switch', {name: 'Player list', exact: true}).click();
    await page.getByRole('combobox', {name: 'Player list: Render type', exact: true}).selectOption('hearts');
    await page.getByLabel('Player list: Refresh ticks', {exact: true}).fill('5');
    await page.getByLabel('Player list: Refresh ticks', {exact: true}).press('Tab');
    await page.setViewportSize({width: 390, height: 1000});
    await page.getByRole('button', {name: 'Open inspector', exact: true}).click();
    await page.waitForSelector('.hui-inspector.is-mobile-open');
    await layout.getByLabel('Value ticks', {exact: true}).fill('9');
    await layout.getByLabel('Value ticks', {exact: true}).press('Tab');
    await page.getByRole('button', {name: /Add variant$/}).click();
    const variantLayout = page.locator('.hui-scoreboard-variant .hui-scoreboard-layout');
    await variantLayout.getByLabel('Title ticks', {exact: true}).fill('11');
    await variantLayout.getByLabel('Title ticks', {exact: true}).press('Tab');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.getByRole('button', {name: 'Close inspector', exact: true}).click();
    await page.setViewportSize({width: 1440, height: 1000});
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    assert.equal(output.revision, 9);
    assert.equal(output.presentation.title, '');
    assert.deepEqual(output.presentation.lines[0], {...fixture.presentation.lines[0], text: 'Credits', value: '200'});
    assert.deepEqual(output.presentation.lines[1], {...fixture.presentation.lines[1], section: 'stats'});
    assert.deepEqual(output.presentation.layout.sections, {stats: ['Account']});
    assert.deepEqual(output.presentation.layout.pages, [
      {id: 'second', lines: ['Second'], durationTicks: 7},
      {id: 'first', show: true, title: 'First', lines: ['Page'], durationTicks: 4},
    ]);
    assert.equal(output.presentation.layout.overflow, 'error');
    assert.deepEqual(output.presentation.layout.refresh, {titleTicks: 3, textTicks: 4, valueTicks: 9, custom: 'refresh'});
    assert.deepEqual(output.presentation.layout.custom, fixture.presentation.layout.custom);
    assert.deepEqual(output.objectives, {custom: 'objectives', playerList: {renderType: 'hearts', refreshTicks: 5},
      belowName: {...fixture.objectives.belowName, value: 'subject.health * 2', format: 'fixed',
        valueText: '{{ subject.health }}', subjects: 'subject.world == viewer.world', conflict: 'override'}});
    assert.equal(output.variants.length, 1);
    assert.equal(output.variants[0].presentation.layout.refresh.titleTicks, 11);
    assert.deepEqual(output.variants[0].presentation.layout.sections, output.presentation.layout.sections);
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Scoreboard browser: rows, section rename, ordered pages, refresh overrides, native objectives, variants, keyboard editing, lossless export and viewport checks passed.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
