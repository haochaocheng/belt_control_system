# MeloTTS 试听途径

**创建时间**: 2026-02-24 22:20
**目的**: 提供 MeloTTS 试听途径，帮助评估是否需要集成

---

## 一、在线试听（最快）

### 1.1 官方 Hugging Face Space

**地址**: https://huggingface.co/spaces/mrfakename/MeloTTS

**特点**：
- ✅ 无需安装，直接在线使用
- ✅ 支持所有语言和说话人
- ✅ 可以输入自定义文本
- ✅ 可以下载生成的音频

**使用方法**：
1. 打开链接
2. 选择语言（Chinese, English, Spanish 等）
3. 选择说话人（Speaker）
4. 输入文本
5. 点击 "Synthesize" 生成
6. 播放或下载音频

**支持的语言**：
- 🇨🇳 Chinese (ZH)
- 🇺🇸 English (EN)
- 🇪🇸 Spanish (ES)
- 🇫🇷 French (FR)
- 🇯🇵 Japanese (JP)
- 🇰🇷 Korean (KR)
- 等等...

---

### 1.2 GitHub 官方示例

**地址**: https://github.com/myshell-ai/MeloTTS

**示例音频位置**：
- 在 README 中有示例音频链接
- 在 `examples/` 目录下有预生成的音频文件

**特点**：
- ✅ 官方提供的高质量示例
- ✅ 展示不同语言和说话人
- ✅ 可以对比不同场景

---

## 二、本地快速试听（推荐）

### 2.1 在 Windows 上快速安装（不推荐用于生产）

**前提条件**：
- Python 3.8+
- 不需要 Rust（使用预编译 wheel）

**步骤**：

```powershell
# 1. 创建虚拟环境
python -m venv melo-test
.\melo-test\Scripts\Activate.ps1

# 2. 安装 MeloTTS（可能需要 10-20 分钟）
pip install melo-tts

# 3. 下载模型（自动）
# 首次运行会自动下载模型

# 4. 测试
python
```

```python
from melo.api import TTS

# 中文测试
tts_zh = TTS(language='ZH', device='cpu')
speaker_ids = tts_zh.hps.data.spk2id
print("中文说话人:", speaker_ids)

# 生成中文语音
tts_zh.tts_to_file(
    text="你好，这是 MeloTTS 的中文语音测试。",
    speaker_id=speaker_ids['ZH'],
    output_path="test_zh.wav"
)

# 英文测试
tts_en = TTS(language='EN', device='cpu')
speaker_ids_en = tts_en.hps.data.spk2id
print("英文说话人:", speaker_ids_en)

# 生成英文语音
tts_en.tts_to_file(
    text="Hello, this is a test of MeloTTS English voice.",
    speaker_id=speaker_ids_en['EN-US'],
    output_path="test_en.wav"
)
```

**注意**：
- ⚠️ Windows 上可能有预编译 wheel，安装较快
- ⚠️ 如果没有预编译 wheel，需要 Rust 编译器
- ⚠️ 仅用于测试，不用于生产部署

---

### 2.2 在设备 188 上测试（推荐）

**优势**：
- ✅ 原生 ARM64 环境
- ✅ 可以测试实际性能
- ✅ 可以对比 PaddleSpeech

**步骤**：

```bash
# SSH 到设备
ssh linaro@192.168.10.188

# 1. 安装 Rust（如果没有）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# 2. 创建虚拟环境
python3 -m venv ~/melo-test
source ~/melo-test/bin/activate

# 3. 安装 MeloTTS（20-30 分钟）
pip3 install melo-tts

# 4. 测试脚本
cat > test_melo.py << 'EOF'
from melo.api import TTS
import time

# 中文测试
print("=== 测试中文 ===")
tts_zh = TTS(language='ZH', device='cpu')
speaker_ids = tts_zh.hps.data.spk2id
print(f"可用说话人: {speaker_ids}")

start = time.time()
tts_zh.tts_to_file(
    text="你好，这是工业控制系统的语音提示测试。请注意设备运行状态。",
    speaker_id=speaker_ids['ZH'],
    output_path="test_zh.wav"
)
elapsed = time.time() - start
print(f"生成时间: {elapsed:.2f} 秒")

# 英文测试
print("\n=== 测试英文 ===")
tts_en = TTS(language='EN', device='cpu')
speaker_ids_en = tts_en.hps.data.spk2id
print(f"可用说话人: {speaker_ids_en}")

start = time.time()
tts_en.tts_to_file(
    text="Hello, this is a voice notification from the industrial control system.",
    speaker_id=speaker_ids_en['EN-US'],
    output_path="test_en.wav"
)
elapsed = time.time() - start
print(f"生成时间: {elapsed:.2f} 秒")

print("\n音频文件已生成:")
print("  - test_zh.wav (中文)")
print("  - test_en.wav (英文)")
EOF

# 5. 运行测试
python3 test_melo.py

# 6. 下载音频到 Windows 试听
# 在 Windows 上执行:
# scp linaro@192.168.10.188:~/test_*.wav .
```

---

## 三、对比试听（最有价值）

### 3.1 同时测试 PaddleSpeech 和 MeloTTS

**在设备 188 上执行**：

