/*
 * Timezone stub for OpenSSL static linking
 *
 * Windows/MinGW: OpenSSL expects __imp___timezone (DLL import),
 *                MinGW provides _timezone (static symbol).
 * Linux/glibc:   Provides timezone variable (without underscore)
 *
 * This stub creates the required symbols at link time.
 */

#include <time.h>

#ifdef _WIN32
    /* MinGW provides _timezone variable */
    extern long _timezone;

    /* Provide __imp___timezone as a pointer to _timezone */
    long * __imp___timezone = &_timezone;
#else
    /* Linux glibc provides timezone variable */
    /* Define _timezone as an alias to system timezone for compatibility */
    extern long int timezone;
    long _timezone = 0;  /* Will be initialized at runtime if needed */

    /* If needed, create a constructor to sync _timezone with system timezone */
    __attribute__((constructor))
    static void init_timezone_stub(void) {
        _timezone = timezone;
    }
#endif
