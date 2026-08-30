const $=id=>document.getElementById(id);
const state={files:[],results:[]};
const input=$('fileInput'), drop=$('dropzone'), list=$('fileList'), queue=$('queue'), results=$('results');

$('selectBtn').onclick=()=>input.click();
input.onchange=e=>addFiles([...e.target.files]);
['dragenter','dragover'].forEach(ev=>drop.addEventListener(ev,e=>{e.preventDefault();drop.classList.add('active')}));
['dragleave','drop'].forEach(ev=>drop.addEventListener(ev,e=>{e.preventDefault();drop.classList.remove('active')}));
drop.addEventListener('drop',e=>addFiles([...e.dataTransfer.files]));
$('clearBtn').onclick=()=>{state.files=[];state.results=[];render()};
$('quality').oninput=e=>$('qualityValue').textContent=e.target.value+'%';

function addFiles(files){
  state.files.push(...files.filter(f=>f.type.startsWith('image/')||f.type.startsWith('video/')));
  render();
}
function fmt(n){if(n<1024)return n+' B';let u=['KB','MB','GB'],i=-1;do{n/=1024;i++}while(n>=1024&&i<u.length-1);return n.toFixed(n<10?2:1)+' '+u[i]}
function render(){
  queue.hidden=state.files.length===0;
  list.innerHTML=state.files.map((f,i)=>`<div class="file">
    <div class="thumb"></div><div class="file-info"><div class="name">${esc(f.name)}</div><div class="meta">${fmt(f.size)} • ${f.type||'file'}</div></div>
    <button class="remove" data-i="${i}">×</button></div>`).join('');
  list.querySelectorAll('.remove').forEach(b=>b.onclick=()=>{state.files.splice(+b.dataset.i,1);render()});
  $('compressBtn').disabled=!state.files.length;
}
function esc(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}

$('compressBtn').onclick=compressAll;
async function compressAll(){
  const imageFiles=state.files.filter(f=>f.type.startsWith('image/'));
  const videoFiles=state.files.filter(f=>f.type.startsWith('video/'));
  state.results=[]; setProgress(0);
  for(let i=0;i<imageFiles.length;i++){
    state.results.push(await compressImage(imageFiles[i]));
    setProgress(Math.round(((i+1)/state.files.length)*100));
  }
  for(let i=0;i<videoFiles.length;i++){
    state.results.push({file:videoFiles[i],blob:null,error:'Video compression engine will be enabled in the next build. The file was not uploaded.'});
    setProgress(Math.round(((imageFiles.length+i+1)/state.files.length)*100));
  }
  renderResults(); setProgress(100);
}
async function compressImage(file){
  try{
    const bmp=await createImageBitmap(file);
    const max=4096, scale=Math.min(1,max/Math.max(bmp.width,bmp.height));
    const canvas=document.createElement('canvas');
    canvas.width=Math.max(1,Math.round(bmp.width*scale));canvas.height=Math.max(1,Math.round(bmp.height*scale));
    canvas.getContext('2d').drawImage(bmp,0,0,canvas.width,canvas.height);
    const type=$('format').value,q=+$('quality').value/100;
    const blob=await new Promise(r=>canvas.toBlob(r,type,q));
    return {file,blob};
  }catch(error){return {file,blob:null,error:error.message}}
}
function renderResults(){
  results.hidden=false;
  $('resultList').innerHTML=state.results.map(r=>{
    if(!r.blob)return `<div class="result"><b>${esc(r.file.name)}</b><div class="sizes">${esc(r.error||'Could not compress')}</div></div>`;
    const url=URL.createObjectURL(r.blob), saved=Math.max(0,Math.round((1-r.blob.size/r.file.size)*100));
    const ext=r.blob.type==='image/webp'?'webp':'jpg', base=r.file.name.replace(/\.[^.]+$/,'');
    return `<div class="result"><b>${esc(r.file.name)}</b><div class="sizes">${fmt(r.file.size)} → ${fmt(r.blob.size)} • ${saved}% smaller</div><a class="save" download="${esc(base+'.'+ext)}" href="${url}">Save file</a></div>`;
  }).join('');
}
function setProgress(v){$('progress').hidden=false;$('bar').style.width=v+'%';$('progressText').textContent=v+'%'}

if('serviceWorker' in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(console.warn));
let deferredPrompt;
window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();deferredPrompt=e;$('installBtn').hidden=false});
$('installBtn').onclick=async()=>{if(!deferredPrompt)return;deferredPrompt.prompt();deferredPrompt=null;$('installBtn').hidden=true};
render();