```bash
# 创建对比测试脚本
cat > compare_tts.py << 'EOF'
import time
from melo.api import TTS as MeloTTS

# 测试文本
test_text_zh = "你好，这是工业控制系统的语音提示。设备运行正常，请注意安全。"
test_text_en = "Hello, this is an industrial control system voice notification. Equipment is running normally."

print("=" * 60)
print("TTS 引擎对比测试")
print("=" * 60)

# 测试 MeloTTS 中文
print("\n[1/4] MeloTTS - 中文")
start = time.time()
tts_melo_zh = MeloTTS(language='ZH', device='cpu')
speaker_ids = tts_melo_zh.hps.data.spk2id
tts_melo_zh.tts_to_file(
    text=test_text_zh,
    speaker_id=speaker_ids['ZH'],
    output_path="melo_zh.wav"
)
elapsed = time.time() - start
print(f"  生成时间: {elapsed:.2f} 秒")
print(f"  输出文件: melo_zh.wav")

# 测试 MeloTTS 英文
print("\n[2/4] MeloTTS - 英文")
start = time.time()
tts_melo_en = MeloTTS(language='EN', device='cpu')
speaker_ids_en = tts_melo_en.hps.data.spk2id
tts_melo_en.tts_to_file(
    text=test_text_en,
    speaker_id=speaker_ids_en['EN-US'],
    output_path="melo_en.wav"
)
elapsed = time.time() - start
print(f"  生成时间: {elapsed:.2f} 秒")
print(f"  输出文件: melo_en.wav")

# 测试 PaddleSpeech 中文
print("\n[3/4] PaddleSpeech - 中文")
try:
    from paddlespeech.cli.tts import TTSExecutor
    start = time.time()
    tts_paddle = TTSExecutor()
    tts_paddle(
        text=test_text_zh,
        output="paddle_zh.wav"
    )
    elapsed = time.time() - start
    print(f"  生成时间: {elapsed:.2f} 秒")
    print(f"  输出文件: paddle_zh.wav")
except Exception as e:
    print(f"  ❌ PaddleSpeech 未安装或出错: {e}")

print("\n" + "=" * 60)
print("测试完成！")
print("=" * 60)
print("\n生成的音频文件:")
print("  - melo_zh.wav    (MeloTTS 中文)")
print("  - melo_en.wav    (MeloTTS 英文)")
print("  - paddle_zh.wav  (PaddleSpeech 中文)")
print("\n请下载到 Windows 试听对比")
EOF

# 运行对比测试
python3 compare_tts.py
```

**下载音频到 Windows**：

```powershell
# 在 Windows 上执行
scp linaro@192.168.10.188:~/*.wav .

# 使用 Windows Media Player 或其他播放器试听
```

---

## 四、在线对比工具

### 4.1 TTS Arena（推荐）

**地址**: https://huggingface.co/spaces/TTS-AGI/TTS-Arena

**特点**：
- ✅ 对比多个 TTS 引擎
- ✅ 包括 MeloTTS、PaddleSpeech 等
- ✅ 盲测模式（不知道是哪个引擎）
- ✅ 可以投票选择更好的

---

## 五、快速评估建议

### 5.1 评估维度

**试听时重点关注**：

1. **中文质量**：
   - 发音准确性
   - 韵律自然度
   - 语速是否合适
   - 是否有机器感

2. **英文质量**（如果需要）：
   - 发音准确性
   - 口音是否合适
   - 语调自然度

3. **适用性**：
   - 是否适合工业场景
   - 是否清晰易懂
   - 是否专业

4. **说话人选择**：
   - 是否有合适的声音
   - 男声/女声选择
   - 年龄感是否合适

### 5.2 对比清单

| 维度 | PaddleSpeech | MeloTTS | 您的评价 |
|------|-------------|---------|---------|
| 中文发音 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ? |
| 中文韵律 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ? |
| 英文质量 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ? |
| 说话人选择 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ? |
| 工业适用性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ? |

---

## 六、推荐试听流程

### 最快速（5 分钟）

1. 访问 Hugging Face Space: https://huggingface.co/spaces/mrfakename/MeloTTS
2. 选择 Chinese (ZH)
3. 输入："你好，这是工业控制系统的语音提示"
4. 生成并试听
5. 对比 GitHub 上的 PaddleSpeech 示例

### 最准确（30 分钟）

1. 在设备 188 上安装 MeloTTS
2. 运行对比测试脚本
3. 下载音频到 Windows
4. 使用相同文本对比试听
5. 评估是否值得增加部署复杂度

---

## 七、决策建议

### 试听后如果发现：

**MeloTTS 明显更好**：
- 使用预编译方案集成
- 执行: `.\scripts\2026-02-24\01-compile-packages-on-device.ps1`

**PaddleSpeech 足够好**：
- 只使用 PaddleSpeech
- 执行: `.\build-ubuntu24-apt.ps1 188`

**两者差不多**：
- 优先选择 PaddleSpeech（部署简单）
- 未来按需添加 MeloTTS

---

## 八、总结

### 推荐试听途径（按优先级）

1. **Hugging Face Space**（最快，5 分钟）
   - https://huggingface.co/spaces/mrfakename/MeloTTS

2. **设备上对比测试**（最准确，30 分钟）
   - 同时测试 PaddleSpeech 和 MeloTTS
   - 使用实际场景文本

3. **GitHub 示例**（参考）
   - https://github.com/myshell-ai/MeloTTS

### 关键评估点

- ✅ 中文质量是否明显优于 PaddleSpeech？
- ✅ 是否需要多语言支持？
- ✅ 是否值得增加部署复杂度？

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 22:20
**建议**: 先在线试听，再决定是否需要集成
