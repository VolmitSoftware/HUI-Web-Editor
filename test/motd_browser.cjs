const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

async function fill(page, label, value) {
  const input = page.getByLabel(label, {exact: true});
  await input.fill(value);
  await input.press('Tab');
}
async function textEquals(page, selector, expected) {
  await page.waitForFunction(({selector, expected}) =>
    document.querySelector(selector)?.textContent.trim() === expected, {selector, expected});
}
async function exported(page) {
  await page.getByRole('button', {name: /^Export .* JSON$/}).click();
  const result = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await page.getByRole('button', {name: 'Close', exact: true}).click();
  return result;
}
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
    const fixture = {
      schemaVersion: 1, revision: 7, custom: {retained: true},
      state: 'event', favicon: 'fallback.png', icons: ['default.png'],
      rotation: {mode: 'sequence', intervalSeconds: 30, custom: 'rotation'},
      links: [{type: 'website', url: 'https://example.org/original', custom: 'original-link'}],
      serverLinks: {enabled: false, custom: 'links', links: [
        {label: 'Rules', url: 'https://example.org/rules', custom: 'link'},
      ]},
      entries: [
        {lines: ['Event A', 'Online {{ server.online }}'], icons: ['event.png'],
          sample: ['Online {{ server.online }}'], sampleMode: 'hide', weight: 3, custom: 'entry',
          select: {hostnames: ['*.example.org'], minProtocol: 768, maxProtocol: 999,
            zone: 'UTC', startTime: '18:00', endTime: '02:00', days: [5],
            states: ['event'], minOnline: 1, maxOnline: 100, custom: 'selector'},
          counts: {onlineMode: 'offset', onlineValue: -3, maximumMode: 'fixed', maximumValue: 200,
            hide: false, custom: 'counts'}},
        {lines: ['Event B'], icons: ['second.png'],
          select: {hostnames: ['*.example.org'], minProtocol: 768, maxProtocol: 999,
            states: ['maintenance'], minOnline: 1, maxOnline: 100},
          custom: {untouched: true}},
      ],
    };
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(fixture));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.waitForSelector('.hui-inspector-body.is-motd');
    await page.getByRole('combobox', {name: 'Rotation mode', exact: true}).selectOption('first');
    await fill(page, 'Rotation interval seconds', '90');
    await fill(page, 'Server state', 'maintenance');
    await fill(page, 'Document icon set', 'default.png\nseason.png');
    await page.getByRole('switch', {name: 'Publish server links', exact: true}).focus();
    await page.keyboard.press('Space');
    await fill(page, 'Link 1: Address', 'https://example.org/updated-rules');
    await fill(page, 'Entry 1: Hostnames', '*.example.org\nstatus.example.net');
    await fill(page, 'Entry 1: Matching states', 'maintenance');
    await fill(page, 'Entry 1: Icon set', 'event-new.png');
    await page.getByRole('combobox', {name: 'Entry 1: Sample mode', exact: true}).selectOption('replace');
    await fill(page, 'Entry 1: Online count value', '5');
    await page.getByRole('switch', {name: 'Entry 1: Saturday', exact: true}).focus();
    await page.keyboard.press('Space');

    await page.getByRole('switch', {name: 'Simulate request selection', exact: true}).click();
    await fill(page, 'Requested hostname', 'play.example.org');
    await fill(page, 'Client protocol number', '800');
    await fill(page, 'Request instant', '2026-10-09T19:00:00Z');
    await fill(page, 'Real online count', '17');
    await fill(page, 'Real maximum count', '100');
    await textEquals(page, '[data-motd-request-result]', 'Selected entry 1; 2 eligible responses.');
    await textEquals(page, '.hui-motd-stage .hui-motd-players', '22/200');
    await textEquals(page, '.hui-motd-stage .hui-motd-line:last-child', 'Online 17');
    assert.equal(await page.getByText('Resolved icon: event-new.png', {exact: true}).isVisible(), true);
    await page.locator('.hui-motd-stage .hui-motd-count').focus();
    await page.locator('.hui-motd-sample-line:visible').waitFor();
    assert.equal(await page.locator('.hui-motd-sample-line:visible').innerText(), 'Online 17');
    await page.keyboard.press('Tab');

    await page.getByRole('combobox', {name: 'Rotation mode', exact: true}).selectOption('sequence');
    await page.getByRole('button', {name: 'Refresh', exact: true}).click();
    await textEquals(page, '[data-motd-request-result]', 'Selected entry 2; 2 eligible responses.');
    await textEquals(page, '.hui-motd-stage .hui-motd-line', 'Event B');
    assert.equal(await page.getByText('Resolved icon: second.png', {exact: true}).isVisible(), true);
    await page.getByRole('combobox', {name: 'Rotation mode', exact: true}).selectOption('first');
    await fill(page, 'Requested hostname', 'wrong.example.net');
    await textEquals(page, '[data-motd-request-result]', 'No eligible response; the original ping is retained.');
    await textEquals(page, '.hui-motd-stage .hui-motd-line', 'Original server response retained.');
    assert.equal(await page.getByText('Published server links: 1', {exact: true}).isVisible(), true);
    await fill(page, 'Requested hostname', 'play.example.org');
    await page.getByRole('switch', {name: 'MOTD feature enabled', exact: true}).click();
    await textEquals(page, '[data-motd-request-result]', 'No eligible response; the original ping is retained.');
    assert.equal(await page.getByText('Published server links: 1', {exact: true}).isVisible(), true);
    await page.getByRole('combobox', {name: 'Server platform', exact: true}).selectOption('spigot');
    assert.equal(await page.getByText('Published server links: 0', {exact: true}).isVisible(), true);
    await page.getByRole('switch', {name: 'MOTD feature enabled', exact: true}).click();
    await textEquals(page, '[data-motd-request-result]', 'No eligible response; the original ping is retained.');
    await page.getByRole('combobox', {name: 'Server platform', exact: true}).selectOption('paper');
    await textEquals(page, '[data-motd-request-result]', 'Selected entry 1; 2 eligible responses.');

    await page.setViewportSize({width: 390, height: 1000});
    await page.getByRole('button', {name: 'Open inspector', exact: true}).click();
    await page.waitForSelector('.hui-inspector.is-mobile-open');
    await fill(page, 'Entry 1: Online count value', '7');
    await textEquals(page, '.hui-motd-stage .hui-motd-players', '24/200');
    await page.getByRole('switch', {name: 'Entry 1: Hide player counts', exact: true}).focus();
    await page.keyboard.press('Space');
    await textEquals(page, '.hui-motd-stage .hui-motd-players', '???');
    await page.keyboard.press('Space');
    await textEquals(page, '.hui-motd-stage .hui-motd-players', '24/200');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.getByRole('button', {name: 'Close inspector', exact: true}).click();
    await page.setViewportSize({width: 1440, height: 1000});
    const output = await exported(page);
    const expected = structuredClone(fixture);
    expected.state = 'maintenance';
    expected.icons.push('season.png');
    expected.rotation.mode = 'first';
    expected.rotation.intervalSeconds = 90;
    expected.serverLinks.enabled = true;
    expected.serverLinks.links[0].url = 'https://example.org/updated-rules';
    expected.entries[0].select.hostnames.push('status.example.net');
    expected.entries[0].select.states = ['maintenance'];
    expected.entries[0].select.days.push(6);
    expected.entries[0].icons = ['event-new.png'];
    expected.entries[0].sampleMode = 'replace';
    expected.entries[0].counts.onlineValue = 7;
    assert.deepEqual(output, expected);
    for (const width of [390, 1440]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('MOTD browser: typed policy edits, request selection, sequence rotation, sampled counts, icons, links, platform limits, keyboard/mobile edits and lossless export passed.');
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
