import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from './handler.mjs';

const user = '12345678-1234-4234-8234-123456789abc';
const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const key = `staging/${user}/${id}.apk`;
const metadata = {action: 'publish', key, size: 100, versionCode: 8, versionName: '1.2.0', notes: 'update', sha256: 'a'.repeat(64)};
const request = body => new Request('https://example.test', {method: 'POST', headers: {authorization: 'Bearer test'}, body: JSON.stringify(body)});
function fixture(overrides = {}) {
  const calls = [];
  const handler = createHandler({
    authorize: async () => user,
    signUpload: async (path, size) => {calls.push(['sign', path, size]); return 'https://upload.example.test';},
    copyUpload: async (...args) => {calls.push(['copy', ...args]);},
    publish: async args => {calls.push(['publish', args]);},
    publicBase: 'https://releases.example.test', randomUUID: () => id, ...overrides,
  });
  return {handler, calls};
}
test('only an authorized editor can prepare or publish', async () => {
  const {handler, calls} = fixture({authorize: async () => null});
  assert.equal((await handler(request({action: 'prepare', size: 100}))).status, 403);
  assert.equal((await handler(request(metadata))).status, 403);
  assert.deepEqual(calls, []);
});
test('prepare signs a bounded staging upload owned by the editor', async () => {
  const {handler, calls} = fixture();
  const result = await handler(request({action: 'prepare', size: 100}));
  assert.deepEqual(await result.json(), {key, url: 'https://upload.example.test'});
  assert.deepEqual(calls, [['sign', key, 100]]);
  assert.equal((await handler(request({action: 'prepare', size: 209715201}))).status, 400);
});
test('publication copies first to a separate immutable release key', async () => {
  const {handler, calls} = fixture();
  assert.equal((await handler(request(metadata))).status, 200);
  assert.deepEqual(calls[0], ['copy', key, `releases/${id}.apk`, 100]);
  assert.equal(calls[1][1].downloadUrl, `https://releases.example.test/releases/${id}.apk`);
  assert.equal(calls[1][1].userId, user);
});
test('rejects foreign staging paths, invalid metadata and failed copies', async () => {
  const {handler, calls} = fixture({copyUpload: async () => {throw Error('copy failed');}});
  assert.equal((await handler(request({...metadata, key: `staging/other/${id}.apk`}))).status, 400);
  assert.equal((await handler(request({...metadata, sha256: 'bad'}))).status, 400);
  assert.equal((await handler(request(metadata))).status, 503);
  assert.deepEqual(calls, []);
});
test('rejects invalid public endpoint before copying', async () => {
  const {handler, calls} = fixture({publicBase: 'http://example.test'});
  assert.equal((await handler(request(metadata))).status, 503);
  assert.deepEqual(calls, []);
});

test('rechecks editor access before publishing after a copy', async () => {
  let checks = 0;
  const {handler, calls} = fixture({authorize: async () => ++checks === 1 ? user : null});
  assert.equal((await handler(request(metadata))).status, 403);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'copy');
});
