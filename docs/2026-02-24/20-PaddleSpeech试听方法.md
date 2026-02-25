# PaddleSpeech 试听方法

**创建时间**: 2026-02-24 22:30
**目的**: 提供 PaddleSpeech 试听途径，支持自定义中文文字输入

---

## 一、在线试听（最快）

### 1.1 PaddleSpeech 官方 Demo

**地址**: https://paddlespeech.bj.bcebos.com/demos/tts_demos.html

**特点**：
- ✅ 无需安装
- ✅ 可以选择不同模型
- ✅ 可以选择不同说话人
- ⚠️ 不能自定义输入文字（只有预设示例）

---

### 1.2 AI Studio 在线体验

**地址**: https://aistudio.baidu.com/aistudio/projectdetail/4353348

**特点**：
- ✅ 百度官方平台
- ✅ 可以运行代码
- ✅ 可以自定义输入文字
- ⚠️ 需要注册百度账号

**使用方法**：
1. 注册/登录百度 AI Studio
2. 打开项目
3. 点击 "运行" 或 "Fork" 项目
4. 修改代码中的文本
5. 运行生成音频

---

## 二、在设备 188 上测试（推荐，最准确）

### 2.1 快速测试脚本

**优势**：
- ✅ 在实际部署环境中测试
- ✅ 可以测试性能
- ✅ 可以自定义任意文字
- ✅ 可以测试不同说话人

**我帮您创建自动化测试脚本**：

```powershell
# 在 Windows 上执行，自动在设备上测试
.\scripts\2026-02-24\03-test-paddlespeech-on-device.ps1
```

---

## 三、本地 Windows 测试（可选）

### 3.1 使用 Docker（推荐）

**优势**：
- ✅ 不污染本地环境
- ✅ 与生产环境一致
- ⚠️ 需要 Docker Desktop

**步骤**：

```powershell
# 1. 启动临时容器
docker run -it --rm `
  -v ${PWD}:/workspace `
  python:3.12-slim bash

# 2. 容器内安装 PaddleSpeech
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple

# 3. 测试
paddlespeech tts --input "你好，这是测试" --output test.wav

# 4. 退出容器
exit

# 5. 播放音频（在 Windows 上）
# test.wav 会保存在当前目录
```

---

### 3.2 直接在 Windows 上安装（不推荐）

**注意**：
- ⚠️ PaddleSpeech 主要为 Linux 设计
- ⚠️ Windows 上可能有兼容性问题
- ⚠️ 仅用于快速测试

**步骤**：

```powershell
# 1. 创建虚拟环境
python -m venv paddle-test
.\paddle-test\Scripts\Activate.ps1

# 2. 安装 PaddleSpeech
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple

# 3. 测试
paddlespeech tts --input "你好世界" --output test.wav

# 4. 播放
# 使用 Windows Media Player 打开 test.wav
```

---

## 四、完整测试脚本（推荐使用）

### 4.1 自动化测试脚本

**我已经为您创建了自动化脚本**：

**文件**: `scripts/2026-02-24/03-test-paddlespeech-on-device.ps1`

**功能**：
- ✅ 自动在设备 188 上安装 PaddleSpeech
- ✅ 生成多个测试音频
- ✅ 测试不同说话人
- ✅ 自动下载到 Windows
- ✅ 可以自定义测试文字

**使用方法**：

```powershell
# 运行测试脚本
.\scripts\2026-02-24\03-test-paddlespeech-on-device.ps1

# 或指定自定义文字
.\scripts\2026-02-24\03-test-paddlespeech-on-device.ps1 -TestText "你好，这是工业控制系统的语音提示"
```

---

### 4.2 交互式测试脚本

**文件**: `scripts/2026-02-24/04-interactive-tts-test.ps1`

**功能**：
- ✅ 交互式输入文字
- ✅ 选择说话人
- ✅ 实时生成和试听
- ✅ 对比不同说话人

**使用方法**：

```powershell
# 运行交互式测试
.\scripts\2026-02-24\04-interactive-tts-test.ps1

# 会提示：
# 1. 输入要合成的文字
# 2. 选择说话人 ID
# 3. 自动生成并下载音频
# 4. 询问是否继续测试
```

---

## 五、测试文本建议

### 5.1 工业场景测试文本

```
基础测试:
"你好，这是语音测试。"

设备状态:
"设备运行正常，请注意安全。"

报警提示:
"警告！设备温度过高，请立即检查。"

操作指引:
"请按下启动按钮，系统将在三秒后启动。三、二、一。"

数字测试:
"当前温度为二十五点五摄氏度，压力为一百二十千帕。"

长文本测试:
"欢迎使用工业控制系统。本系统采用先进的语音提示技术，为您提供实时的设备状态信息和操作指引。请遵守安全操作规程，确保设备正常运行。"
```

### 5.2 说话人选择建议

**PaddleSpeech AISHELL-3 模型**：
- 174 个说话人可选
- 说话人 ID: 0-173

**推荐说话人**（工业场景）：
```
女声（清晰、专业）:
- Speaker 0: 年轻女声，清晰
- Speaker 10: 成熟女声，稳重
- Speaker 20: 中性女声，专业

男声（沉稳、权威）:
- Speaker 1: 年轻男声，清晰
- Speaker 11: 成熟男声，沉稳
- Speaker 21: 中性男声，专业
```

---

## 六、完整测试流程

### 方案 A：使用自动化脚本（最简单）

