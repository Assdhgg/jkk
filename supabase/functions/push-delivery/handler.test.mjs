import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from './handler.mjs';

test('requires service bearer and reports only counts', async () => {
 let calls=0; const done=[];
 const handler=createHandler({secret:'local-test-secret',claim:async()=>{calls++;return [{job_id:'j',lease_id:'l',token:'private-fid',kind:'approved'}];},send:async()=>({success:true,permanent:false}),finish:async(...args)=>done.push(args)});
 assert.equal((await handler(new Request('http://local/',{method:'POST'}))).status,401); assert.equal(calls,0);
 const response=await handler(new Request('http://local/',{method:'POST',headers:{authorization:'Bearer local-test-secret'}}));
 assert.deepEqual(await response.json(),{processed:1,sent:1,unconfirmed:0}); assert.deepEqual(done,[['j','l',true,false]]);
});
test('transient send failure returns job for retry', async () => {
 const done=[];const handler=createHandler({secret:'secret',claim:async()=>[{job_id:'j',lease_id:'l',token:'x',kind:'support_reply'}],send:async()=>{throw Error('offline');},finish:async(...args)=>done.push(args)});
 const response=await handler(new Request('http://local/',{method:'POST',headers:{authorization:'Bearer secret'}}));assert.equal(response.status,200);assert.deepEqual(done,[['j','l',false,false]]);
});

test('worker secret authorizes scheduling without exposing a service key', async () => {
 let calls = 0;
 const handler = createHandler({secret: 'service-key', workerSecret: 'worker-secret', claim: async () => { calls++; return []; }, send: async () => {}, finish: async () => {}});
 const request = key => new Request('http://local/', {method: 'POST', headers: {authorization: 'Bearer public-jwt', 'x-push-worker-secret': key}});
 assert.equal((await handler(request('wrong'))).status, 401);
 assert.equal(calls, 0);
 assert.equal((await handler(request('worker-secret'))).status, 200);
 assert.equal(calls, 1);
});

test('app update uses an update notification message', async () => {
  let notification;
  const handler = createHandler({secret:'secret',claim:async()=>[{job_id:'j',lease_id:'l',token:'x',kind:'app_update'}],send:async(_token,title,body)=>{notification={title,body}; return {success:true,permanent:false};},finish:async()=>{}});
  await handler(new Request('https://worker.test',{method:'POST',headers:{authorization:'Bearer secret'}}));
  assert.equal(notification.title, 'App update available');
  assert.match(notification.body, /download and install/);
});


test('all push notification messages use the new app name', async () => {
  const kinds = ['app_update', 'approved', 'rejected', 'coins_received', 'support_reply', 'unknown'];
  const messages = [];
  const handler = createHandler({secret: 'secret', claim: async () => kinds.map(kind => ({job_id: kind, lease_id: 'lease', token: 'synthetic', kind})), send: async (_token, title, body) => { messages.push({title, body}); return {success: true, permanent: false}; }, finish: async () => {}});
  const response = await handler(new Request('https://worker.test', {method: 'POST', headers: {authorization: 'Bearer secret'}}));
  assert.equal(response.status, 200);
  assert.equal(messages.length, kinds.length);
  for (const message of messages) {
    assert.match(message.body, /Freelan Space/);
    assert.doesNotMatch(`${message.title} ${message.body}`, /Growth Circle/i);
  }
});

test('admin messages send their own title and body without changing existing messages', async () => {
 const sent=[];
 const jobs=[{job_id:'a',lease_id:'1',token:'device-a',kind:'admin_message',title:'Maintenance',body:'We are updating the app.'},{job_id:'b',lease_id:'2',token:'device-b',kind:'approved',title:null,body:null}];
 const handler=createHandler({secret:'local-secret',claim:async()=>jobs,send:async(...args)=>{sent.push(args);return {success:true,permanent:false}},finish:async()=>{}});
 const res=await handler(new Request('https://worker.test',{method:'POST',headers:{authorization:'Bearer local-secret'}}));
 assert.equal(res.status,200);
 assert.deepEqual(sent[0],['device-a','Maintenance','We are updating the app.','admin_message']);
 assert.deepEqual(sent[1],['device-b','Submission approved','Open Freelan Space to see your update.','approved']);
});

test('HTTP v1 uses registration token and a high importance Android channel', async () => {
 const {fcmMessage}=await import('./payload.mjs');
 const payload=fcmMessage('synthetic-fcm-token','Hello','Message','admin_message');
 assert.equal(payload.message.token,'synthetic-fcm-token');
 assert.equal('fid' in payload.message,false);
 assert.deepEqual(payload.message.notification,{title:'Hello',body:'Message'});
 assert.equal(payload.message.android.priority,'HIGH');
 assert.equal(payload.message.android.notification.channel_id,'freelan_updates');
});

test('full batch immediately schedules the next batch', async () => {
 let continued=0;
 const handler=createHandler({secret:'secret',claim:async()=>Array.from({length:100},(_,i)=>({job_id:String(i),lease_id:'l',token:'synthetic',kind:'approved'})),send:async()=>({success:true,permanent:false}),finish:async()=>{},continueDelivery:()=>{continued++;}});
 const response=await handler(new Request('https://worker.test',{method:'POST',headers:{authorization:'Bearer secret'}}));
 assert.equal((await response.json()).sent,100);
 assert.equal(continued,1);
});
