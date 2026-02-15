# PaddleSpeech 离线部署完整方案

**创建时间**: 2026-02-15 02:30
**目标**: 在ARM64设备上离线部署PaddleSpeech TTS
**问题**: aistudio_sdk依赖冲突，无法在线下载模型

---

## 🔍 问题根源分析

### 依赖链
```
PaddleSpeech
  └── paddlenlp
       └── aistudio_sdk
            └── hub.download (不存在)
```

### 为什么会失败
1. **aistudio_sdk API变更**: 新版本移除了`hub.download`函数
2. **paddlenlp未更新**: 仍然依赖旧版API
3. **版本锁定困难**: 无法找到兼容的版本组合

---

## ✅ 解决方案：完全绕过在线下载

### 方案概述
1. **不使用TTSExecutor自动下载**
2. **手动下载模型文件**
3. **直接使用底层API加载模型**

---

## 📥 步骤1: 手动下载模型

### 模型文件列表

#### FastSpeech2 + PWG (推荐)
```
声学模型 (AM): FastSpeech2
https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip

声码器 (Vocoder): Parallel WaveGAN
https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip
```

#### VITS (单模型，更简单)
```
VITS 中文模型:
https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip
```

### 下载方法

#### 方法1: 使用wget/curl
```bash
# 在有网络的Linux机器上
wget https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip
```

#### 方法2: 使用浏览器
直接在浏览器中打开URL下载

#### 方法3: 使用PowerShell
```powershell
Invoke-WebRequest -Uri "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip" -OutFile "vits_csmsc.zip"
```

---

## 📂 步骤2: 组织模型文件

### 目录结构
```
libs/tts_models/paddlespeech/
├── vits_csmsc/
│   ├── default.yaml
│   ├── snapshot_iter_*.pdz
│   └── phone_id_map.txt
└── fastspeech2_pwgan/
    ├── fastspeech2_csmsc/
    │   ├── default.yaml
    │   ├── snapshot_iter_*.pdz
    │   └── phone_id_map.txt
    └── pwgan_csmsc/
        ├── default.yaml
        └── snapshot_iter_*.pdz
```

### 解压命令
```powershell
# Windows
Expand-Archive -Path vits_csmsc.zip -DestinationPath libs/tts_models/paddlespeech/vits_csmsc

# Linux
unzip vits_csmsc.zip -d /path/to/models/vits_csmsc
```

---

## 💻 步骤3: 使用底层API加载模型

### 方法A: 使用PaddleSpeech底层API（推荐）

```python
from paddlespeech.t2s.exps.syn_utils import get_am_inference, get_voc_inference
from paddlespeech.t2s.frontend.zh_frontend import Frontend
import soundfile as sf

# 初始化前端（文本处理）
frontend = Frontend(
    phone_vocab_path="libs/tts_models/paddlespeech/vits_csmsc/phone_id_map.txt"
)

# 加载声学模型
am_inference = get_am_inference(
    am='fastspeech2_csmsc',
    am_config='libs/tts_models/paddlespeech/fastspeech2_csmsc/default.yaml',
    am_ckpt='libs/tts_models/paddlespeech/fastspeech2_csmsc/snapshot_iter_*.pdz',
    am_stat='libs/tts_models/paddlespeech/fastspeech2_csmsc/speech_stats.npy',
    phones_dict='libs/tts_models/paddlespeech/fastspeech2_csmsc/phone_id_map.txt'
)

# 加载声码器
voc_inference = get_voc_inference(
    voc='pwgan_csmsc',
    voc_config='libs/tts_models/paddlespeech/pwgan_csmsc/default.yaml',
    voc_ckpt='libs/tts_models/paddlespeech/pwgan_csmsc/snapshot_iter_*.pdz',
    voc_stat='libs/tts_models/paddlespeech/pwgan_csmsc/feats_stats.npy'
)

# 合成语音
def synthesize(text):
    # 文本转音素
    input_ids = frontend.get_input_ids(text, merge_sentences=True)
    phone_ids = input_ids["phone_ids"]

    # 声学模型推理
    mel = am_inference(phone_ids)

    # 声码器推理
    wav = voc_inference(mel)

    return wav

# 使用
text = "你好，欢迎使用飞桨语音合成"
wav = synthesize(text)
sf.write("output.wav", wav, samplerate=24000)
```

