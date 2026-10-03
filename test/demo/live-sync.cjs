const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/Users/brianfopiano/.nvm/versions/node/v24.19.0/lib/node_modules/@playwright/cli/node_modules/playwright');
const {pause,travel,button,click,type,startCapture,stopCapture} = require('./capture.cjs');
const root = path.resolve(__dirname,'../..');
const scratch = path.join(root,'.qa/demo/captures');
const privateFile = process.env.EDITOR_SESSION_FILE || path.resolve(root,'../Gloss/build/demo/editor-session.json');
const coordination = path.join(root,'.qa/demo/live-sync-ready');
const publishTrigger = path.join(root,'.qa/demo/live-sync-publish');
let capability;
(async()=>{
  capability=JSON.parse(fs.readFileSync(privateFile));
  const relay=Buffer.from(capability.endpoint).toString('base64url');
  const url=capability.builder+'/#/sync/'+capability.sessionId+'/'+capability.editorToken+'?relay='+relay;
  const browser=await chromium.launch({headless:true});
  try {
    const context=await browser.newContext({viewport:{width:1920,height:1080}});
    const page=await context.newPage();page.setDefaultTimeout(15000);
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    await page.goto(url);await pause(page,1300);
    if(await page.getByText('Skip',{exact:true}).isVisible())await page.getByText('Skip',{exact:true}).click();
    await button(page,'Read from relay').click();
    await button(page,'Replace workspace & connect').click();
    await page.locator('.hui-sync-bar.is-connected').waitFor();await pause(page,1800);
    await page.screenshot({path:path.join(scratch,'live-sync-connected.png')});
    const capture=await startCapture(page,'live-sync');await pause(page,1800);
    await page.screenshot({path:path.join(scratch,'live-sync-start.png')});
    await click(page,page.getByRole('button',{name:'Contents',exact:true}));
    const pages=page.locator('.hui-extras-row').filter({has:page.locator('.hui-field-label').getByText('pages',{exact:true})}).locator('input');
    const raw=await pages.inputValue();
    const source=JSON.parse(raw);
    assert.ok(Array.isArray(source)&&typeof source[0]?.lines[0]==='string','Actual session must contain a first-page text line');
    const original=JSON.stringify(source[0].lines[0]);
    const index=raw.indexOf(original);
    assert.ok(index>=0,'First-page text must be selectable in the authored pages input');
    await click(page,pages);
    await pages.evaluate((element,selection)=>element.setSelectionRange(selection.start,selection.end),{start:index+1,end:index+original.length-1});
    await pages.pressSequentially('&6Edited live in Gloss',{delay:65});await pages.press('Tab');await pause(page,1800);
    const edited=JSON.parse(await pages.inputValue());
    const expected=structuredClone(source);expected[0].lines[0]='&6Edited live in Gloss';
    assert.deepEqual(edited,expected,'Editing one page line must preserve every other authored page and object');
    await click(page,page.getByRole('button',{name:'Contents',exact:true}));
    const show=page.locator('[aria-label="Show condition"]');
    await type(page,show,'true');
    await click(page,page.getByRole('button',{name:'Zoom out',exact:true}));
    await page.screenshot({path:path.join(scratch,'live-sync-action.png')});
    fs.writeFileSync(coordination,'staged\n');
    console.log('Owned editor edits staged; waiting for native capture coordination');
    const deadline=Date.now()+10*60*1000;
    while(!fs.existsSync(publishTrigger)){assert.ok(Date.now()<deadline,'Native capture coordination timed out');await pause(page,500);}
    await click(page,button(page,'Publish to Server'));
    await page.locator('.hui-sync-bar.is-applied').waitFor({timeout:45000});
    await travel(page,page.locator('body'));await pause(page,5000);await page.screenshot({path:path.join(scratch,'live-sync-end.png')});
    assert.deepEqual(errors,[],'Connected editor raised browser errors');
    const metadata=await stopCapture(page,capture,{id:'live-sync',coverage:['genuine authenticated relay session','authored hologram text','explicit Publish to Server','actual server Applied acknowledgement']});
    fs.writeFileSync(path.join(root,'.qa/demo/live-sync-applied'),'applied\n');
    console.log(JSON.stringify(metadata));
    const issues=page.getByRole('button',{name:/Open the validation panel/});
    if(await issues.count()) {
      await issues.click();
      console.log(JSON.stringify({validationMessages:await page.locator('.hui-validation-message').allTextContents()}));
    }
    await context.close();
  } finally {await browser.close();}
})().catch(error=>{
  let message=error.message;
  for(const value of [capability?.sessionId,capability?.editorToken])if(value)message=message.split(value).join('[private]');
  console.error(message);process.exitCode=1;
});
