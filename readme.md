 
# libmdbx wrapper для Zig

 
```

### 2. Добавьте libmdbx submodule
```bash
git submodule add https://github.com/erthink/libmdbx.git libs/libmdbx
git submodule update --init --recursive
```

### 3. Создайте version.c
```bash
cat > version.c << 'EOF'
#include "libs/libmdbx/src/essentials.h"

const char mdbx_sourcery_anchor[] = "mdbx-zig-build";

const struct MDBX_version_info mdbx_version = {
    1, 0, 0, {0, 0},
    {"", "", "", ""},
    "mdbx-zig-build"
};

__cold const char *mdbx_sourcery_anchor_probe(void) {
    return mdbx_sourcery_anchor;
}
EOF
```
