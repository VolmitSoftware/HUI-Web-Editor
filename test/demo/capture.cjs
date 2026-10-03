const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const playwrightPath = process.env.PLAYWRIGHT_MODULE || '/Users/brianfopiano/.nvm/versions/node/v24.19.0/lib/node_modules/@playwright/cli/node_modules/playwright';
const {chromium} = require(playwrightPath);
const ffmpeg = process.env.FFMPEG || '/Users/brianfopiano/.local/bin/ffmpeg';
const root = path.resolve(__dirname, '../..');
const scratch = path.join(root, '.qa/demo/captures');
const baseUrl = process.env.EDITOR_URL || 'http://127.0.0.1:8098';
const viewport = {width:1920, height:1080};
const shots = JSON.parse(fs.readFileSync(path.join(__dirname, 'shots.json')));
const requested = new Set(process.argv.slice(2));
let cursor = {x:960,y:540};
const snapshots = new Map();
async function pause(page, ms=1200) { await page.waitForTimeout(ms); }
async function travel(page, locator) {
  await locator.evaluate(element => element.scrollIntoView({block:'center',inline:'nearest'}));
  const box = await locator.boundingBox();
  assert.ok(box, 'The recorded control must be visible');
  const next = {x:box.x+box.width/2,y:box.y+box.height/2};
  const steps = 24;
  for (let i=1;i<=steps;i++) {
    const t=i/steps; const eased=t*t*(3-2*t);
    await page.mouse.move(cursor.x+(next.x-cursor.x)*eased,cursor.y+(next.y-cursor.y)*eased);
    await page.waitForTimeout(16);
  }
  cursor=next; await pause(page,250);
}
function button(page, name) {return page.getByRole('button',{name:new RegExp(name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')+'$')}).filter({visible:true});}
async function click(page,locator) {await travel(page,locator);await locator.click();await pause(page,700);}
async function type(page,locator,value) {
  await travel(page,locator);await locator.click();await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value,{delay:65});await locator.press('Tab');await pause(page,1600);
}
async function importFixture(page, id) {
  await page.getByRole('button',{name:'Import JSON',exact:true}).click();
  const choosing = page.waitForEvent('filechooser');
  await button(page,'Choose a .json file').click();
  await (await choosing).setFiles(path.join(__dirname,'fixtures',id+'.json'));
  await button(page,'Replace document').click();await pause(page,700);
}
async function exportJson(page, recorded=true) {
  const control=page.getByRole('button',{name:/^Export .* JSON$/});
  if(recorded) await click(page,control);else await control.click();
  const json=JSON.parse(await page.locator('pre.hui-codeblock:visible').last().innerText());
  await pause(page,1800);
  if(recorded) await click(page,page.getByRole('button',{name:'Close',exact:true}));else await page.getByRole('button',{name:'Close',exact:true}).click();
  return json;
}
function readPath(value, key) {return key.split('.').reduce((current,part)=>current[part],value);}
async function operation(page, op) {
  if(op.kind==='input') {
    let locator=op.aria ? page.locator('[aria-label='+JSON.stringify(op.aria)+']') : op.field ? page.locator('.hui-inspector-body .hui-field').filter({has:page.locator('.hui-field-label').getByText(op.field,{exact:true})}).locator('input:not([type=color]),textarea') : page.locator(op.selector);
    if(op.index!==undefined) locator=locator.nth(op.index);
    await type(page,locator,op.value);
  } else if(op.kind==='click') {
    let locator=op.selector?page.locator(op.selector):op.role?page.getByRole(op.role,{name:new RegExp(op.button.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?:.*)?$')}):button(page,op.button);
    if(op.index!==undefined)locator=locator.nth(op.index);
    if(op.key)await page.keyboard.down(op.key);
    try {await click(page,locator);}finally{if(op.key)await page.keyboard.up(op.key);}
  } else if(op.kind==='shortcut') {
    await page.keyboard.press(op.key);await pause(page,1600);
  } else if(op.kind==='exportSnapshot') {
    const data=await exportJson(page);
    if(op.equals)assert.deepEqual(data,snapshots.get(op.equals),'Seed must reproduce the complete exported document');
    if(op.name)snapshots.set(op.name,data);
  } else if(op.kind==='upload') {
    const choosing=page.waitForEvent('filechooser');
    await click(page,button(page,op.button).nth(op.index||0));
    await (await choosing).setFiles(path.resolve(root,op.file));await pause(page,1700);
  } else if(op.kind==='canvasContext') {
    const locator=page.locator('.hui-canvas-stage:visible').first();await travel(page,locator);
    const box=await locator.boundingBox();
    cursor={x:box.x+box.width*(op.x||.3),y:box.y+box.height*(op.y||.35)};
    await page.mouse.move(cursor.x,cursor.y,{steps:18});await page.mouse.click(cursor.x,cursor.y,{button:'right'});await pause(page,1000);
  } else if(op.kind==='newDocument') {
    await click(page,page.locator('#hui-library-new-document'));
    await click(page,button(page,op.create));
  } else if(op.kind==='download') {
    const waiting=page.waitForEvent('download');
    await click(page,button(page,op.button));
    const file=path.join(scratch,op.name+(op.format==='zip'?'.zip':'.json'));
    await (await waiting).saveAs(file);
    if(op.format==='zip') {
      const result=spawnSync('python3',['-c','import zipfile,sys,json; z=zipfile.ZipFile(sys.argv[1]); assert sorted(z.namelist())==json.loads(sys.argv[2]); assert all(z.read(n).startswith(bytes([137,80,78,71,13,10,26,10])) for n in z.namelist())',file,JSON.stringify(op.entries)],{encoding:'utf8'});
      assert.equal(result.status,0,result.stderr);return;
    }
    const data=JSON.parse(fs.readFileSync(file));
    for(const [key,expected] of Object.entries(op.assertions||{}))assert.deepEqual(readPath(data,key),expected,key);
  } else if(op.kind==='mode') {
    await click(page,page.getByRole('button',{name:/Editor mode:/}));
    await click(page,page.getByRole('menuitem',{name:new RegExp(op.value+'$')}));
  } else if(op.kind==='select') {
    const locator=page.locator(op.selector).nth(op.index||0);
    await travel(page,locator);await locator.selectOption(op.value);await pause(page,1400);
  } else if(op.kind==='previewClick') {
    const locator=page.locator('[data-id='+JSON.stringify(op.id)+']:visible');
    const before=op.expectChange?await locator.locator('canvas').evaluate(canvas=>canvas.toDataURL()):null;
    await travel(page,locator);await page.mouse.click(cursor.x,cursor.y,{button:op.button||'right'});await pause(page,1500);
    if(op.expectChange)assert.notEqual(await locator.locator('canvas').evaluate(canvas=>canvas.toDataURL()),before,'Preview pixels must reflect the interaction');
  } else if(op.kind==='distinctSprites') {
    const sprites=await Promise.all(op.ids.map(id=>page.locator('[data-id='+JSON.stringify(id)+'] canvas').evaluate(canvas=>canvas.toDataURL())));
    assert.equal(new Set(sprites).size,op.ids.length,'Each list entry must have distinct rendered pixels');
  } else if(op.kind==='wait') {await pause(page,op.ms);}
  else if(op.kind==='extras') {
    const row=page.locator('.hui-extras-row').filter({has:page.locator('.hui-field-label').getByText(op.key,{exact:true})});
    if(!await row.locator('input').isVisible()) await click(page,page.locator('.hui-extras').getByRole('button',{name:new RegExp(op.section+'$')}));
    const locator=page.locator('.hui-extras-row').filter({has:page.locator('.hui-field-label').getByText(op.key,{exact:true})}).locator('input');
    await type(page,locator,op.literal?op.value:JSON.stringify(op.value));
  } else if(op.kind==='component') {
    await click(page,button(page,'Components'));
    await click(page,page.getByText(op.id,{exact:true}).filter({visible:true}).first());
  } else if(op.kind==='screenshot') {await page.screenshot({path:path.join(scratch,op.name+'.png')});}
  else throw new Error('Unknown operation '+op.kind);
}
async function startCapture(page,id) {
  const dir=path.join(scratch,id);fs.mkdirSync(dir,{recursive:true});
  await page.evaluate(()=>{
    const pointer=document.createElement('div');pointer.id='demo-cursor';pointer.setAttribute('aria-hidden','true');
    pointer.style.cssText='position:fixed;left:960px;top:540px;width:22px;height:30px;pointer-events:none;z-index:2147483647;filter:drop-shadow(0 1px 2px #000)';
    pointer.innerHTML='<svg xmlns="http://www.w3.org/2000/svg" width="22" height="30" viewBox="0 0 22 30"><path d="M2 2 L2 24 L8 18 L13 29 L17 27 L12 16 L21 16 Z" fill="white" stroke="black" stroke-width="1.3"/></svg>';
    document.body.append(pointer);document.addEventListener('mousemove',e=>{pointer.style.left=e.clientX+'px';pointer.style.top=e.clientY+'px';});
    let frame=0;function draw(){pointer.style.opacity=(++frame%2)?'1':'.999';window.demoCursorRaf=requestAnimationFrame(draw);}draw();
  });
  const session=await page.context().newCDPSession(page);const frames=[];
  session.on('Page.screencastFrame',async event=>{
    const filename=path.join(dir,String(frames.length).padStart(6,'0')+'.jpg');
    fs.writeFileSync(filename,Buffer.from(event.data,'base64'));
    frames.push({filename,timestamp:event.metadata.timestamp,width:event.metadata.deviceWidth,height:event.metadata.deviceHeight});
    await session.send('Page.screencastFrameAck',{sessionId:event.sessionId});
  });
  await session.send('Page.startScreencast',{format:'jpeg',quality:92,maxWidth:viewport.width,maxHeight:viewport.height,everyNthFrame:1});
  return {session,frames,dir};
}
async function stopCapture(page,capture,shot) {
  await capture.session.send('Page.stopScreencast');await pause(page,300);
  await page.evaluate(()=>{cancelAnimationFrame(window.demoCursorRaf);document.querySelector('#demo-cursor')?.remove();});
  const frames=capture.frames;assert.ok(frames.length>40,'A continuous native recording is required');
  assert.ok(frames.every(f=>f.width===1920&&f.height===1080),'Native source viewport must be 1920x1080');
  const concat=path.join(capture.dir,'frames.txt');
  let text='';for(let i=0;i<frames.length;i++){text+=`file '${frames[i].filename}'\n`;text+=`duration ${i+1<frames.length?Math.max(.001,frames[i+1].timestamp-frames[i].timestamp):1/30}\n`;}
  text+=`file '${frames.at(-1).filename}'\n`;fs.writeFileSync(concat,text);
  const output=path.join(scratch,shot.id+'-editor.webm');
  const encoded=spawnSync(ffmpeg,['-y','-v','error','-f','concat','-safe','0','-i',concat,'-an','-r','30','-c:v','libvpx-vp9','-cpu-used','6','-row-mt','1','-threads','4','-crf','31','-b:v','0','-pix_fmt','yuv420p',output],{encoding:'utf8'});
  assert.equal(encoded.status,0,encoded.stderr);assert.ok(fs.statSync(output).size<25*1024*1024,'Clip exceeds 25 MB');
  const decoded=spawnSync(ffmpeg,['-v','error','-i',output,'-f','null','-'],{encoding:'utf8'});assert.equal(decoded.status,0,decoded.stderr);
  const duration=frames.at(-1).timestamp-frames[0].timestamp;
  const metadata={id:shot.id,file:output,duration,width:1920,height:1080,outputFps:30,capturedFrames:frames.length,averageCaptureFps:frames.length/duration,silent:true,proof:'Browser editor authoring and preview',coverage:shot.coverage};
  fs.writeFileSync(path.join(scratch,shot.id+'.json'),JSON.stringify(metadata,null,2)+'\n');return metadata;
}
if(require.main===module)(async()=>{
  fs.mkdirSync(scratch,{recursive:true});const browser=await chromium.launch({headless:true});
  try {for(const shot of shots){if(requested.size&&!requested.has(shot.id))continue;
    const context=await browser.newContext({viewport});try {const page=await context.newPage();page.setDefaultTimeout(10000);const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto(baseUrl);await page.waitForTimeout(800);if(await page.getByText('Skip',{exact:true}).isVisible())await page.getByText('Skip',{exact:true}).click();
    await page.locator('#hui-library-new-document').click();await button(page,shot.create).click();
    if(shot.fixture)await importFixture(page,shot.fixture);
    for(const op of shot.setup||[])await operation(page,op);
    await pause(page,1200);snapshots.clear();cursor={x:960,y:540};
    const capture=await startCapture(page,shot.id);await pause(page,1800);
    await page.screenshot({path:path.join(scratch,shot.id+'-start.png')});
    for(const op of shot.operations)await operation(page,op);
    await travel(page,page.locator('body'));await pause(page,900);await page.screenshot({path:path.join(scratch,shot.id+'-action.png')});
    if(shot.assertions){const saved=await exportJson(page);for(const [key,expected] of Object.entries(shot.assertions))assert.deepEqual(readPath(saved,key),expected,key);}
    await pause(page,2200);await page.screenshot({path:path.join(scratch,shot.id+'-end.png')});
    assert.deepEqual(errors,[],'Browser runtime errors');const metadata=await stopCapture(page,capture,shot);console.log(JSON.stringify(metadata));await context.close();}catch(error){console.error('FAILED '+shot.id+': '+error.stack);await context.close();process.exitCode=1;}
  }}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});

module.exports={pause,travel,button,click,type,operation,exportJson,startCapture,stopCapture};
