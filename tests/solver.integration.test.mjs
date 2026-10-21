import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
const cli=resolve('_build/js/debug/build/cmd/moonpocket/moonpocket.js');
const clock=n=>String(Math.floor(n/60)).padStart(2,'0')+':'+String(n%60).padStart(2,'0');
const minute=s=>Number(s.slice(0,2))*60+Number(s.slice(3));
const run=(args,input)=>spawnSync(process.execPath,[cli,...args],{encoding:'utf8',input});

test('planner exact objective matches independent permutation and minute oracle',()=>{
 const dir=mkdtempSync(join(tmpdir(),'pocket-plan-'));
 let seed=937; const rnd=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n};
 try {for(let trial=0;trial<48;trial++){
   const recovery=rnd(9), switching=rnd(11);
   const events=Array.from({length:rnd(4)},()=>{const s=rnd(110);return [s,Math.min(120,s+5+rnd(20))]});
   const busy=Array(120).fill(false); for(const [s,e] of events)for(let t=s;t<e;t++)busy[t]=true;
   const free=Array(120).fill(false);
   for(let t=0;t<120;){if(busy[t]){t++;continue}const s=t;while(t<120&&!busy[t])t++;for(let u=s+(s?recovery:0);u<t;u++)free[u]=true}
   const tasks=Array.from({length:3+rnd(4)},(_,i)=>{const release=rnd(50), deadline=60+rnd(61);return{id:'t'+i,duration:5+rnd(26),release,deadline,value:1+rnd(15),context:rnd(3),parent:i>0&&rnd(3)===0?rnd(i):-1}});
   let best=[0,0,0];
   const slot=(task,ready)=>{for(let s=Math.max(ready,task.release);s+task.duration<=task.deadline;s++){let ok=true;for(let u=s;u<s+task.duration;u++)if(!free[u]){ok=false;break}if(ok)return s}return null};
   function search(mask,last,end,value,count){if(value>best[0]||(value===best[0]&&(count>best[1]||(count===best[1]&&end<best[2]))))best=[value,count,end];for(let i=0;i<tasks.length;i++){const t=tasks[i];if(mask&(1<<i)||t.parent>=0&&!(mask&(1<<t.parent)))continue;const s=slot(t,end+(last>=0&&tasks[last].context!==t.context?switching:0));if(s!==null)search(mask|(1<<i),i,s+t.duration,value+t.value,count+1)}}
   search(0,-1,0,0,0);
   const day=['day 09:00 11:00',...events.map(([s,e],i)=>'fixed e'+i+' '+clock(540+s)+' '+clock(540+e))].join('\n');
   const text=tasks.map(t=>'task '+t.id+' '+t.duration+' '+clock(540+t.release)+' '+clock(540+t.deadline)+' '+t.value+' c'+t.context).concat(tasks.filter(t=>t.parent>=0).map(t=>'after '+t.id+' t'+t.parent)).join('\n');
   const taskPath=join(dir,'tasks.txt');writeFileSync(taskPath,text);
   const result=run(['--input','-','--mode','plan','--tasks',taskPath,'--recovery',String(recovery),'--switch',String(switching)],day);
   assert.equal(result.status,0,result.stderr);const r=JSON.parse(result.stdout);
   assert.deepEqual([r.total_value,r.scheduled_count,r.assignments.length?minute(r.assignments.at(-1).end)-540:0],best,'scenario '+trial);
   const done=new Set();let end=0,last=null;for(const a of r.assignments){const t=tasks.find(t=>t.id===a.task_id),s=minute(a.start)-540,e=minute(a.end)-540;assert.ok(!done.has(t.id));assert.equal(e-s,t.duration);assert.ok(s>=t.release&&e<=t.deadline);assert.ok(s>=end+(last&&last.context!==t.context?switching:0));if(t.parent>=0)assert.ok(done.has('t'+t.parent));for(let u=s;u<e;u++)assert.ok(free[u]);done.add(t.id);end=e;last=t}
 }}finally{rmSync(dir,{recursive:true,force:true})}
});

test('reclaim joint synergy costs and infeasible exit code',()=>{
 const day='day 09:00 12:00\nbusy a 09:30 10:00\nbusy b 10:30 11:00';
 const dir=mkdtempSync(join(tmpdir(),'pocket-reclaim-'));
 try{const costs=join(dir,'costs');writeFileSync(costs,'cost a 2\ncost b 3');
 for(const [budget,status] of [[4,1],[5,0]]){const p=run(['--input','-','--mode','reclaim','--target','180','--budget',String(budget),'--costs',costs,'--recovery','0'],day);assert.equal(p.status,status,p.stderr);const r=JSON.parse(p.stdout);assert.equal(r.optimal,true);if(!status){assert.equal(r.solution.cost,5);assert.deepEqual(r.solution.removed_ids,['a','b'])}}
 assert.equal(run(['--mode','plan','--tasks',costs],'').status,2);
 assert.equal(run(['--mode','bad'],'').status,2);
 }finally{rmSync(dir,{recursive:true,force:true})}
});
