/**
 * PJSIP Video Device Subsystem Stubs
 *
 * This file provides stub implementations for PJSIP video device functions
 * when video support is disabled during PJSIP compilation.
 */

/* Stub implementation for pjmedia_vid_dev_subsys_init */
int pjmedia_vid_dev_subsys_init(void* pf)
{
    /* No-op when video is disabled */
    (void)pf;  /* Suppress unused parameter warning */
    return 0;  /* PJ_SUCCESS = 0 */
}

/* Stub implementation for pjmedia_vid_dev_subsys_shutdown */
int pjmedia_vid_dev_subsys_shutdown(void)
{
    /* No-op when video is disabled */
    return 0;  /* PJ_SUCCESS = 0 */
}
