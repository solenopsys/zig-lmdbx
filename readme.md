# zig-lmdbx

Zig wrapper for libmdbx with C API exports.

## Features

- Zig-native interface to libmdbx
- C API exports for FFI usage (Bun, Node.js, etc.)
- Transaction support
- Cursor operations

## Performance

Outperforms lmdb-js by ~20% in bulk operations and 10-20x faster when each write uses a separate transaction.

## Why libmdbx over lmdb

- Auto-resizing database without manual configuration
- Better write performance and scalability
- Improved data integrity with checksums
- More efficient space reclamation
- Enhanced ACID guarantees
- Better handling of large databases (up to 128TB)
- Active development and bug fixes

## Building

```bash
zig build -Doptimize=ReleaseFast
```

The build process automatically copies the version.c file and compiles libmdbx as a static library.

## Usage

The library exports a C API with the following functions:

- `open(path, db_ptr)` - Open database
- `close(db_ptr)` - Close database
- `put(db_ptr, key, key_len, value, value_len)` - Store key-value pair
- `get(db_ptr, key, key_len, value_ptr, value_len)` - Retrieve value
- `del(db_ptr, key, key_len)` - Delete key
- `flush(db_ptr)` - Flush changes
- `txn_begin(db_ptr)` - Begin transaction
- `txn_commit(db_ptr)` - Commit transaction
- `txn_abort(db_ptr)` - Abort transaction
- `cursor_open(db_ptr, cursor_ptr)` - Open cursor
- `cursor_close(cursor_ptr)` - Close cursor
- `cursor_get(cursor_ptr, ...)` - Cursor operations

## Examples

The `bun_examples/` directory contains TypeScript examples for Bun runtime:

- `test.ts` - Basic usage example (put, get, delete operations)
- `performance-test.ts` - Performance benchmark for bulk operations
- `performance-test-txn.ts` - Performance benchmark with transactions
- `test-range.ts` - Cursor operations and range queries
- `lmdbx.ts` - TypeScript FFI bindings

## Requirements

- Zig 0.15.1+
- libmdbx submodule in `libs/libmdbx`
