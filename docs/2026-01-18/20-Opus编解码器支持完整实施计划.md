# Opus 编解码器支持 - 完整实施计划

**日期**: 2026-01-18 23:30
**目标**: 在项目中添加 Opus 编解码器支持，实现三编解码器共存（PCMA + PCMU + Opus）
**状态**: 📋 规划中

---

## 🎯 总体目标

### 核心需求
1. **编译 Opus 库**：在容器中交叉编译 Opus 静态库（aarch64）
2. **PJSIP 集成 Opus**：重新编译 PJSIP，启用 Opus 支持
3. **应用程序配置**：在代码中配置 Opus 编解码器
4. **UI 扩展**：在 SIP 设置界面添加音频编码器选择

### 最终效果
- ✅ PCMA/8000 Hz（优先级 215）
- ✅ PCMU/8000 Hz（优先级 214）
- ✅ Opus/16000 Hz（优先级 213）⭐ 新增
- ✅ 用户可在设置界面选择优先使用哪种编码器

---

## 📋 工作分解（按顺序执行）

### Phase 1: Opus 库编译（当前阶段）

#### 1.1 下载 Opus 源码
**目标**: 下载最新稳定版 Opus 源码

**执行**:
```powershell
# 位置：cross-compile/src/opus-1.5.2/
# 下载地址：https://github.com/xiph/opus/releases
# 或：https://opus-codec.org/downloads/
```

**预期结果**:
- 源码路径：`cross-compile/src/opus-1.5.2/`
- 与 `pjproject-2.16/` 和 `FFmpeg-master/` 同级

#### 1.2 创建 Opus 编译脚本
**目标**: 创建容器编译脚本，生成 aarch64 静态库

**脚本路径**: `scripts/2026-01-18/compile-opus-in-container.ps1`

**编译参数**:
```bash
# 容器内执行
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/opt/opus \
    --disable-shared \
    --enable-static \
    --enable-float-approx \
    --disable-doc \
    --disable-extra-programs

make -j8
make install
```

**输出产物**:
- 静态库：`/opt/opus/lib/libopus.a`
- 头文件：`/opt/opus/include/opus/*.h`
- 复制到：`docker/rk3588/rk3588-libs/lib/libopus.a`
- 复制到：`docker/rk3588/rk3588-libs/include/opus/*.h`

**预期时间**: 5-10 分钟

---

### Phase 2: PJSIP 重新编译支持 Opus

#### 2.1 查看 PJSIP Opus 配置选项
**目标**: 了解如何启用 PJSIP 的 Opus 支持

**参考文档**:
- PJSIP 官方文档：`pjproject-2.16/pjmedia/include/pjmedia-codec/opus.h`
- 配置文件：`docker/rk3588/pjsip_config_site.h`

**关键配置宏**:
```c
// 启用 Opus 编解码器
#define PJMEDIA_HAS_OPUS_CODEC 1

// Opus 库路径（可能需要）
// 通过 configure 参数指定，不在 config_site.h
```

#### 2.2 修改 PJSIP 配置文件
**文件**: `docker/rk3588/pjsip_config_site.h`

**添加内容**:
```c
// ========================================
// ✅ 2026-01-18 23:30 启用 Opus 编解码器支持
// ========================================
#define PJMEDIA_HAS_OPUS_CODEC 1  // 启用 Opus

// Opus 默认配置（可选）
// #define PJMEDIA_CODEC_OPUS_DEFAULT_SAMPLE_RATE 16000
// #define PJMEDIA_CODEC_OPUS_DEFAULT_CHANNEL_CNT 1
// #define PJMEDIA_CODEC_OPUS_DEFAULT_BIT_RATE 16000
```

#### 2.3 修改 PJSIP 编译脚本
**文件**: `scripts/2025-12-27/compile-pjsip-in-container.ps1`（或创建新版本）

**关键修改**: 添加 `--with-opus` 参数

**configure 命令**:
```bash
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/opt/pjproject \
    --disable-shared \
    --enable-static \
    --with-opus=/opt/opus \  # ⭐ 新增：指定 Opus 库路径
    --disable-video \
    --disable-libwebrtc \
    # ... 其他参数保持不变
```

