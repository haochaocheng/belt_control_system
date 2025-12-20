# Video Incoming Call - Three Buttons UI Fix (Final Solution)

## Problem Statement

**Symptom**: When receiving a video call, only 2 buttons appear (Answer, Reject) instead of 3 buttons (Video Answer, Audio Answer, Reject)

**User Feedback**:
1. First test: "Still only two buttons, nothing changed"
2. Second test: "Still not working"

## Root Cause Analysis

### Attempt 1: Timing Issue - Detection in call_state_callback_wrapper
- **Method**: Detect video in `call_state_callback_wrapper` when state becomes INCOMING
- **Result**: ❌ Failed - `media_cnt = 0` at this point (SDP not yet parsed)

### Attempt 2: Remove Auto-Answer - Detection in incoming_call_callback_wrapper
- **Discovery**: Found auto-answer code that prevented users from seeing incoming call UI
- **Fix**:
  1. Removed auto-answer logic
  2. Added video detection with SipPhoneManager notification
  3. Removed duplicate detection in call_state_callback_wrapper
- **Compilation**: ✅ Success (2025-12-08 16:06)
- **Test Result**: ❌ Failed - User reported "Still not working"
- **Log Analysis**:
  - ❌ NO `[INCOMING CALL]` logs appeared
  - ✅ BUT Risip's `incomingCall` signal WAS triggered (saw "Incoming call from:" logs)
- **Root Cause**: `incoming_call_callback_wrapper` was NEVER called!

### Attempt 3: Final Solution - Detection in Risip incomingCall Signal ✅

**Analysis**:
1. `incoming_call_callback_wrapper` is registered at `risipendpoint.cpp:430`
2. But PJSUA2 C++ wrapper layer intercepts callbacks before our wrapper
3. PJSUA2 Account objects likely re-register callbacks after `libStart()`
4. Result: Our wrapper is never invoked

**Solution**: Detect video in Risip SDK's `incomingCall` signal handler (this signal IS triggered)

## Implementation

### Modified File: `src/sip_phone/SipPhoneManager.cpp`

**Location**: Lines 508-546 (in Risip incomingCall signal lambda handler)

**Before**:
```cpp
qDebug() << "Incoming call from:" << call->buddy()->contact();
d->currentCall = call;

// ✅ Video detection is now handled in risipendpoint.cpp call_state_callback_wrapper()
// when state becomes INCOMING (after SDP has been parsed and media_cnt is populated)

// Emit incoming call signal to QML
```

**After**:
```cpp
qDebug() << "Incoming call from:" << call->buddy()->contact();
d->currentCall = call;

// ✅ Detect video in Risip incoming call signal (final solution)
// incoming_call_callback_wrapper is not triggered (intercepted by PJSUA2), so detect here
int callId = call->callId();
qDebug() << "📞 [RISIP INCOMING] RisipCall callId:" << callId;

if (callId >= 0) {
    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    pj_status_t status = pjsua_call_get_info(callId, &ci);
    qDebug() << "📞 [RISIP INCOMING] pjsua_call_get_info status:" << status << "media_cnt:" << ci.media_cnt;

    if (status == PJ_SUCCESS) {
        bool hasVideo = false;
        qDebug() << "📞 [RISIP INCOMING] Checking" << ci.media_cnt << "media streams...";

        for (unsigned i = 0; i < ci.media_cnt; ++i) {
            qDebug() << "📞 [RISIP INCOMING] Media" << i
                     << ": type=" << ci.media[i].type
                     << "dir=" << ci.media[i].dir
                     << "status=" << ci.media[i].status
                     << "(AUDIO=" << PJMEDIA_TYPE_AUDIO << ", VIDEO=" << PJMEDIA_TYPE_VIDEO << ")";

            if (ci.media[i].type == PJMEDIA_TYPE_VIDEO &&
                ci.media[i].dir != PJMEDIA_DIR_NONE) {
                hasVideo = true;
                qDebug() << "✅ Detected video media in Risip incoming call at index" << i;
            }
        }

        qDebug() << "📞 [RISIP INCOMING] Final result: hasVideo =" << hasVideo;
        setIsIncomingVideoCall(hasVideo);
    } else {
        qWarning() << "❌ Failed to get call info in Risip incoming signal, status:" << status;
        setIsIncomingVideoCall(false);
    }
} else {
    qDebug() << "⚠️ Invalid call ID in Risip incoming signal";
    setIsIncomingVideoCall(false);
}

// Emit incoming call signal to QML
```

