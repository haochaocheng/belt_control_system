/**
 * FFmpeg Hardware Decoder Shim for PJSIP
 *
 * Problem: PJSIP uses avcodec_find_decoder(AV_CODEC_ID_H264) which returns
 *          the default software decoder "h264" instead of hardware decoders.
 *
 * Solution: Intercept avcodec_find_decoder() and avcodec_find_decoder_by_name()
 *           to return hardware decoders (h264_rkmpp or h264_v4l2m2m) instead.
 *
 * Usage: LD_PRELOAD=/opt/lib/libffmpeg_hwdec_shim.so ./belt_control_system
 *
 * Build: gcc -shared -fPIC -o libffmpeg_hwdec_shim.so ffmpeg_hwdec_shim.c -ldl
 *
 * Note: This shim does NOT include libavcodec headers to avoid build dependencies.
 *       It uses opaque pointers and hardcoded AV_CODEC_ID_H264 value.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Opaque types for FFmpeg structures (we don't need to know their internal structure)
typedef struct AVCodec AVCodec;
typedef struct AVCodecContext AVCodecContext;
typedef struct AVDictionary AVDictionary;

// AVCodecID enum value for H.264 (from libavcodec/codec_id.h)
// This value is stable across FFmpeg versions
#define AV_CODEC_ID_H264 27

// Function pointer types for original FFmpeg functions
typedef const AVCodec* (*avcodec_find_decoder_t)(int codec_id);
typedef const AVCodec* (*avcodec_find_decoder_by_name_t)(const char *name);
typedef int (*avcodec_open2_t)(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options);
typedef const char* (*avcodec_get_name_t)(int id);
typedef const AVCodec* (*av_codec_iterate_t)(void **opaque);

// Global variables to store original function pointers
static avcodec_find_decoder_t original_find_decoder = NULL;
static avcodec_find_decoder_by_name_t original_find_decoder_by_name = NULL;
static avcodec_open2_t original_avcodec_open2 = NULL;
static avcodec_get_name_t original_avcodec_get_name = NULL;
static av_codec_iterate_t original_av_codec_iterate = NULL;

// Flag to enable/disable hardware decoder override
static int hw_decoder_enabled = 1;

// Initialize function pointers (called once)
static void init_original_functions(void) {
    if (!original_find_decoder) {
        original_find_decoder = (avcodec_find_decoder_t)dlsym(RTLD_NEXT, "avcodec_find_decoder");
        if (!original_find_decoder) {
            fprintf(stderr, "[FFmpeg HW Shim] ERROR: Failed to find avcodec_find_decoder: %s\n", dlerror());
            return;
        }
    }

    if (!original_find_decoder_by_name) {
        original_find_decoder_by_name = (avcodec_find_decoder_by_name_t)dlsym(RTLD_NEXT, "avcodec_find_decoder_by_name");
        if (!original_find_decoder_by_name) {
            fprintf(stderr, "[FFmpeg HW Shim] ERROR: Failed to find avcodec_find_decoder_by_name: %s\n", dlerror());
            return;
        }
    }

    if (!original_avcodec_open2) {
        original_avcodec_open2 = (avcodec_open2_t)dlsym(RTLD_NEXT, "avcodec_open2");
        if (!original_avcodec_open2) {
            fprintf(stderr, "[FFmpeg HW Shim] ERROR: Failed to find avcodec_open2: %s\n", dlerror());
            return;
        }
    }

    if (!original_avcodec_get_name) {
        original_avcodec_get_name = (avcodec_get_name_t)dlsym(RTLD_NEXT, "avcodec_get_name");
        if (!original_avcodec_get_name) {
            fprintf(stderr, "[FFmpeg HW Shim] ERROR: Failed to find avcodec_get_name: %s\n", dlerror());
            return;
        }
    }

    if (!original_av_codec_iterate) {
        original_av_codec_iterate = (av_codec_iterate_t)dlsym(RTLD_NEXT, "av_codec_iterate");
        if (!original_av_codec_iterate) {
            fprintf(stderr, "[FFmpeg HW Shim] ERROR: Failed to find av_codec_iterate: %s\n", dlerror());
            return;
        }
    }
}

// Check if environment variable disables hardware decoder
static void check_environment(void) {
    const char *disable = getenv("DISABLE_HW_DECODER");
    if (disable && (strcmp(disable, "1") == 0 || strcmp(disable, "true") == 0)) {
        hw_decoder_enabled = 0;
        fprintf(stderr, "[FFmpeg HW Shim] Hardware decoder disabled by environment variable\n");
    }
}

/**
 * Intercepted avcodec_find_decoder() - Returns hardware decoder for H.264
 */
