import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,extname,sep} from 'node:path';
import {randomUUID} from 'node:crypto';
import {MemoryStore} from './store.mjs';
const web=resolve(fileURLToPath(new URL('../web/',import.meta.url)));
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json','.svg':'image/svg+xml'};
export function validateOrder(body,products){
 if(!body||!Array.isArray(body.items)||!body.items.length||body.items.length>20)throw Object.assign(Error('Provide 1–20 items.'),{status:400});
 const seen=new Set();const items=body.items.map(i=>{const p=products.find(p=>p.id===i.id);if(!p||seen.has(i.id)||!Number.isInteger(i.quantity)||i.quantity<1||i.quantity>10)throw Object.assign(Error('Invalid product or quantity (1–10).'),{status:400});seen.add(i.id);return {id:p.id,quantity:i.quantity,priceCents:p.priceCents};}).sort((a,b)=>a.id.localeCompare(b.id));
 return {items,totalCents:items.reduce((n,i)=>n+i.quantity*i.priceCents,0)};
}
export function createServer(store=new MemoryStore(),{commerce=false}={}){
return http.createServer(async(req,res)=>{
const requestId=randomUUID();res.setHeader('X-Request-ID',requestId);res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('Content-Security-Policy',"default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'");
const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
try{
const url=new URL(req.url,'http://localhost');const route=url.pathname;
if(route==='/healthz')return json(200,{status:'ok'});
if(route==='/readyz'){await store.ready();return json(200,{status:'ready',mode:store.mode});}
if(req.method==='GET'&&route==='/api/products'){return json(200,{products:await store.products()});}
if(req.method==='GET'&&route.startsWith('/api/products/')){const p=(await store.products()).find(p=>p.id===route.split('/').pop());return p?json(200,p):json(404,{error:'Product not found'});}
if(commerce&&req.method==='GET'&&/^\/api\/images\/[a-z-]+\.svg$/.test(route)){const bytes=await store.image(route.split('/').pop());res.writeHead(200,{'Content-Type':'image/svg+xml','Cache-Control':'public, max-age=3600'});return res.end(bytes);}
if(commerce&&route==='/api/orders'&&req.method==='POST'){
if(!(req.headers['content-type']||'').startsWith('application/json'))return json(415,{error:'Use application/json'});
const key=req.headers['idempotency-key'];if(typeof key!=='string'||!/^[-a-zA-Z0-9]{16,80}$/.test(key))return json(400,{error:'Provide an Idempotency-Key of 16–80 letters, numbers or hyphens.'});
let raw='';let bytes=0;for await(const chunk of req){bytes+=chunk.length;if(bytes>16384){json(413,{error:'Request too large'});return;}raw+=chunk;}
let body;try{body=JSON.parse(raw);}catch{return json(400,{error:'Malformed JSON'});}
const order=validateOrder(body,await store.products(true));return json(201,await store.order(key,order));
}
if(route.startsWith('/api/'))return json(404,{error:'Route not found'});
if(!['GET','HEAD'].includes(req.method))return json(405,{error:'Method not allowed'});
let decoded;try{decoded=decodeURIComponent(route);}catch{return json(400,{error:'Invalid path'});}
const file=resolve(web,'.'+(decoded==='/'?'/index.html':decoded));if(!file.startsWith(web+sep))return json(404,{error:'Not found'});
let content;try{content=await readFile(file);}catch{return json(404,{error:'Not found'});}
res.writeHead(200,{'Content-Type':mime[extname(file)]||'application/octet-stream','Cache-Control':'no-cache'});res.end(req.method==='HEAD'?undefined:content);
}catch(e){const status=e.status||503;console.error(JSON.stringify({requestId,status,error:e.name}));json(status,{error:status===400||status===409?e.message:'Service temporarily unavailable',requestId});}
});}
if(process.argv[1]===fileURLToPath(import.meta.url)){
let store=new MemoryStore();if(process.env.DATA_MODE==='azure'){const {AzureStore}=await import('./azure-store.mjs');store=await AzureStore.connect();}
const server=createServer(store,{commerce:process.env.COMMERCE==='true'});server.requestTimeout=15000;server.headersTimeout=10000;server.listen(Number(process.env.PORT||8080),'0.0.0.0',()=>console.log(JSON.stringify({event:'listening',port:Number(process.env.PORT||8080),mode:store.mode})));
process.on('SIGTERM',()=>{server.close(async()=>{await store.close?.();process.exit(0);});setTimeout(()=>process.exit(1),10000).unref();});
}