#### 2.4 重新编译 PJSIP
**执行**:
```powershell
# 用户启动脚本
.\scripts\2026-01-18\compile-pjsip-with-opus.ps1
```

**预期结果**:
- PJSIP 静态库包含 Opus 支持
- 库文件：`docker/rk3588/rk3588-libs/lib/libpjmedia-codec-*.a`（更新）
- 确认 Opus 支持：查看编译日志

**预期时间**: 15-30 分钟

---

### Phase 3: 应用程序配置 Opus

#### 3.1 验证 Opus 编解码器可用性
**文件**: `src/risip/core/risipendpoint.cpp`

**添加调试日志**（Line ~770）:
```cpp
// ✅ 2026-01-18 23:30 验证 Opus 编解码器是否可用
qDebug() << "🔍 [CODEC] Checking Opus availability...";

try {
    CodecInfoVector codecs = Endpoint::instance().codecEnum();
    bool opusFound = false;

    for (unsigned i = 0; i < codecs.size(); i++) {
        QString codecId = QString::fromStdString(codecs[i].codecId);
        if (codecId.contains("opus", Qt::CaseInsensitive)) {
            qDebug() << "  ✅ Found Opus codec:" << codecId;
            opusFound = true;
        }
    }

    if (!opusFound) {
        qDebug() << "  ❌ Opus codec NOT found!";
        qDebug() << "     PJSIP may not be compiled with Opus support";
    }
} catch (Error &err) {
    qDebug() << "Warning: Could not enumerate codecs:" << QString::fromStdString(err.reason);
}
```

#### 3.2 配置 Opus 编解码器
**文件**: `src/risip/core/risipendpoint.cpp`（基于 FIX 100.247.3 的位置）

**参考已有文档**: `docs/2026-01-18/15-Opus16kHz配置方案.md`

**配置内容**（Line 766-850）:
```cpp
// ✅ 2026-01-18 23:30 配置 Opus 16kHz（宽带音频）
try {
    // Step 1: 禁用默认的 Opus 48kHz
    Endpoint::instance().codecSetPriority("opus/48000/2", 0);

    // Step 2: 获取当前 Opus 配置
    CodecOpusConfig opus_cfg = Endpoint::instance().codecGetOpusConfig();

    // Step 3: 修改为 16kHz 配置
    opus_cfg.sample_rate = 16000;     // 16kHz（与 PJSIP 内部匹配）
    opus_cfg.channel_cnt = 1;         // 单声道
    opus_cfg.bit_rate = 16000;        // 16 kbps
    opus_cfg.complexity = 10;         // 最高质量
    opus_cfg.cbr = false;             // VBR 模式
    opus_cfg.packet_loss = 10;        // 预期 10% 丢包
    opus_cfg.frm_ptime = 20;          // 20ms 帧

    // Step 4: 应用配置
    Endpoint::instance().codecSetOpusConfig(opus_cfg);
    qDebug() << "  ✅ Opus/16000 configured successfully";

    // Step 5: 设置优先级
    Endpoint::instance().codecSetPriority("opus/16000/1", 213);
    qDebug() << "  ✅ opus/16000/1 enabled (priority: 213)";

} catch (Error &err) {
    qDebug() << "Warning: Could not configure Opus:" << QString::fromStdString(err.reason);
}
```

#### 3.3 测试验证
**执行**:
```powershell
.\build-ubuntu24-apt.ps1 188
```

**验证日志**:
```
🎵 [CODEC] Configuring audio codecs...
  ✅ PCMA/8000 enabled (priority: 215)
  ✅ PCMU/8000 enabled (priority: 214)
  🔍 [CODEC] Checking Opus availability...
    ✅ Found Opus codec: opus/48000/2
  ⛔ opus/48000/2 disabled
  ✅ Opus/16000 configured successfully
  ✅ opus/16000/1 enabled (priority: 213)
```

**通话测试**:
- 拨打支持 Opus 的 SIP 客户端
- 查看 SDP 协商日志
- 确认使用 Opus 编解码器

---

### Phase 4: SIP 设置界面扩展

#### 4.1 数据模型扩展
**文件**: `src/sip_phone/SipPhoneManager.h`

