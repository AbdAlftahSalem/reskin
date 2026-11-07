import { strict as assert } from 'node:assert';
import { test } from 'node:test';

import { toWsUri, VmServiceClient, type Transport } from '../src/vm.js';

/** A fake Dart VM service that knows two isolates; only the second has reskin. */
function fakeVm(log: string[]): Transport {
  let cb: (d: string) => void = () => {};
  return {
    send(data) {
      const req = JSON.parse(data);
      log.push(req.method);
      let result: unknown;
      if (req.method === 'getVM') result = { type: 'VM', isolates: [{ id: 'isolates/1' }, { id: 'isolates/2' }] };
      else if (req.method === 'getIsolate') {
        result = { type: 'Isolate', extensionRPCs: req.params.isolateId === 'isolates/2' ? ['ext.reskin.applyTheme', 'ext.reskin.xray'] : ['ext.flutter.reassemble'] };
      } else if (req.method === 'ext.reskin.applyTheme') {
        assert.equal(req.params.isolateId, 'isolates/2');
        result = { type: '_extensionType', applied: 0, echo: req.params.prompt };
      } else if (req.method === 'ext.reskin.xray') {
        setTimeout(() => cb(JSON.stringify({ jsonrpc: '2.0', id: req.id, error: { code: -32000, message: 'Extension error', data: { details: 'No ReskinHost mounted.' } } })), 1);
        return;
      }
      setTimeout(() => cb(JSON.stringify({ jsonrpc: '2.0', method: 'streamNotify', params: {} })), 0);
      setTimeout(() => cb(JSON.stringify({ jsonrpc: '2.0', id: req.id, result })), 2);
    },
    onMessage(f) { cb = f; },
    close() {},
  };
}

test('toWsUri converts what flutter run prints', () => {
  assert.equal(toWsUri('http://127.0.0.1:5555/abc=/'), 'ws://127.0.0.1:5555/abc=/ws');
  assert.equal(toWsUri('ws://127.0.0.1:5555/abc=/ws'), 'ws://127.0.0.1:5555/abc=/ws');
});

test('finds the reskin isolate and calls the extension', async () => {
  const log: string[] = [];
  const c = new VmServiceClient(fakeVm(log));
  const r = await c.reskin<{ applied: number; echo: string }>('applyTheme', { prompt: 'gold on navy', seed: undefined });
  assert.deepEqual(r, { applied: 0, echo: 'gold on navy' });
  assert.deepEqual(log, ['getVM', 'getIsolate', 'getIsolate', 'ext.reskin.applyTheme']);
});

test('extension errors surface their details', async () => {
  const c = new VmServiceClient(fakeVm([]));
  await assert.rejects(c.reskin('xray'), /No ReskinHost mounted/);
});