const AVCodec* avcodec_find_decoder(int codec_id) {
    init_original_functions();
    check_environment();

    // Only intercept H.264 decoder requests
    if (codec_id == AV_CODEC_ID_H264 && hw_decoder_enabled) {
        const AVCodec *hw_decoder = NULL;

        // Try Rockchip MPP decoder first (best performance on RK3588)
        hw_decoder = original_find_decoder_by_name("h264_rkmpp");
        if (hw_decoder) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅ Redirecting H.264 decoder to: h264_rkmpp (Rockchip MPP)\n");
            return hw_decoder;
        }

        // Try V4L2 M2M decoder as fallback
        hw_decoder = original_find_decoder_by_name("h264_v4l2m2m");
        if (hw_decoder) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅ Redirecting H.264 decoder to: h264_v4l2m2m (V4L2 M2M)\n");
            return hw_decoder;
        }

        // If no hardware decoder available, fall back to software
        fprintf(stderr, "[FFmpeg HW Shim] ⚠️ No hardware H.264 decoder found, using software decoder\n");
    }

    // For non-H.264 codecs or if hardware disabled, use original function
    return original_find_decoder(codec_id);
}

/**
 * Intercepted avcodec_find_decoder_by_name() - Redirect h264 to hardware decoder
 *
 * CRITICAL: PJSIP's FFmpeg plugin calls avcodec_find_decoder_by_name("h264")
 * directly, bypassing our avcodec_find_decoder() interception!
 * We must intercept this and redirect to hardware decoder.
 */
const AVCodec* avcodec_find_decoder_by_name(const char *name) {
    init_original_functions();
    check_environment();

    // CRITICAL: Intercept software H.264 decoder requests and redirect to hardware
    if (name && strcmp(name, "h264") == 0 && hw_decoder_enabled) {
        fprintf(stderr, "[FFmpeg HW Shim] 🎯 INTERCEPTED: avcodec_find_decoder_by_name(\"%s\")\n", name);
        fprintf(stderr, "[FFmpeg HW Shim]    → Redirecting to hardware decoder...\n");

        // Try Rockchip MPP decoder first
        const AVCodec *hw_decoder = original_find_decoder_by_name("h264_rkmpp");
        if (hw_decoder) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅✅✅ SUCCESS: Redirected \"h264\" → \"h264_rkmpp\"\n");
            return hw_decoder;
        }

        // Try V4L2 M2M decoder as fallback
        hw_decoder = original_find_decoder_by_name("h264_v4l2m2m");
        if (hw_decoder) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅✅ SUCCESS: Redirected \"h264\" → \"h264_v4l2m2m\"\n");
            return hw_decoder;
        }

        fprintf(stderr, "[FFmpeg HW Shim] ⚠️ WARNING: No hardware decoder available, using software\n");
    }

    const AVCodec *decoder = original_find_decoder_by_name(name);

    // Log all H.264 decoder lookups
    if (decoder && name && strstr(name, "h264")) {
        if (strstr(name, "rkmpp") || strstr(name, "v4l2m2m")) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅ Found hardware decoder: %s\n", name);
        } else if (strcmp(name, "h264") == 0) {
            fprintf(stderr, "[FFmpeg HW Shim] ⚠️ WARNING: Software decoder \"%s\" requested (shim bypassed?)\n", name);
        }
    }

    return decoder;
}

/**
 * Intercepted avcodec_open2() - CRITICAL: Force hardware decoder override
 *
 * ULTIMATE FIX: Even if PJSIP cached the software decoder pointer,
 * we intercept avcodec_open2() and forcibly redirect to hardware decoder.
 */
