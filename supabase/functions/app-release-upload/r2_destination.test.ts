import { S3Client, CopyObjectCommand } from 'npm:@aws-sdk/client-s3@3.899.0';
import assert from 'node:assert/strict';
import { preventDestinationOverwrite } from './r2_destination.mjs';

Deno.test('SDK signs the R2 destination condition and source ETag', async () => {
  let headers: Headers | undefined;
  const server = Deno.serve({hostname: '127.0.0.1', port: 0, onListen: () => {}}, request => {
    headers = request.headers;
    return new Response('<CopyObjectResult><ETag>"ok"</ETag></CopyObjectResult>', {
      status: 200, headers: {'content-type': 'application/xml'},
    });
  });
  const address = server.addr as Deno.NetAddr;
  const s3 = new S3Client({
    region: 'auto', endpoint: `http://127.0.0.1:${address.port}`, forcePathStyle: true,
    credentials: {accessKeyId: 'synthetic', secretAccessKey: 'synthetic'},
  });
  try {
    await s3.send(preventDestinationOverwrite(new CopyObjectCommand({
      Bucket: 'fixture', Key: 'releases/freelan-space-v1.2.0-8.apk',
      CopySource: 'fixture/staging/source.apk', CopySourceIfMatch: '"source-etag"',
    })));
    assert.equal(headers?.get('cf-copy-destination-if-none-match'), '*');
    assert.equal(headers?.get('x-amz-copy-source-if-match'), '"source-etag"');
    assert.match(headers?.get('authorization') ?? '', /cf-copy-destination-if-none-match/);
  } finally {
    s3.destroy();
    await server.shutdown();
  }
});
