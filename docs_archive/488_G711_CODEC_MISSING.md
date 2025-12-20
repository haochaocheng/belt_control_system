# 488错误根本原因: G.711编解码器缺失

## 2025-12-05 最新发现

### 问题根源

经过深入分析SIP日志和PJSIP配置，发现**488 Not Acceptable Here**错误的真正原因是:

#### 1. SDP中缺少G.711编解码器 (PCMU/PCMA)

**用户最新测试日志 (13:10:00)**:
```sdp
m=audio 4000 RTP/AVP 96 3 120
a=rtpmap:96 iLBC/8000
a=rtpmap:3 GSM/8000
a=rtpmap:120 telephone-event/8000
```

**问题**: SDP只包含iLBC, GSM和telephone-event,**缺少最标准的G.711编解码器(PCMU/PCMA)**。

FreeSWITCH等大多数SIP服务器**要求**支持G.711 (PCMU/PCMA),因为这是最基本的SIP音频编解码器。

#### 2. PJSIP配置禁用了G.711

检查PJSIP配置发现:

```bash
grep -A 2 "PJMEDIA_HAS_G711_CODEC" /f/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/include/pjmedia/config_auto.h
# 输出:
#ifndef PJMEDIA_HAS_G711_CODEC
#define PJMEDIA_HAS_G711_CODEC 0  # ← 被禁用!
```

**原因**: `config_auto.h`由configure脚本生成,默认将G.711设置为0(禁用)。

### 解决方案

#### 方案1: 在config_site.h中强制启用G.711

**已完成修改**:

文件: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h`

```c
/* Enable basic audio codecs for SIP calling (REQUIRED by PJSUA2) */
#define PJMEDIA_HAS_SPEEX_CODEC         1
#define PJMEDIA_HAS_GSM_CODEC           1
#define PJMEDIA_HAS_ILBC_CODEC          1

/* CRITICAL: Enable G.711 codec (PCMU/PCMA) - standard codec required by most SIP servers
 * This overrides config_auto.h which disables G.711 by default
 */
#define PJMEDIA_HAS_G711_CODEC          1  # ← 已添加 (第43行)

/* Video resolution defaults */
```

**验证修改**:
```bash
grep -n "PJMEDIA_HAS_G711_CODEC" /f/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h
# 输出:
43:#define PJMEDIA_HAS_G711_CODEC          1  ← ✅ 已启用
```

#### 方案2: 重新编译PJSIP (遇到问题!)

**尝试编译**:
```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1
make clean
make dep
make -j8 lib
```

**编译失败**: GCC 15.2.0兼容性问题

**错误日志**:
```
C:/msys64/mingw64/lib/gcc/x86_64-w64-mingw32/15.2.0/include/stdint.h:9:9:
error: expected '=', ',', ';', 'asm' or '__attribute__' before '#pragma'
    9 | #pragma GCC diagnostic push
      |         ^~~
