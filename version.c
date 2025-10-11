/* This is CMake-template for libmdbx's version.c
 ******************************************************************************/

#include "internals.h"

#if !defined(MDBX_VERSION_UNSTABLE) &&                                                                                 \
    (MDBX_VERSION_MAJOR != 0 || MDBX_VERSION_MINOR != 14)
#error "API version mismatch! Had `git fetch --tags` done?"
#endif

static const char sourcery[] =
#ifdef MDBX_VERSION_UNSTABLE
    "UNSTABLE@"
#endif
    MDBX_STRINGIFY(MDBX_BUILD_SOURCERY);

__dll_export
#ifdef __attribute_used__
    __attribute_used__
#elif defined(__GNUC__) || __has_attribute(__used__)
    __attribute__((__used__))
#endif
#ifdef __attribute_externally_visible__
        __attribute_externally_visible__
#elif (defined(__GNUC__) && !defined(__clang__)) || __has_attribute(__externally_visible__)
    __attribute__((__externally_visible__))
#endif
    const struct MDBX_version_info mdbx_version = {
        0,
        14,
        1,
        95,
        "", /* pre-release suffix of SemVer
                                        0.14.1.95 */
        {"2025-09-18T09:21:46+03:00", "2c4205d50730b9d43090da71b465e9bb126b631c", "924581bdc8a1e217139c1d286c1ffb0ef0f9d14d", "v0.14.1-95-g924581bd"},
        sourcery};

__dll_export
#ifdef __attribute_used__
    __attribute_used__
#elif defined(__GNUC__) || __has_attribute(__used__)
    __attribute__((__used__))
#endif
#ifdef __attribute_externally_visible__
        __attribute_externally_visible__
#elif (defined(__GNUC__) && !defined(__clang__)) || __has_attribute(__externally_visible__)
    __attribute__((__externally_visible__))
#endif
    const char *const mdbx_sourcery_anchor = sourcery;