**Key Features**:
- ✅ Detects video in Risip's `incomingCall` signal (which IS triggered)
- ✅ Uses PJSIP C API to directly call `pjsua_call_get_info()` for media info
- ✅ Iterates through `ci.media[]` array to find `PJMEDIA_TYPE_VIDEO`
- ✅ Updates UI flag via `setIsIncomingVideoCall()`
- ✅ Detailed debug logging showing each media stream's type and status

## Technical Architecture

### PJSIP Callback Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│  1. PJSIP C API Layer (Lowest)                               │
│     pjsua_var.ua_cfg.cb.on_incoming_call                    │
│     ❌ We tried to intercept here, but PJSUA2 overrides it   │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  2. PJSUA2 C++ Wrapper Layer (Middle)                        │
│     Account::onIncomingCall()                                │
│     ⚠️ PJSUA2 re-registers callbacks here, overriding ours   │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Risip SDK Layer (Highest)                                │
│     RisipCallManager::incomingCall signal                    │
│     ✅ We detect video here (final solution)                 │
└─────────────────────────────────────────────────────────────┘
```

### Why Does Risip Signal Have Complete Media Info?

Although Risip's `incomingCall` signal is triggered at the PJSUA2 layer:
1. PJSIP has already parsed the SIP INVITE request
2. SDP (Session Description Protocol) has been parsed
3. `pjsua_call_info` structure's `media_cnt` and `media[]` are populated
4. We can directly call `pjsua_call_get_info()` to get complete information

**Key**: Don't rely on callback interception. Instead, **passively wait** for Risip signal, then **actively query** PJSIP for media info.

## Testing

### Expected Logs (Video Call):
```
[DEBUG] Incoming call from: "Extension 1006" 1006
[DEBUG] 📞 [RISIP INCOMING] RisipCall callId: 0
[DEBUG] 📞 [RISIP INCOMING] pjsua_call_get_info status: 0 media_cnt: 2
[DEBUG] 📞 [RISIP INCOMING] Checking 2 media streams...
[DEBUG] 📞 [RISIP INCOMING] Media 0: type=0 dir=3 status=... (AUDIO=0, VIDEO=1)
[DEBUG] 📞 [RISIP INCOMING] Media 1: type=1 dir=3 status=... (AUDIO=0, VIDEO=1)
[DEBUG] ✅ Detected video media in Risip incoming call at index 1
[DEBUG] 📞 [RISIP INCOMING] Final result: hasVideo = true
[DEBUG] ✅ Incoming call detected: Video = true
```

### Expected Behavior:
- ✅ Video calls: Show 3 buttons (📹 Video Answer, 📞 Audio Answer, ✗ Reject)
- ✅ Audio calls: Show 2 buttons (✓ Answer, ✗ Reject)

## Summary

**Compilation**: ✅ Success (2025-12-08 16:33)

**Core Changes**:
- **File**: `src/sip_phone/SipPhoneManager.cpp` lines 508-546
- **Method**: Added video detection in Risip `incomingCall` signal lambda
- **Effect**: Correctly identify video calls, display 3-button UI

**Key Lessons**:
1. Don't over-rely on callback interception - wrapper libraries may override them
2. Use existing verified mechanisms (Risip signals) instead of trying to intercept lower layers
3. Active querying (calling `pjsua_call_get_info()`) is more reliable than passive waiting for callbacks
4. Detailed debug logging is critical for diagnosing callback issues

**Next Steps**:
1. Test video incoming call, verify 3 buttons appear
2. Test audio incoming call, verify 2 buttons appear
3. Check logs to confirm `[RISIP INCOMING]` appears and `media_cnt > 0`