int avcodec_open2(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options) {
    init_original_functions();

    // Get codec name if possible (codec pointer might be NULL for encoder contexts)
    const char *codec_name = "unknown";
    if (codec) {
        // Try to get codec name from the codec structure
        // We use a pointer offset hack since we don't have the full AVCodec structure
        // In AVCodec structure, the name field is typically at offset 0 (first field)
        const char **name_ptr = (const char **)codec;
        if (name_ptr && *name_ptr) {
            codec_name = *name_ptr;
        }
    }

    // 🚨 CRITICAL FIX: If trying to open software h264 decoder, forcibly redirect to hardware!
    if (codec && codec_name && strcmp(codec_name, "h264") == 0 && hw_decoder_enabled) {
        fprintf(stderr, "[FFmpeg HW Shim] 🚨🚨 CRITICAL INTERCEPT: Blocking software h264 decoder open!\n");
        fprintf(stderr, "[FFmpeg HW Shim]    → Forcibly redirecting to hardware decoder...\n");

        // Try to get hardware decoder
        const AVCodec *hw_decoder = original_find_decoder_by_name("h264_rkmpp");
        if (!hw_decoder) {
            hw_decoder = original_find_decoder_by_name("h264_v4l2m2m");
        }

        if (hw_decoder) {
            codec = hw_decoder;
            // Update codec_name for logging
            const char **hw_name_ptr = (const char **)hw_decoder;
            if (hw_name_ptr && *hw_name_ptr) {
                codec_name = *hw_name_ptr;
            }
            fprintf(stderr, "[FFmpeg HW Shim] ✅✅ Redirected to: %s\n", codec_name);
        } else {
            fprintf(stderr, "[FFmpeg HW Shim] ⚠️ WARNING: No hardware decoder found, proceeding with software\n");
        }
    }

    // Log ALL h264 decoder open attempts (before calling original function)
    if (strstr(codec_name, "h264")) {
        fprintf(stderr, "[FFmpeg HW Shim] 🔧 Attempting to open decoder: %s\n", codec_name);
    }

    // Call original avcodec_open2 (with potentially substituted codec)
    int result = original_avcodec_open2(avctx, codec, options);

    // Log the result
    if (result == 0) {
        // Success
        if (strstr(codec_name, "h264")) {
            if (strstr(codec_name, "rkmpp")) {
                fprintf(stderr, "[FFmpeg HW Shim] ✅✅✅ SUCCESS: h264_rkmpp decoder initialized (HARDWARE)\n");
                fprintf(stderr, "[FFmpeg HW Shim]    Expect LOW CPU usage during video decoding\n");
            } else if (strstr(codec_name, "v4l2m2m")) {
                fprintf(stderr, "[FFmpeg HW Shim] ✅✅ SUCCESS: h264_v4l2m2m decoder initialized (HARDWARE)\n");
                fprintf(stderr, "[FFmpeg HW Shim]    Expect LOW CPU usage during video decoding\n");
            } else {
                fprintf(stderr, "[FFmpeg HW Shim] ⚠️⚠️⚠️ WARNING: %s decoder initialized (SOFTWARE)\n", codec_name);
                fprintf(stderr, "[FFmpeg HW Shim]    Expect HIGH CPU usage during video decoding\n");
            }
        }
    } else {
        // Failure
        if (strstr(codec_name, "h264")) {
            if (strstr(codec_name, "rkmpp") || strstr(codec_name, "v4l2m2m")) {
                fprintf(stderr, "[FFmpeg HW Shim] ❌❌❌ FAILURE: %s decoder initialization FAILED (error %d)\n", codec_name, result);
                fprintf(stderr, "[FFmpeg HW Shim]    PJSIP will likely fall back to SOFTWARE decoding\n");
                fprintf(stderr, "[FFmpeg HW Shim]    Check /dev/mpp_service permissions and librockchip_mpp.so.1\n");
            } else {
                fprintf(stderr, "[FFmpeg HW Shim] ❌ FAILURE: %s decoder initialization FAILED (error %d)\n", codec_name, result);
            }
        }
    }

    return result;
}

/**
 * Intercepted av_codec_iterate() - Skip software H.264 decoder during enumeration
 *
 * CRITICAL: PJSIP's FFmpeg plugin calls av_codec_iterate() during initialization
 * to enumerate all codecs and cache them in a static array. During video calls,
 * PJSIP directly uses the cached pointer (first h264 decoder = software "h264").
 *
 * Our previous interception of avcodec_find_decoder() is completely bypassed!
 *
 * Solution: Intercept av_codec_iterate() and skip the software h264 decoder
 * so that PJSIP's cache will contain hardware decoders (h264_rkmpp/h264_v4l2m2m)
 * instead of the software decoder.
 */
const AVCodec* av_codec_iterate(void **opaque) {
    init_original_functions();
    check_environment();

    // Get next codec from FFmpeg
    const AVCodec *codec = original_av_codec_iterate(opaque);

    // If hardware decoding is disabled, return all codecs normally
    if (!hw_decoder_enabled) {
        return codec;
    }

    // Loop until we find a codec that's not the software h264 decoder
    while (codec) {
        // Try to get codec name (first field in AVCodec structure)
        const char *codec_name = "unknown";
        const char **name_ptr = (const char **)codec;
        if (name_ptr && *name_ptr) {
            codec_name = *name_ptr;
        }

        // Check if this is the software h264 decoder
        if (strcmp(codec_name, "h264") == 0) {
            // ✅ CRITICAL: Skip the software h264 decoder during enumeration!
            // This prevents PJSIP from caching it
            fprintf(stderr, "[FFmpeg HW Shim] 🚫 SKIPPING software h264 decoder during enumeration\n");
            fprintf(stderr, "[FFmpeg HW Shim]    PJSIP will cache hardware decoders instead\n");

            // Get next codec
            codec = original_av_codec_iterate(opaque);
            continue;  // Check next codec
        }

        // Log hardware h264 decoders we're allowing through
        if (strstr(codec_name, "h264_rkmpp") || strstr(codec_name, "h264_v4l2m2m")) {
            fprintf(stderr, "[FFmpeg HW Shim] ✅ Allowing hardware decoder: %s\n", codec_name);
        }

        // Return this codec (it's not the software h264 decoder)
        return codec;
    }

    // No more codecs
    return NULL;
}

// Constructor - runs when library is loaded
__attribute__((constructor))
static void ffmpeg_hwdec_shim_init(void) {
    fprintf(stderr, "\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "FFmpeg Hardware Decoder Shim LOADED\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "Version: 1.0\n");
    fprintf(stderr, "Target: H.264 hardware decoding for PJSIP\n");
    fprintf(stderr, "Decoders: h264_rkmpp (priority 1), h264_v4l2m2m (priority 2)\n");
    fprintf(stderr, "Disable: Set DISABLE_HW_DECODER=1 to bypass\n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "\n");
}
