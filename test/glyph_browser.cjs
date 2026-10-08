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
    const source = {schemaVersion: 1, revision: 17, namespace: 'trails', font: 'icons',
      glyphs: [{id: 'coin', image: 'coin.png', height: 8, ascent: 7, frames: 1, fallback: 'C', extension: {keep: true}}],
      overlays: [{id: 'frame', image: 'frame.png', height: 8, ascent: 7, anchor: 'bottom'}],
      space: {enabled: true, range: [-16, 32]},
      waypointStyles: [{id: 'quest', nearDistance: 8, farDistance: 80,
        sprites: [{id: 'near', image: 'near.png', extension: 'retain'}]}], extension: {keep: 3}};
    await page.getByRole('button', {name: 'Import JSON', exact: true}).click();
    await page.locator('textarea:visible').last().fill(JSON.stringify(source));
    await page.getByRole('button', {name: /Replace document$/}).click();
    await page.getByLabel('Namespace', {exact: true}).fill('atlas');
    await page.getByLabel('Glyph image', {exact: true}).fill('icons/coin.png');
    await page.getByLabel('Style ID', {exact: true}).fill('destination');
    await page.getByLabel('Sprite image', {exact: true}).fill('waypoints/near.png');
    await page.getByRole('button', {name: 'Add glyph', exact: true}).click();
    await page.getByLabel('Glyph ID', {exact: true}).last().fill('token');
    await page.getByLabel('Glyph image', {exact: true}).last().fill('icons/token.png');
    await page.getByRole('button', {name: 'Add overlay', exact: true}).click();
    await page.getByRole('button', {name: 'Remove overlay', exact: true}).last().click();
    await page.getByRole('button', {name: 'Add sprite', exact: true}).click();
    await page.getByLabel('Sprite image', {exact: true}).last().fill('waypoints/far.png');
    await page.getByRole('button', {name: /^Export .* JSON$/}).click();
    const output = JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
    await page.getByRole('button', {name: 'Close', exact: true}).click();
    assert.equal(output.namespace, 'atlas');
    assert.equal(output.revision, 17);
    assert.equal(output.glyphs.length, 2);
    assert.equal(output.glyphs[0].image, 'icons/coin.png');
    assert.equal(output.glyphs[1].id, 'token');
    assert.deepEqual(output.glyphs[0].extension, source.glyphs[0].extension);
    assert.deepEqual(output.overlays, source.overlays);
    assert.deepEqual(output.space, source.space);
    assert.equal(output.waypointStyles[0].id, 'destination');
    assert.equal(output.waypointStyles[0].sprites.length, 2);
    assert.equal(output.waypointStyles[0].sprites[0].extension, 'retain');
    assert.deepEqual(output.extension, source.extension);
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    }
    assert.deepEqual(errors, []);
    console.log('Glyph browser passed: font identity, glyph and overlay lists, waypoint sprites, lossless export, mobile width.');
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
