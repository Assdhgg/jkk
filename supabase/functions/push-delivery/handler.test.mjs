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