**添加枚举**:
```cpp
// ✅ 2026-01-18 23:30 音频编解码器选择
enum class AudioCodec {
    PCMA,   // G.711 A-law (8000 Hz)
    PCMU,   // G.711 μ-law (8000 Hz)
    Opus    // Opus (16000 Hz)
};
Q_ENUM(AudioCodec)
```

**添加属性和信号**:
```cpp
// 音频编解码器优先选择
Q_PROPERTY(AudioCodec preferredCodec READ preferredCodec WRITE setPreferredCodec NOTIFY preferredCodecChanged)

AudioCodec preferredCodec() const;
void setPreferredCodec(AudioCodec codec);

signals:
    void preferredCodecChanged(AudioCodec codec);
```

#### 4.2 实现编解码器切换
**文件**: `src/sip_phone/SipPhoneManager.cpp`

**实现方法**:
```cpp
void SipPhoneManager::setPreferredCodec(AudioCodec codec) {
    if (m_preferredCodec == codec) return;
    m_preferredCodec = codec;

    // 根据选择调整编解码器优先级
    switch (codec) {
    case AudioCodec::PCMA:
        Endpoint::instance().codecSetPriority("PCMA/8000", 230);
        Endpoint::instance().codecSetPriority("PCMU/8000", 214);
        Endpoint::instance().codecSetPriority("opus/16000/1", 213);
        break;
    case AudioCodec::PCMU:
        Endpoint::instance().codecSetPriority("PCMU/8000", 230);
        Endpoint::instance().codecSetPriority("PCMA/8000", 214);
        Endpoint::instance().codecSetPriority("opus/16000/1", 213);
        break;
    case AudioCodec::Opus:
        Endpoint::instance().codecSetPriority("opus/16000/1", 230);
        Endpoint::instance().codecSetPriority("PCMA/8000", 214);
        Endpoint::instance().codecSetPriority("PCMU/8000", 213);
        break;
    }

    qDebug() << "✅ [CODEC] Preferred codec changed to:" << codec;
    emit preferredCodecChanged(codec);
}
```

#### 4.3 QML 界面修改
**文件**: `src/qml/components/sip_phone/pages/SipSettingsPage.qml`

**添加编解码器选择**:
```qml
// ✅ 2026-01-18 23:30 音频编解码器选择
ColumnLayout {
    Label {
        text: "音频编解码器"
        font.pixelSize: 14
        font.bold: true
    }

    ComboBox {
        id: codecComboBox
        model: ["PCMA (G.711 A-law)", "PCMU (G.711 μ-law)", "Opus (宽带音频)"]
        currentIndex: {
            switch(SipPhoneManager.preferredCodec) {
            case SipPhoneManager.PCMA: return 0;
            case SipPhoneManager.PCMU: return 1;
            case SipPhoneManager.Opus: return 2;
            default: return 0;
            }
        }
        onCurrentIndexChanged: {
            switch(currentIndex) {
            case 0: SipPhoneManager.preferredCodec = SipPhoneManager.PCMA; break;
            case 1: SipPhoneManager.preferredCodec = SipPhoneManager.PCMU; break;
            case 2: SipPhoneManager.preferredCodec = SipPhoneManager.Opus; break;
            }
        }
    }

    Label {
        text: "PCMA/PCMU: 通用兼容 | Opus: 高音质低带宽"
        font.pixelSize: 10
        color: "#666666"
    }
}
```

#### 4.4 配置持久化
**文件**: `src/sip_phone/SipPhoneManager.cpp`

**保存到设置**:
```cpp
void SipPhoneManager::setPreferredCodec(AudioCodec codec) {
    // ... 上面的代码 ...

    // 保存到配置文件
    QSettings settings;
    settings.setValue("sip/preferredCodec", static_cast<int>(codec));
}

// 启动时加载
void SipPhoneManager::loadSettings() {
    QSettings settings;
    int codecInt = settings.value("sip/preferredCodec", 0).toInt();
    setPreferredCodec(static_cast<AudioCodec>(codecInt));
}
```

---

## 🔧 脚本清单

### 需要创建的脚本

1. **`scripts/2026-01-18/compile-opus-in-container.ps1`** ⭐ 优先
   - 在容器中编译 Opus 库
   - 输出：`docker/rk3588/rk3588-libs/lib/libopus.a`