```

**原因**: MSYS2最近更新了GCC到15.2.0版本,PJSIP 2.15.1的代码与新版GCC的`stdint.h`不兼容。

### 当前状态

| 组件 | 状态 | 说明 |
|------|------|------|
| **视频问题** | ✅ **已解决** | SDP不再包含m=video行 |
| **pjsua_call.c:651** | ✅ 已修改 | `opt->flag = 0` (移除INCLUDE_DISABLED_MEDIA) |
| **pjsua_call.c:655** | ✅ 已修改 | `opt->vid_cnt = 0` (禁用默认视频) |
| **config_site.h:43** | ✅ 已修改 | `PJMEDIA_HAS_G711_CODEC = 1` (启用G.711) |
| **PJSIP库** | ❌ **未重新编译** | GCC 15.2.0兼容性问题 |
| **应用程序** | ⏳ 使用旧库 | 不包含G.711编解码器 |
| **488错误** | ❌ **仍存在** | 缺少G.711编解码器 |

### 解决方案选项

#### 选项A: 降级GCC (推荐)

在MSYS2中降级GCC到14.x或13.x版本:

```bash
# 在MSYS2 MINGW64终端中
pacman -U /var/cache/pacman/pkg/mingw-w64-x86_64-gcc-13.*.pkg.tar.zst
# 或从镜像下载GCC 13/14
```

然后重新编译PJSIP:
```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1
make clean
make dep
make -j8 lib
```

#### 选项B: 修复PJSIP代码兼容GCC 15

修改PJSIP源代码以兼容GCC 15.2.0的新stdint.h:

1. 找到触发错误的头文件包含
2. 调整include顺序或添加编译选项
3. 重新编译

#### 选项C: 使用预编译的PJSIP库

从PJSIP官方或第三方获取包含G.711的预编译库。

### 预期修复后的SDP

启用G.711后,SDP应该包含:

```sdp
m=audio 4000 RTP/AVP 0 8 96 3 120
a=rtpmap:0 PCMU/8000      ← G.711 μ-law (最常用)
a=rtpmap:8 PCMA/8000      ← G.711 A-law
a=rtpmap:96 iLBC/8000
a=rtpmap:3 GSM/8000
a=rtpmap:120 telephone-event/8000
```

FreeSWITCH会接受PCMU或PCMA,返回`200 OK`。

### 临时解决方法 (用户可以测试)

如果用户不想等待PJSIP重新编译,可以:

1. **在FreeSWITCH服务器配置中启用iLBC和GSM编解码器**
   - 编辑FreeSWITCH配置
   - 确保支持当前SDP中的编解码器 (iLBC, GSM)

2. **使用其他SIP客户端测试**
   - 使用Linphone, Zoiper等客户端
   - 验证FreeSWITCH是否正常工作

### 技术总结

#### 完整的修复链

1. ✅ 视频从SDP中移除 (pjsua_call.c修改)
2. ✅ G.711编解码器配置启用 (config_site.h修改)
3. ❌ PJSIP库需要重新编译 ← **当前阻塞点**
4. ⏳ 应用程序需要链接新PJSIP库
5. ⏳ 测试验证488错误解决

#### 核心发现

- **问题1 (已解决)**: SDP包含视频流 → pjsua_call.c两处修改
- **问题2 (阻塞)**: SDP缺少G.711 → 需要重新编译PJSIP,但GCC太新
- **根本原因**: configure禁用G.711 + GCC版本升级

### 文件修改清单

| 文件 | 修改内容 | 状态 | 生效 |
|------|----------|------|------|
| `pjsua_call.c:651` | `opt->flag = 0` | ✅ 已修改 | ✅ 已编译到库 |
| `pjsua_call.c:655` | `opt->vid_cnt = 0` | ✅ 已修改 | ✅ 已编译到库 |
| `config_site.h:43` | `PJMEDIA_HAS_G711_CODEC = 1` | ✅ 已修改 | ❌ 未编译到库 |

### 下一步行动

**立即需要**:
1. ✅ **已完成** - 解决GCC兼容性问题 (使用Qt MinGW GCC 11.2.0)
2. ✅ **已完成** - 重新编译PJSIP库(包含G.711)
3. ✅ **已完成** - 复制新库到应用程序 (31个库文件)
4. ✅ **已完成** - 重新编译应用程序 (belt_control_system.exe)
5. ⏳ **等待用户测试验证**

**预期结果**:
- SDP包含PCMU/PCMA
- FreeSWITCH返回200 OK
- 语音通话成功建立

---

**创建时间**: 2025-12-05 13:30
**发现者**: Claude Code (Anthropic)
**完成时间**: 2025-12-05 下午
**状态**: ✅ **所有修复已完成，等待用户测试**
**关键文件**: config_site.h:43, config_auto.h:36, os-auto.mak:66, pjsua_call.c:651,655

## 🎉 修复完成总结

**所有必要的修改和编译工作已完成！** 详细信息请查看：

📄 **[G711_CODEC_FIX_COMPLETED.md](G711_CODEC_FIX_COMPLETED.md)** - 完整的修复报告和测试说明

### 完成的工作

1. ✅ **发现根本原因**: os-auto.mak的AC_NO_G711_CODEC=1导致编译器使用`-DPJMEDIA_HAS_G711_CODEC=0`标志
2. ✅ **三层配置修复**: 修改config_site.h, config_auto.h, 和 os-auto.mak
3. ✅ **PJMEDIA重新编译**: g711.o已成功编译进库
4. ✅ **PJSIP重新编译**: 包含vid_cnt=0视频修复
5. ✅ **应用程序重新编译**: belt_control_system.exe已生成

### 待用户验证

请运行`belt_control_system.exe`并进行测试呼叫，验证：
1. SDP中是否包含 `a=rtpmap:0 PCMU/8000` 和 `a=rtpmap:8 PCMA/8000`
2. FreeSWITCH是否返回 `200 OK` (不再是488)
3. 语音通话是否成功建立