```powershell
# 1. 运行测试脚本
.\scripts\2026-02-24\03-test-paddlespeech-on-device.ps1

# 2. 等待生成（约 5-10 分钟）
# 脚本会自动：
# - 在设备上安装 PaddleSpeech
# - 生成多个测试音频
# - 下载到 Windows

# 3. 试听音频
# 音频保存在: test_output/paddlespeech/
# 使用 Windows Media Player 播放
```

### 方案 B：交互式测试（最灵活）

```powershell
# 1. 运行交互式脚本
.\scripts\2026-02-24\04-interactive-tts-test.ps1

# 2. 按提示操作
# - 输入文字
# - 选择说话人
# - 试听音频
# - 继续测试或退出
```

### 方案 C：手动测试（最灵活）

```bash
# 1. SSH 到设备
ssh linaro@192.168.10.188

# 2. 安装 PaddleSpeech（如果没有）
pip3 install paddlespeech

# 3. 测试
paddlespeech tts \
  --input "你好，这是工业控制系统的语音提示" \
  --output test.wav \
  --spk_id 0

# 4. 下载音频（在 Windows 上执行）
scp linaro@192.168.10.188:~/test.wav .

# 5. 播放试听
```

---

## 七、说话人对比测试

### 7.1 生成多个说话人的音频

**在设备上执行**：

```bash
# 创建对比测试脚本
cat > test_speakers.sh << 'EOF'
#!/bin/bash

TEXT="你好，这是工业控制系统的语音提示。设备运行正常，请注意安全。"

echo "生成不同说话人的音频..."

# 测试 10 个不同的说话人
for i in 0 1 10 11 20 21 50 51 100 101; do
    echo "生成说话人 $i ..."
    paddlespeech tts \
        --input "$TEXT" \
        --output "speaker_${i}.wav" \
        --spk_id $i
done

echo "完成！生成了 10 个音频文件"
ls -lh speaker_*.wav
EOF

chmod +x test_speakers.sh
./test_speakers.sh
```

**下载所有音频**：

```powershell
# 在 Windows 上执行
scp linaro@192.168.10.188:~/speaker_*.wav .
```

---

## 八、性能测试

### 8.1 测试生成速度

**在设备上执行**：

```bash
# 创建性能测试脚本
cat > benchmark.py << 'EOF'
import time
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()

test_texts = [
    "你好",
    "你好，这是测试",
    "你好，这是工业控制系统的语音提示",
    "你好，这是工业控制系统的语音提示。设备运行正常，请注意安全。",
]

print("=" * 60)
print("PaddleSpeech 性能测试")
print("=" * 60)

for i, text in enumerate(test_texts):
    print(f"\n测试 {i+1}: {len(text)} 个字符")
    print(f"文本: {text}")

    start = time.time()
    tts(text=text, output=f"bench_{i}.wav")
    elapsed = time.time() - start

    print(f"生成时间: {elapsed:.2f} 秒")
    print(f"实时率: {elapsed / (len(text) * 0.3):.2f}x")  # 假设每字 0.3 秒

print("\n" + "=" * 60)
print("测试完成")
print("=" * 60)
EOF

python3 benchmark.py
```

---

## 九、我为您创建的脚本

### 脚本 1：自动化测试

**文件**: `scripts/2026-02-24/03-test-paddlespeech-on-device.ps1`

**功能**：
- 自动安装 PaddleSpeech
- 生成测试音频
- 下载到 Windows

### 脚本 2：交互式测试

**文件**: `scripts/2026-02-24/04-interactive-tts-test.ps1`

**功能**：
- 交互式输入文字
- 选择说话人
- 实时生成和试听

---

## 十、推荐使用流程

### 最快速（5 分钟）

```powershell
# 1. 运行自动化测试
.\scripts\2026-02-24\03-test-paddlespeech-on-device.ps1

# 2. 等待完成
# 3. 试听 test_output/paddlespeech/ 目录下的音频
```

### 最灵活（按需）

```powershell
# 1. 运行交互式测试
.\scripts\2026-02-24\04-interactive-tts-test.ps1

# 2. 输入自定义文字
# 3. 选择说话人
# 4. 试听并对比
```

---

## 十一、常见问题

### Q1: 如何选择合适的说话人？

**A**:
1. 先试听几个推荐的说话人（0, 1, 10, 11, 20, 21）
2. 根据场景选择：
   - 报警提示：选择清晰、有力的声音
   - 日常提示：选择柔和、专业的声音
   - 操作指引：选择稳重、权威的声音

### Q2: 如何调整语速？

**A**:
```bash
paddlespeech tts \
  --input "你好" \
  --output test.wav \
  --spk_id 0 \
  --speed 1.2  # 1.0 是正常速度，1.2 是 1.2 倍速
```

### Q3: 如何调整音调？

**A**:
```bash
paddlespeech tts \
  --input "你好" \
  --output test.wav \
  --spk_id 0 \
  --pitch 1.1  # 1.0 是正常音调，1.1 是提高 10%
```

---

## 十二、下一步

**试听后的决策**：

1. **如果 PaddleSpeech 满足需求**：
   ```powershell
   # 直接重新构建（MeloTTS 已禁用）
   .\build-ubuntu24-apt.ps1 188
   ```

2. **如果需要对比 MeloTTS**：
   - 先试听 MeloTTS（见 19-MeloTTS试听途径.md）
   - 再决定是否需要集成

3. **如果两个都需要**：
   ```powershell
   # 使用预编译方案
   .\scripts\2026-02-24\01-compile-packages-on-device.ps1
   ```

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 22:30
**下一步**: 运行测试脚本试听 PaddleSpeech