2. **`scripts/2026-01-18/compile-pjsip-with-opus.ps1`**
   - 基于现有脚本修改
   - 添加 `--with-opus=/opt/opus` 参数

3. **`scripts/2026-01-18/download-opus-source.ps1`**（可选）
   - 自动下载 Opus 源码到正确位置

### 脚本命名规则
- 如果脚本不可用，标注文件名：`compile-opus-in-container-UNUSABLE-v1.ps1`
- 最新可用版本不加后缀

---

## 📊 预期时间线

| 阶段 | 任务 | 预计时间 | 累计时间 |
|------|------|----------|----------|
| Phase 1.1 | 下载 Opus 源码 | 5 分钟 | 5 分钟 |
| Phase 1.2 | 编译 Opus 库 | 5-10 分钟 | 15 分钟 |
| Phase 2 | 重新编译 PJSIP | 15-30 分钟 | 45 分钟 |
| Phase 3 | 配置 Opus 编解码器 | 10 分钟 | 55 分钟 |
| Phase 4 | UI 扩展 | 20 分钟 | 75 分钟 |
| 测试验证 | 通话测试 | 15 分钟 | 90 分钟 |

**总计**: 约 1.5 小时

---

## ✅ 成功标准

### Phase 1 成功标准
- [ ] Opus 源码下载完成
- [ ] 容器编译成功
- [ ] 生成 `libopus.a` 静态库
- [ ] 头文件正确复制

### Phase 2 成功标准
- [ ] PJSIP 编译日志显示 "Opus support: yes"
- [ ] `libpjmedia-codec-*.a` 文件更新（文件大小增加）
- [ ] 无编译错误

### Phase 3 成功标准
- [ ] 应用启动日志显示 "Found Opus codec"
- [ ] Opus 配置成功日志
- [ ] 拨打电话 SDP 协商包含 "opus"

### Phase 4 成功标准
- [ ] SIP 设置界面显示编解码器选择下拉框
- [ ] 切换编解码器后优先级改变
- [ ] 配置持久化（重启后保持）

---

## 🚨 可能遇到的问题

### 问题 1: Opus 库链接错误
**症状**: PJSIP 编译失败，提示找不到 Opus 库

**解决**:
- 确认 Opus 安装路径：`/opt/opus`
- 检查 `--with-opus` 参数
- 检查 `libopus.a` 是否存在

### 问题 2: Opus 编解码器未注册
**症状**: 应用日志显示 "Opus codec NOT found"

**解决**:
- 确认 `PJMEDIA_HAS_OPUS_CODEC 1` 已定义
- 检查 PJSIP 编译日志
- 可能需要调用 `pjmedia_codec_opus_init()`

### 问题 3: Opus 采样率不匹配
**症状**: 拨打电话崩溃或音质异常

**解决**:
- 确认 `sample_rate = 16000` 配置生效
- 检查 plughw 设备是否支持 16kHz
- 查看 FIX 100.248 设备选择是否正确

---

## 📄 相关文档

### 参考文档
1. [Opus 16kHz 配置方案](15-Opus16kHz配置方案.md) - 详细配置参数
2. [FIX 100.248 实施总结](17-FIX100.248-实施完成总结.md) - plughw 设备选择
3. [PJSIP 编译脚本](../../scripts/2025-12-27/compile-pjsip-in-container.ps1) - 现有编译参考

### 待创建文档
1. `21-Opus库编译完成总结.md` - Phase 1 完成后
2. `22-PJSIP-Opus集成完成总结.md` - Phase 2 完成后
3. `23-Opus编解码器配置完成.md` - Phase 3 完成后
4. `24-SIP设置界面扩展完成.md` - Phase 4 完成后

---

## 🎯 下一步行动

**立即执行**:
1. ✅ 文档已创建（本文档）
2. ⏭️ 下载 Opus 源码
3. ⏭️ 创建 Opus 编译脚本

**用户操作**:
- 确认计划无误
- 启动 Phase 1.1（下载 Opus 源码）

---

**创建时间**: 2026-01-18 23:30
**最后更新**: 2026-01-18 23:30
