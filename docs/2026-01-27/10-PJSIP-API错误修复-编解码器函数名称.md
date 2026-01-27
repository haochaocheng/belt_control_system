# PJSIP API 错误修复 - 编解码器函数名称

**日期**: 2026-01-27
**问题**: 使用了不存在的 PJSIP API 函数导致编译失败

## 问题描述

编译时出现以下错误：

```
SipPhoneManager.cpp:3315:26: error: 'pjsua_codec_enum_info' was not declared in this scope
SipPhoneManager.cpp:3384:26: error: 'pjsua_codec_get_priority' was not declared in this scope
SipPhoneManager.cpp:3459:26: error: 'pjsua_vid_codec_enum_info' was not declared in this scope
SipPhoneManager.cpp:3508:26: error: 'pjsua_vid_codec_get_priority' was not declared in this scope
```

## 根本原因

代码中使用了**不存在的 PJSIP API 函数名称**：

### 错误的函数名（不存在）：
- ❌ `pjsua_codec_enum_info()` - 音频编解码器枚举
- ❌ `pjsua_codec_get_priority()` - 获取音频编解码器优先级
- ❌ `pjsua_vid_codec_enum_info()` - 视频编解码器枚举
- ❌ `pjsua_vid_codec_get_priority()` - 获取视频编解码器优先级

### 正确的函数名（PJSIP 2.16）：
- ✅ `pjsua_enum_codecs()` - 音频编解码器枚举
- ✅ `pjsua_codec_set_priority()` - 设置音频编解码器优先级（**只有 set，没有 get**）
- ✅ `pjsua_vid_enum_codecs()` - 视频编解码器枚举
- ✅ `pjsua_vid_codec_set_priority()` - 设置视频编解码器优先级（**只有 set，没有 get**）

## 修复方案

### 1. 修复音频编解码器枚举（第 3315 行）

**错误代码**：
```cpp
pj_status_t status = pjsua_codec_enum_info(codec_info, &count);
```

**修复后**：
```cpp
pj_status_t status = pjsua_enum_codecs(codec_info, &count);
```

### 2. 修复音频编解码器优先级查询（第 3384 行）

**问题**：PJSIP 没有 `pjsua_codec_get_priority()` 函数

**解决方案**：
- 方案 A：遍历所有编解码器，检查优先级是否 > 0
- 方案 B：维护一个已启用编解码器的列表
- **推荐方案 C**：使用 `pjsua_enum_codecs()` 返回的 `priority` 字段

**修复后**：
```cpp
// ✅ 2026-01-27 [FIX 100.300.47] 使用 pjsua_enum_codecs 获取优先级
pjsua_codec_info codec_info[32];
unsigned count = 32;
pj_status_t status = pjsua_enum_codecs(codec_info, &count);

if (status != PJ_SUCCESS) {
    return false;
}

// 查找匹配的编解码器
for (unsigned i = 0; i < count; ++i) {
    QString codecId = QString::fromUtf8(codec_info[i].codec_id.ptr,
                                       codec_info[i].codec_id.slen);
    if (codecId.contains(codecName, Qt::CaseInsensitive)) {
        // priority > 0 表示启用，priority == 0 表示禁用
        return codec_info[i].priority > 0;
    }
}

return false;
```

### 3. 修复视频编解码器枚举（第 3459 行）

**错误代码**：
```cpp
pj_status_t status = pjsua_vid_codec_enum_info(codec_info, &count);
```

**修复后**：
```cpp
pj_status_t status = pjsua_vid_enum_codecs(codec_info, &count);
```

### 4. 修复视频编解码器优先级查询（第 3508 行）

**修复后**（与音频编解码器相同）：
```cpp
// ✅ 2026-01-27 [FIX 100.300.47] 使用 pjsua_vid_enum_codecs 获取优先级
pjsua_codec_info codec_info[32];
unsigned count = 32;
pj_status_t status = pjsua_vid_enum_codecs(codec_info, &count);

if (status != PJ_SUCCESS) {
    return false;
}

// 查找匹配的编解码器
for (unsigned i = 0; i < count; ++i) {
    QString codecId = QString::fromUtf8(codec_info[i].codec_id.ptr,
                                       codec_info[i].codec_id.slen);
    if (codecId.contains(codecName, Qt::CaseInsensitive)) {
        return codec_info[i].priority > 0;
    }
}

return false;
```

## PJSIP API 参考

### 音频编解码器 API

```c
// 枚举所有音频编解码器
PJ_DECL(pj_status_t) pjsua_enum_codecs(
    pjsua_codec_info id[],  // 输出：编解码器信息数组
    unsigned *count         // 输入/输出：数组大小/实际数量
);

// 设置音频编解码器优先级
PJ_DECL(pj_status_t) pjsua_codec_set_priority(
    const pj_str_t *codec_id,  // 编解码器 ID
    pj_uint8_t priority        // 优先级 (0=禁用, 1-255=启用)
);
```

### 视频编解码器 API

```c
// 枚举所有视频编解码器
PJ_DECL(pj_status_t) pjsua_vid_enum_codecs(
    pjsua_codec_info id[],  // 输出：编解码器信息数组
    unsigned *count         // 输入/输出：数组大小/实际数量
);

// 设置视频编解码器优先级
PJ_DECL(pj_status_t) pjsua_vid_codec_set_priority(
    const pj_str_t *codec_id,  // 编解码器 ID
    pj_uint8_t priority        // 优先级 (0=禁用, 1-255=启用)
);
```

### pjsua_codec_info 结构体

```c
typedef struct pjsua_codec_info
{
    pj_str_t    codec_id;   // 编解码器 ID (例如 "opus/48000/2")
    pj_uint8_t  priority;   // 优先级 (0=禁用, 1-255=启用)
    pj_uint8_t  pt;         // Payload type
    char        buf_[32];   // 内部缓冲区
} pjsua_codec_info;
```

## 技术要点

1. **PJSIP 没有 get_priority 函数**：
   - 只有 `set_priority` 函数
   - 要查询优先级，必须使用 `enum_codecs` 遍历所有编解码器

2. **priority 字段含义**：
   - `priority == 0`：编解码器禁用
   - `priority > 0`：编解码器启用（数值越大优先级越高）

3. **函数命名规则**：
   - 音频编解码器：`pjsua_enum_codecs()` / `pjsua_codec_set_priority()`
   - 视频编解码器：`pjsua_vid_enum_codecs()` / `pjsua_vid_codec_set_priority()`
   - 注意：音频是 `enum_codecs`，视频是 `vid_enum_codecs`

4. **备份文件也有错误**：
   - J:\belt_control_system 备份中的代码也使用了错误的 API
   - 说明这个错误是在之前的开发中引入的
   - 可能从未在实际编译中测试过

## 相关问题

- FIX 100.300.46: 从备份恢复了缺失的函数声明
- FIX 100.300.45: 修复了 SherpaOnnxTTS 编译错误
- FIX 100.252.3: 添加了编解码器列表 Q_PROPERTY

## 状态

⏳ **待修复** - 需要修改 SipPhoneManager.cpp 中的 4 处 API 调用
