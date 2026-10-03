const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/Users/brianfopiano/.nvm/versions/node/v24.19.0/lib/node_modules/@playwright/cli/node_modules/playwright');
const captureRoot = path.resolve(__dirname,'../../.qa/demo/captures');
const ids = process.argv.slice(2);
const server = http.createServer((request,response)=>{
  const id = decodeURIComponent(request.url.slice(1));
  if(!ids.includes(id)){response.writeHead(404).end();return;}
  const file=path.join(captureRoot,id+'-editor.webm');
  response.writeHead(200,{'Content-Type':'video/webm','Content-Length':fs.statSync(file).size});
  fs.createReadStream(file).pipe(response);
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.launch({headless:true});
  const accepted=[];
  try {const page=await browser.newPage();for(const id of ids){
    await page.setContent('<video muted></video>');
    const result=await page.evaluate(async({url})=>{
      const video=document.querySelector('video');video.src=url;
      await new Promise((resolve,reject)=>{video.onloadedmetadata=resolve;video.onerror=reject;});
      await video.play();await new Promise(resolve=>setTimeout(resolve,1100));
      const first=video.getVideoPlaybackQuality().totalVideoFrames;
      await new Promise(resolve=>setTimeout(resolve,1100));
      const second=video.getVideoPlaybackQuality().totalVideoFrames;
      video.pause();
      for(const time of [video.duration/2,video.duration-.2]){
        video.currentTime=time;await new Promise(resolve=>video.onseeked=resolve);
      }
      return {duration:video.duration,width:video.videoWidth,height:video.videoHeight,first,second,error:video.error?.message};
    },{url:`http://127.0.0.1:${server.address().port}/${id}`});
    assert.equal(result.width,1920);assert.equal(result.height,1080);
    assert.ok(result.second>result.first+10,'Continuous browser decoding must advance');assert.ok(!result.error);
    accepted.push({...JSON.parse(fs.readFileSync(path.join(captureRoot,id+'.json'))),browserPlayback:result});
    process.stdout.write(id+' verified\n');
  }
  fs.writeFileSync(path.join(captureRoot,'accepted-manifest.json'),JSON.stringify(accepted,null,2)+'\n');
  }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);process.exitCode=1;server.close();});
