import { dlopen, FFIType, suffix, ptr, read } from "bun:ffi";

const lib = dlopen(`./zig-out/lib/liblmdbx.${suffix}`, {
  open: {
    args: [FFIType.cstring, FFIType.ptr],
    returns: FFIType.i32,
  },
  close: {
    args: [FFIType.u64],
    returns: FFIType.void,
  },
  put: {
    args: [FFIType.u64, FFIType.ptr, FFIType.u64, FFIType.ptr, FFIType.u64],
    returns: FFIType.i32,
  },
  get: {
    args: [FFIType.u64, FFIType.ptr, FFIType.u64, FFIType.ptr, FFIType.ptr],
    returns: FFIType.i32,
  },
  free: {
    args: [FFIType.u64, FFIType.u64],
    returns: FFIType.void,
  },
  del: {
    args: [FFIType.u64, FFIType.ptr, FFIType.u64],
    returns: FFIType.i32,
  },
  flush: {
    args: [FFIType.u64],
    returns: FFIType.i32,
  },
  txn_begin: {
    args: [FFIType.u64],
    returns: FFIType.i32,
  },
  txn_commit: {
    args: [FFIType.u64],
    returns: FFIType.i32,
  },
  txn_abort: {
    args: [FFIType.u64],
    returns: FFIType.void,
  },
  cursor_open: {
    args: [FFIType.u64, FFIType.ptr],
    returns: FFIType.i32,
  },
  cursor_close: {
    args: [FFIType.u64],
    returns: FFIType.void,
  },
  cursor_get: {
    args: [FFIType.u64, FFIType.ptr, FFIType.ptr, FFIType.ptr, FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
});

export class Database {
  private db: bigint;
  private resultPtr = new BigUint64Array(1);
  private resultLen = new BigUint64Array(1);

  constructor(path: string) {
    const dbPtr = new BigUint64Array(1);
    const rc = lib.symbols.open(Buffer.from(path + "\0"), ptr(dbPtr));
    if (rc !== 0) throw new Error(`Failed to open database: ${rc}`);
    this.db = dbPtr[0];
  }

  put(key: string | Buffer, value: string | Buffer): void {
    const k = Buffer.isBuffer(key) ? key : Buffer.from(key);
    const v = Buffer.isBuffer(value) ? value : Buffer.from(value);
    const rc = lib.symbols.put(this.db, ptr(k), BigInt(k.length), ptr(v), BigInt(v.length));
    if (rc !== 0) throw new Error(`Put failed: ${rc}`);
  }

  get(key: string | Buffer): Buffer | null {
    const k = Buffer.isBuffer(key) ? key : Buffer.from(key);
    const rc = lib.symbols.get(this.db, ptr(k), BigInt(k.length), ptr(this.resultPtr), ptr(this.resultLen));

    if (rc === -2) return null;
    if (rc !== 0) throw new Error(`Get failed: ${rc}`);

    const dataPtr = Number(this.resultPtr[0]);
    const len = Number(this.resultLen[0]);
    const buf = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      buf[i] = read.u8(dataPtr, i);
    }
    lib.symbols.free(this.resultPtr[0], BigInt(len));
    return Buffer.from(buf);
  }

  delete(key: string | Buffer): void {
    const k = Buffer.isBuffer(key) ? key : Buffer.from(key);
    const rc = lib.symbols.del(this.db, ptr(k), BigInt(k.length));
    if (rc !== 0) throw new Error(`Delete failed: ${rc}`);
  }

  flush(): void {
    const rc = lib.symbols.flush(this.db);
    if (rc !== 0) throw new Error(`Flush failed: ${rc}`);
  }

  beginTransaction(): void {
    const rc = lib.symbols.txn_begin(this.db);
    if (rc !== 0) throw new Error(`Begin transaction failed: ${rc}`);
  }

  commitTransaction(): void {
    const rc = lib.symbols.txn_commit(this.db);
    if (rc !== 0) throw new Error(`Commit transaction failed: ${rc}`);
  }

  abortTransaction(): void {
    lib.symbols.txn_abort(this.db);
  }

  transaction<T>(fn: () => T): T {
    this.beginTransaction();
    try {
      const result = fn();
      this.commitTransaction();
      return result;
    } catch (err) {
      this.abortTransaction();
      throw err;
    }
  }

  getRange(options?: {
    start?: string | Buffer,
    end?: string | Buffer,
    limit?: number,
    reverse?: boolean
  }) {
    const cursorPtr = new BigUint64Array(1);
    const rc = lib.symbols.cursor_open(this.db, ptr(cursorPtr));
    if (rc !== 0) throw new Error(`Cursor open failed: ${rc}`);

    const cursor = cursorPtr[0];
    const keyPtr = new BigUint64Array(1);
    const keyLen = new BigUint64Array(1);
    const valuePtr = new BigUint64Array(1);
    const valueLen = new BigUint64Array(1);

    const MDBX_FIRST = 0;
    const MDBX_NEXT = 8;
    const results: Array<{ key: Buffer, value: Buffer }> = [];

    let op = MDBX_FIRST;
    let count = 0;
    const maxLimit = options?.limit || 1000000;

    while (count < maxLimit) {
      const rc = lib.symbols.cursor_get(cursor, ptr(keyPtr), ptr(keyLen), ptr(valuePtr), ptr(valueLen), op);
      if (rc !== 0) break;

      const kLen = Number(keyLen[0]);
      const vLen = Number(valueLen[0]);
      const kPtr = Number(keyPtr[0]);
      const vPtr = Number(valuePtr[0]);

      const key = Buffer.alloc(kLen);
      const value = Buffer.alloc(vLen);

      for (let i = 0; i < kLen; i++) key[i] = read.u8(kPtr, i);
      for (let i = 0; i < vLen; i++) value[i] = read.u8(vPtr, i);

      results.push({ key, value });
      count++;
      op = MDBX_NEXT;
    }

    lib.symbols.cursor_close(cursor);
    return results;
  }

  close(): void {
    lib.symbols.close(this.db);
  }
}
