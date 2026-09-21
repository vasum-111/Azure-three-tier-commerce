import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
export class MemoryStore{
 mode='memory-demo';orders=new Map();
 async ready(){}
 async products(){return JSON.parse(await readFile(new URL('../data/products.json',import.meta.url),'utf8'));}
 async order(key,order){const existing=this.orders.get(key);if(existing){if(JSON.stringify(existing.items)!==JSON.stringify(order.items))throw Object.assign(Error('Idempotency key already used for another cart.'),{status:409});return existing;}
 const saved={id:randomUUID(),...order,currency:'USD'};if(this.orders.size>=1000)this.orders.delete(this.orders.keys().next().value);this.orders.set(key,saved);return saved;}
 async image(name){return readFile(new URL('../assets/'+name,import.meta.url));}
}