### 方法B: 使用VITS（单模型，更简单）

```python
from paddlespeech.t2s.exps.syn_utils import get_am_inference
from paddlespeech.t2s.frontend.zh_frontend import Frontend
import soundfile as sf

# 初始化前端
frontend = Frontend(
    phone_vocab_path="libs/tts_models/paddlespeech/vits_csmsc/phone_id_map.txt"
)

# 加载VITS模型（声学模型+声码器一体）
vits_inference = get_am_inference(
    am='vits_csmsc',
    am_config='libs/tts_models/paddlespeech/vits_csmsc/default.yaml',
    am_ckpt='libs/tts_models/paddlespeech/vits_csmsc/snapshot_iter_*.pdz',
    phones_dict='libs/tts_models/paddlespeech/vits_csmsc/phone_id_map.txt'
)

# 合成语音
def synthesize(text):
    input_ids = frontend.get_input_ids(text, merge_sentences=True)
    phone_ids = input_ids["phone_ids"]
    wav = vits_inference(phone_ids)
    return wav

# 使用
text = "你好，欢迎使用飞桨语音合成"
wav = synthesize(text)
sf.write("output.wav", wav, samplerate=24000)
```

---

## 🔧 步骤4: 集成到项目

### C++封装（PaddleSpeechAdapter）

```cpp
// src/tts_engines/PaddleSpeechAdapter.cpp

#include <Python.h>

class PaddleSpeechAdapter {
public:
    PaddleSpeechAdapter() {
        // 初始化Python解释器
        Py_Initialize();

        // 导入模块
        PyRun_SimpleString("import sys");
        PyRun_SimpleString("sys.path.append('/app/tts_engines')");

        // 加载模型
        PyRun_SimpleString(R"(
from paddlespeech_offline import PaddleSpeechOffline
tts = PaddleSpeechOffline('/app/models/paddlespeech/vits_csmsc')
        )");
    }

    void generateSpeech(const QString& text, const QString& outputPath) {
        QString pythonCode = QString(R"(
wav = tts.synthesize('%1')
import soundfile as sf
sf.write('%2', wav, samplerate=24000)
        )").arg(text, outputPath);

        PyRun_SimpleString(pythonCode.toUtf8().constData());
    }
};
```

---

## 🐳 步骤5: Docker部署

### Dockerfile修改

```dockerfile
# 安装PaddleSpeech（不使用TTSExecutor）
RUN pip install paddlepaddle paddlespeech --no-deps && \
    pip install numpy scipy soundfile librosa

# 复制离线模型
COPY libs/tts_models/paddlespeech /app/models/paddlespeech

# 复制离线推理脚本
COPY tts_engines/paddlespeech_offline.py /app/tts_engines/
```

---

## ✅ 优势

1. **完全离线**: 不依赖网络
2. **绕过依赖问题**: 不使用aistudio_sdk
3. **性能更好**: 直接使用底层API
4. **可控性强**: 完全掌握模型加载过程

---

## 📝 注意事项

1. **模型文件大小**: VITS约200MB，FastSpeech2+PWG约150MB
2. **Python依赖**: 仍需paddlepaddle和paddlespeech，但不需要完整安装
3. **ARM64兼容性**: 确保paddlepaddle有ARM64版本

---

## 🚀 下一步

1. 手动下载模型文件
2. 创建离线推理脚本
3. 测试语音合成
4. 集成到C++代码

---

**Sources**:
- [PaddleSpeech GitHub](https://github.com/PaddlePaddle/PaddleSpeech)
- [PaddleSpeech Model Zoo](https://github.com/PaddlePaddle/PaddleSpeech/blob/develop/docs/source/released_model.md)
