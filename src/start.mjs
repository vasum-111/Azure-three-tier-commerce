process.env.COMMERCE='true';
const {spawn}=await import('node:child_process');
const p=spawn(process.execPath,['src/server.mjs'],{stdio:'inherit',env:process.env});
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>p.kill(signal));
p.on('exit',code=>process.exit(code??0));
