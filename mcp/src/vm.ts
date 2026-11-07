/** Minimal Dart VM service (JSON-RPC 2.0 over WebSocket) client for reskin's extensions. */

export interface Transport {
  send(data: string): void;
  onMessage(cb: (data: string) => void): void;
  close(): void;
}

/** Normalises what `flutter run` prints (http://127.0.0.1:1234/abc=/) to the ws URI. */
export function toWsUri(uri: string): string {
  let u = uri.trim();
  if (u.startsWith('http://')) u = 'ws://' + u.slice(7);
  else if (u.startsWith('https://')) u = 'wss://' + u.slice(8);
  if (!u.endsWith('/ws')) u = u.replace(/\/?$/, '/ws');
  return u;
}

export async function connectWebSocket(uri: string, timeoutMs = 8000): Promise<Transport> {
  const WS = (globalThis as { WebSocket?: typeof WebSocket }).WebSocket;
  if (!WS) throw new Error('This Node has no global WebSocket (need Node 22+).');
  const ws = new WS(toWsUri(uri));
  await new Promise<void>((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`VM service did not answer at ${uri}`)), timeoutMs);
    ws.addEventListener('open', () => { clearTimeout(t); resolve(); });
    ws.addEventListener('error', () => { clearTimeout(t); reject(new Error(`Cannot connect to VM service at ${uri}`)); });
  });
  return {
    send: (d) => ws.send(d),
    onMessage: (cb) => ws.addEventListener('message', (e: MessageEvent) => cb(String(e.data))),
    close: () => ws.close(),
  };
}

export class VmServiceClient {
  private nextId = 1;
  private pending = new Map<string, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();

  constructor(private readonly transport: Transport, private readonly timeoutMs = 20000) {
    transport.onMessage((raw) => {
      let msg: { id?: string | number; result?: unknown; error?: { message?: string; data?: unknown } };
      try { msg = JSON.parse(raw); } catch { return; }
      if (msg.id === undefined) return; // stream events
      const p = this.pending.get(String(msg.id));
      if (!p) return;
      this.pending.delete(String(msg.id));
      if (msg.error) {
        const detail = (msg.error.data as { details?: string } | undefined)?.details;
        p.reject(new Error(msg.error.message + (detail ? `: ${detail}` : '')));
      } else p.resolve(msg.result);
    });
  }

  call<T = unknown>(method: string, params: Record<string, unknown> = {}): Promise<T> {
    const id = String(this.nextId++);
    const body = JSON.stringify({ jsonrpc: '2.0', id, method, params });
    return new Promise<T>((resolve, reject) => {
      const t = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`VM service call ${method} timed out`));
      }, this.timeoutMs);
      this.pending.set(id, {
        resolve: (v) => { clearTimeout(t); resolve(v as T); },
        reject: (e) => { clearTimeout(t); reject(e); },
      });
      this.transport.send(body);
    });
  }

  /** The isolate that registered `ext.reskin.*`. */
  async findReskinIsolate(): Promise<string> {
    const vm = await this.call<{ isolates: { id: string }[] }>('getVM');
    for (const iso of vm.isolates ?? []) {
      const info = await this.call<{ extensionRPCs?: string[] }>('getIsolate', { isolateId: iso.id });
      if ((info.extensionRPCs ?? []).includes('ext.reskin.applyTheme')) return iso.id;
    }
    throw new Error('No isolate has reskin extensions. Is the app running in debug with Reskin.builder()?');
  }

  /** Calls `ext.reskin.<name>`; params are sent as strings, as service extensions expect. */
  async reskin<T = unknown>(name: string, params: Record<string, string | undefined> = {}): Promise<T> {
    const isolateId = await this.findReskinIsolate();
    const clean: Record<string, string> = { isolateId };
    for (const [k, v] of Object.entries(params)) if (v !== undefined) clean[k] = v;
    const res = await this.call<Record<string, unknown>>(`ext.reskin.${name}`, clean);
    const { type: _type, ...rest } = res ?? {};
    return rest as T;
  }

  close(): void { this.transport.close(); }
}
