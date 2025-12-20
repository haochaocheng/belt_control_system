/* Compatibility header for missing macros
 * This file defines macros that may be missing in older glibc versions
 * to ensure compatibility when cross-compiling
 */

#ifndef _FIX_GLIBC_COMPAT_H
#define _FIX_GLIBC_COMPAT_H

/* __COLD attribute - marks functions as cold (rarely executed)
 * Define as __attribute__((__cold__)) if not already defined
 */
#ifndef __COLD
#define __COLD __attribute__((__cold__))
#endif

#endif /* _FIX_GLIBC_COMPAT_H */
