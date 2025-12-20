/* Fix for math macro compatibility issues between different GLIBC versions */
/* This header resolves __MATHDECL_ALIAS macro definition missing in some environments */

#ifndef FIX_MATH_MACROS_H
#define FIX_MATH_MACROS_H

/* Define __MATHDECL_ALIAS if not already defined */
#ifndef __MATHDECL_ALIAS
#define __MATHDECL_ALIAS(type, function, suffix, alias_function, alias_suffix)   __MATHDECL(type, function, suffix)
#endif

/* Define __MATHDECL_1_ALIAS if not already defined */
#ifndef __MATHDECL_1_ALIAS
#define __MATHDECL_1_ALIAS(type, function, suffix, alias_function, alias_suffix)   __MATHDECL_1(type, function, suffix)
#endif

/* Define __MATH_PRECNAME if not already defined */
#ifndef __MATH_PRECNAME
#define __MATH_PRECNAME(name) name##f
#endif

/* Ensure __MATHDECL is defined (fallback) */
#ifndef __MATHDECL
#define __MATHDECL(type, function, suffix)   extern type function suffix
#endif

/* Ensure __MATHDECL_1 is defined (fallback) */
#ifndef __MATHDECL_1
#define __MATHDECL_1(type, function, suffix)   extern type function suffix
#endif

#endif /* FIX_MATH_MACROS_H */
