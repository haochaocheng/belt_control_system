/**
 * PJSIP Video Device Subsystem Stubs
 *
 * This file provides stub implementations for PJSIP video device functions
 * when video support is disabled during PJSIP compilation.
 *
 * The functions return PJ_SUCCESS (0) to indicate they're no-ops.
 */

#include <pj/types.h>
#include <pj/errno.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Stub implementation for pjmedia_vid_dev_subsys_init */
PJ_DEF(pj_status_t) pjmedia_vid_dev_subsys_init(void* pf)
{
    /* No-op when video is disabled */
    PJ_UNUSED_ARG(pf);
    return PJ_SUCCESS;
}

/* Stub implementation for pjmedia_vid_dev_subsys_shutdown */
PJ_DEF(pj_status_t) pjmedia_vid_dev_subsys_shutdown(void)
{
    /* No-op when video is disabled */
    return PJ_SUCCESS;
}

#ifdef __cplusplus
}
#endif
