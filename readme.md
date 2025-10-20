# zig-lmdbx

Zig wrapper for libmdbx with C API exports for easy FFI integration.

## Features

- Zig-native interface to libmdbx
- C API exports for FFI usage (Bun, Node.js, Deno, etc.)
- Full transaction support with ACID guarantees
- Cursor operations for efficient iteration
- Cross-compilation support for multiple architectures
- Zero dependencies - statically linked libmdbx

## Performance

Based on our benchmarks, libmdbx significantly outperforms LMDB:

- **Read operations**: 20-30% faster than LMDB
- **Transactional writes**: 10-20x faster than LMDB when each write uses a separate transaction
- **Bulk operations**: ~20% faster than lmdb-js in bulk inserts

The performance advantage is especially noticeable in write-heavy workloads with proper transaction management.

## Why libmdbx over lmdb

- **Auto-resizing database** - No manual size configuration needed
- **Better write performance** - Improved throughput and scalability
- **Data integrity** - Built-in checksums for corruption detection
- **Efficient space reclamation** - Better handling of freed pages
- **Enhanced ACID guarantees** - Stronger consistency guarantees
- **Large database support** - Handle databases up to 128TB
- **Active development** - Regular updates and bug fixes

## Building

### Prerequisites

- Zig 0.15.1 or higher
- libmdbx submodule initialized: `git submodule update --init --recursive`

### Single Target Build

Build for your current platform:

```bash
zig build -Doptimize=ReleaseFast
```

Build for a specific target:

```bash
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseFast
```

### Cross-Compilation for All Targets

The easiest way to build for all supported platforms is using the build script:

```bash
./build_all.sh
```

This script will:
1. Clean previous builds
2. Cross-compile for all 4 target combinations (2 architectures × 2 libc)
3. Output results to `zig-out/lib/`

Alternatively, use the Zig build system directly:

```bash
zig build -Dall=true -Doptimize=ReleaseFast
```

### Supported Targets

The build system supports cross-compilation for the following targets:

| Architecture | libc  | Target Triple          | Output Library              |
|--------------|-------|------------------------|-----------------------------|
| x86_64       | glibc | x86_64-linux-gnu       | liblmdbx-x86_64-gnu.so      |
| x86_64       | musl  | x86_64-linux-musl      | liblmdbx-x86_64-musl.so     |
| ARM64        | glibc | aarch64-linux-gnu      | liblmdbx-aarch64-gnu.so     |
| ARM64        | musl  | aarch64-linux-musl     | liblmdbx-aarch64-musl.so    |

**Note on Cross-Compilation:**
- All targets can be cross-compiled from x86_64 Linux without additional toolchains
- Zig handles the cross-compilation automatically
- The build process includes architecture-specific optimizations
- For x86_64 targets, AVX512 instructions are disabled for better compatibility
- glibc cross-compilation includes workarounds for missing kernel headers

### Build Output

Built libraries are saved in `zig-out/lib/` with names reflecting architecture and libc variant:

```
zig-out/lib/
├── liblmdbx-x86_64-gnu.so      # x86_64 with glibc (1.7 MB)
├── liblmdbx-x86_64-musl.so     # x86_64 with musl (1.6 MB)
├── liblmdbx-aarch64-gnu.so     # ARM64 with glibc (1.7 MB)
└── liblmdbx-aarch64-musl.so    # ARM64 with musl (1.7 MB)
```

The build process automatically:
- Compiles libmdbx as a static library
- Links it into the shared library
- Applies platform-specific compiler flags
- Includes debug symbols (use `strip` to reduce size)

### Optimization Options

- `ReleaseFast` - Maximum performance (recommended for production)
- `ReleaseSmall` - Optimized for size (~30% smaller)
- `ReleaseSafe` - Performance with safety checks
- `Debug` - Full debugging support

## C API Reference

The library exports a complete C API for database operations:

### Database Management
- `open(path, db_ptr)` - Open/create database
- `close(db_ptr)` - Close database and free resources
- `flush(db_ptr)` - Sync changes to disk

### Key-Value Operations
- `put(db_ptr, key, key_len, value, value_len)` - Insert or update
- `get(db_ptr, key, key_len, value_ptr, value_len)` - Retrieve value
- `del(db_ptr, key, key_len)` - Delete entry

### Transaction Management
- `txn_begin(db_ptr)` - Start transaction
- `txn_commit(db_ptr)` - Commit transaction
- `txn_abort(db_ptr)` - Rollback transaction

### Cursor Operations
- `cursor_open(db_ptr, cursor_ptr)` - Create cursor
- `cursor_close(cursor_ptr)` - Close cursor
- `cursor_get(cursor_ptr, ...)` - Navigate and read data

## FFI Examples

The `bun_examples/` directory contains TypeScript examples for Bun runtime:

### Basic Examples
- `test.ts` - Simple put/get/delete operations
- `test-range.ts` - Cursor operations and range queries
- `lmdbx.ts` - TypeScript FFI bindings implementation

### Performance Benchmarks
- `performance-test.ts` - Bulk operations benchmark
- `performance-test-txn.ts` - Transactional write benchmark

### Running Examples

```bash
cd bun_examples
bun test.ts
```

## Usage in Your Project

### Bun Example

```typescript
import { dlopen, FFIType, suffix } from "bun:ffi";

const lib = dlopen(`./zig-out/lib/liblmdbx-x86_64-gnu.${suffix}`, {
  open: { args: [FFIType.cstring, FFIType.ptr], returns: FFIType.i32 },
  put: { args: [FFIType.ptr, FFIType.cstring, FFIType.u32,
                FFIType.cstring, FFIType.u32], returns: FFIType.i32 },
  get: { args: [FFIType.ptr, FFIType.cstring, FFIType.u32,
                FFIType.ptr, FFIType.ptr], returns: FFIType.i32 },
  close: { args: [FFIType.ptr], returns: FFIType.void },
});

// Open database
const dbPtr = new BigUint64Array(1);
lib.symbols.open("./test.db", dbPtr);

// Store data
const key = "hello";
const value = "world";
lib.symbols.put(dbPtr[0], key, key.length, value, value.length);

// Retrieve data
const resultBuf = new Uint8Array(1024);
const resultLen = new Uint32Array(1);
lib.symbols.get(dbPtr[0], key, key.length, resultBuf, resultLen);

// Close database
lib.symbols.close(dbPtr[0]);
```

## Testing

Run the integration tests:

```bash
zig build test
```

This runs both cursor and C API test suites.

## Technical Details

### Build System

The build system uses Zig's cross-compilation capabilities:
- No external toolchains required
- Automatic libc bundling for target platform
- Platform-specific compiler flags applied automatically

### Platform-Specific Optimizations

**x86_64 targets:**
- AVX512 instructions disabled for broader compatibility
- SIMD workaround flag set for cross-compilation
- glibc header workarounds for cachectl.h

**ARM64 targets:**
- NEON optimizations enabled when available
- Position-independent code (PIC) for shared libraries

**All targets:**
- `-fPIC` for shared library compatibility
- `-O3` optimization level
- C11 standard compliance

## License

This wrapper follows libmdbx licensing. See libmdbx repository for details.

## Contributing

Contributions welcome! Please ensure cross-compilation works for all targets before submitting PRs.

## Requirements

- **Zig**: 0.15.1 or higher
- **libmdbx**: Included as submodule in `libs/libmdbx`
- **Platform**: Linux (x86_64 or ARM64)
