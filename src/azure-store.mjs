import sql from 'mssql';
import {createClient} from 'redis';
import {BlobServiceClient} from '@azure/storage-blob';
import {DefaultAzureCredential} from '@azure/identity';
import {randomUUID} from 'node:crypto';
export class AzureStore{
mode='azure';
static async connect(){const s=new AzureStore();s.pool=await new sql.ConnectionPool({server:process.env.SQL_SERVER,database:'commerce',user:process.env.SQL_USER,password:process.env.SQL_PASSWORD,options:{encrypt:true,trustServerCertificate:false},pool:{max:10,min:0,idleTimeoutMillis:30000}}).connect();s.redis=createClient({socket:{host:process.env.REDIS_HOST,port:10000,tls:true,connectTimeout:3000,reconnectStrategy:retries=>Math.min(retries*500,5000)},password:process.env.REDIS_PASSWORD,disableOfflineQueue:true});s.redis.on('error',()=>console.warn(JSON.stringify({event:'cache-unavailable'})));s.redis.connect().catch(()=>{});s.blobs=new BlobServiceClient('https://'+process.env.STORAGE_ACCOUNT+'.blob.core.windows.net',new DefaultAzureCredential()).getContainerClient('products');return s;}
async ready(){await this.pool.request().query('SELECT TOP (1) id FROM dbo.Products');}
async products(fresh=false){if(!fresh&&this.redis.isReady){try{const hit=await this.redis.get('catalog:v1');if(hit)return JSON.parse(hit);}catch{}}const {recordset}=await this.pool.request().query('SELECT id,name,priceCents,category,glyph FROM dbo.Products ORDER BY id');if(this.redis.isReady){try{await this.redis.set('catalog:v1',JSON.stringify(recordset),{EX:60});}catch{}}return recordset;}
async order(key,order){const request=()=>this.pool.request().input('key',sql.VarChar(80),key);const existing=await request().query('SELECT payload FROM dbo.Orders WHERE idempotencyKey=@key');const check=row=>{const saved=JSON.parse(row.payload);if(JSON.stringify(saved.items)!==JSON.stringify(order.items))throw Object.assign(Error('Idempotency key already used for another cart.'),{status:409});return saved;};if(existing.recordset.length)return check(existing.recordset[0]);const saved={id:randomUUID(),...order,currency:'USD'};try{await request().input('id',sql.UniqueIdentifier,saved.id).input('payload',sql.NVarChar(sql.MAX),JSON.stringify(saved)).query('INSERT INTO dbo.Orders(id,idempotencyKey,payload) VALUES(@id,@key,@payload)');return saved;}catch(e){if([2601,2627].includes(e.number)){const winner=await request().query('SELECT payload FROM dbo.Orders WHERE idempotencyKey=@key');if(winner.recordset.length)return check(winner.recordset[0]);}throw e;}}
async image(name){return this.blobs.getBlockBlobClient(name).downloadToBuffer();}
async close(){if(this.redis.isOpen)this.redis.destroy();await this.pool.close();}
}
