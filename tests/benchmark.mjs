import {spawnSync} from 'node:child_process';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
const cli=resolve('_build/js/debug/build/cmd/moonpocket/moonpocket.js');
const dir=mkdtempSync(join(tmpdir(),'moonpocket-bench-'));
try {
  const tasks=[];
  for(let i=0;i<12;i++) tasks.push(`task t${i} 5 09:00 18:00 ${i+1} c${i%3}`);
  const path=join(dir,'tasks.txt'); writeFileSync(path,tasks.join('\n'));
  const samples=20; const started=performance.now();
  for(let i=0;i<samples;i++) {
    const result=spawnSync(process.execPath,[cli,'--input','examples/quiet.day','--mode','plan','--tasks',path],{encoding:'utf8'});
    if(result.status!==0) throw new Error(result.stderr);
  }
  const elapsed=performance.now()-started;
  console.log(JSON.stringify({name:'planner-12-task',samples,average_ms:Number((elapsed/samples).toFixed(3)),total_ms:Number(elapsed.toFixed(3))}));
} finally { rmSync(dir,{recursive:true,force:true}); }
