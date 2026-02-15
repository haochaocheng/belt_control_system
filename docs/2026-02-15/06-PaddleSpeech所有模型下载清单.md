# PaddleSpeech 所有官方模型下载清单

**创建时间**: 2026-02-15 06:10
**目的**: 提供所有PaddleSpeech官方TTS模型的完整下载地址

---

## 📥 中文模型（推荐）

### 1. FastSpeech2-CSMSC（女声）⭐ **当前使用**

**声学模型 (AM)**:
```
名称: fastspeech2_csmsc_ckpt_1.4.0
大小: 约 116 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip
说话人: 女声（标贝科技）
```

**声码器 (Vocoder)**:
```
名称: pwgan_csmsc_ckpt_0.5
大小: 约 5 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip
```

**HiFiGAN声码器（可选，质量更好）**:
```
名称: hifigan_csmsc_ckpt_0.1.1
大小: 约 50 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_csmsc_ckpt_0.1.1.zip
```

---

### 2. FastSpeech2-AISHELL3（多说话人，含男声）⭐ **推荐下载**

**声学模型 (AM)**:
```
名称: fastspeech2_aishell3_ckpt_1.1.0
大小: 约 120 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip
说话人: 218个说话人（男女混合）
```

**声码器 (Vocoder)**:
```
名称: pwgan_aishell3_ckpt_0.5
大小: 约 5 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip
```

**HiFiGAN声码器（可选）**:
```
名称: hifigan_aishell3_ckpt_0.2.0
大小: 约 50 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_aishell3_ckpt_0.2.0.zip
```

---

### 3. VITS-CSMSC（女声，端到端）⭐ **高质量**

```
名称: vits_csmsc_ckpt_1.4.0
大小: 约 400 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip
说话人: 女声（标贝科技）
特点: 端到端模型，不需要单独的声码器
```

---

### 4. VITS-AISHELL3（多说话人，含男声）⭐ **高质量+多说话人**

```
名称: vits_aishell3_ckpt_1.1.0
大小: 约 500 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip
说话人: 218个说话人（男女混合）
特点: 端到端模型，质量最好
```

---

### 5. SpeedySpeech-CSMSC（女声，快速）

**声学模型 (AM)**:
```
名称: speedyspeech_csmsc_ckpt_0.5.0
大小: 约 12 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip
说话人: 女声（标贝科技）
特点: 推理速度快，质量略低
```

**声码器**: 使用 pwgan_csmsc（见上面）

---

### 6. Tacotron2-CSMSC（女声，经典）

**声学模型 (AM)**:
```
名称: tacotron2_csmsc_ckpt_0.2.0
大小: 约 105 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/tacotron2/tacotron2_csmsc_ckpt_0.2.0.zip
说话人: 女声（标贝科技）
```

**声码器**: 使用 pwgan_csmsc（见上面）

---

### 7. Tacotron2-AISHELL3（多说话人）

**声学模型 (AM)**:
```
名称: tacotron2_aishell3_ckpt_0.3.0
大小: 约 110 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/tacotron2/tacotron2_aishell3_ckpt_0.3.0.zip
说话人: 218个说话人（男女混合）
```

**声码器**: 使用 pwgan_aishell3（见上面）

---

### 8. 中英文混合模型

**FastSpeech2-Mix（中英混合）**:
```
名称: fastspeech2_mix_ckpt_1.2.0
大小: 约 120 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_mix_ckpt_1.2.0.zip
说话人: 女声
特点: 支持中英文混合
```

**声码器**: 使用 pwgan_csmsc（见上面）

---

### 9. 粤语模型

**FastSpeech2-Canton（粤语）**:
```
名称: fastspeech2_canton_ckpt_0.1.0
大小: 约 115 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_canton_ckpt_0.1.0.zip
说话人: 女声
语言: 粤语
```

**声码器**:
```
名称: pwgan_canton_ckpt_0.1.0
大小: 约 5 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_canton_ckpt_0.1.0.zip
```

---

## 📥 英文模型

### 10. FastSpeech2-LJSpeech（英文女声）

**声学模型 (AM)**:
```
名称: fastspeech2_ljspeech_ckpt_1.4.0
大小: 约 115 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_ljspeech_ckpt_1.4.0.zip
说话人: 女声
语言: 英文
```

**声码器**:
```
名称: pwgan_ljspeech_ckpt_0.5
大小: 约 5 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_ljspeech_ckpt_0.5.zip
```

---

### 11. FastSpeech2-VCTK（英文多说话人）

**声学模型 (AM)**:
```
名称: fastspeech2_vctk_ckpt_1.2.0
大小: 约 120 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_vctk_ckpt_1.2.0.zip
说话人: 109个说话人（男女混合）
语言: 英文
```

**声码器**:
```
名称: pwgan_vctk_ckpt_0.5
大小: 约 5 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_vctk_ckpt_0.5.zip
```

---

### 12. VITS-LJSpeech（英文女声，端到端）

```
名称: vits_ljspeech_ckpt_1.0.0
大小: 约 400 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_ljspeech_ckpt_1.0.0.zip
说话人: 女声
语言: 英文
```

---

### 13. VITS-VCTK（英文多说话人，端到端）

```
名称: vits_vctk_ckpt_1.0.0
大小: 约 500 MB
下载: https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_vctk_ckpt_1.0.0.zip
说话人: 109个说话人（男女混合）
语言: 英文
```

---

## 📋 完整下载清单（按优先级）

### 🔥 必须下载（中文女声）

1. **FastSpeech2-CSMSC + PWG** ✅ 已下载
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip
   ```

---

### ⭐ 强烈推荐（支持男声）

2. **FastSpeech2-AISHELL3 + PWG**
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip
   ```

3. **VITS-AISHELL3**（高质量+多说话人）
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip
   ```

---

### 💎 高质量选项

4. **VITS-CSMSC**（女声，质量最好）
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip
   ```

5. **HiFiGAN-CSMSC**（更好的声码器）
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_csmsc_ckpt_0.1.1.zip
   ```

6. **HiFiGAN-AISHELL3**
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_aishell3_ckpt_0.2.0.zip
   ```

---

### 🚀 快速选项

7. **SpeedySpeech-CSMSC**（速度优先）
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip
   ```

---

### 🌏 其他语言

8. **中英混合**
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_mix_ckpt_1.2.0.zip
   ```

9. **粤语**
   ```
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_canton_ckpt_0.1.0.zip
   https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_canton_ckpt_0.1.0.zip
   ```

10. **英文女声**
    ```
    https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_ljspeech_ckpt_1.4.0.zip
    https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_ljspeech_ckpt_0.5.zip
    ```

11. **英文多说话人**
    ```
    https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_vctk_ckpt_1.2.0.zip
    https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_vctk_ckpt_0.5.zip
    ```

---

## 💾 批量下载脚本

### PowerShell脚本（Windows）

```powershell
# 创建下载目录
$DownloadDir = "E:\2025\3_gongkongji\belt_control_system\libs\tts_models\paddlespeech_all"
New-Item -ItemType Directory -Path $DownloadDir -Force

# 中文模型（必须）
$urls = @(
    # FastSpeech2-CSMSC（已下载，可跳过）
    # "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip",
    # "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip",

    # FastSpeech2-AISHELL3（多说话人，含男声）
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip",
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip",

    # VITS-CSMSC（高质量女声）
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip",

    # VITS-AISHELL3（高质量多说话人）
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip",

    # HiFiGAN声码器（高质量）
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_csmsc_ckpt_0.1.1.zip",
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_aishell3_ckpt_0.2.0.zip",

    # SpeedySpeech（快速）
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip",

    # Tacotron2
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/tacotron2/tacotron2_csmsc_ckpt_0.2.0.zip",
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/tacotron2/tacotron2_aishell3_ckpt_0.3.0.zip",

    # 中英混合
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_mix_ckpt_1.2.0.zip",

    # 粤语
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_canton_ckpt_0.1.0.zip",
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_canton_ckpt_0.1.0.zip"
)

# 下载所有模型
foreach ($url in $urls) {
    $filename = Split-Path $url -Leaf
    $output = Join-Path $DownloadDir $filename

    Write-Host "下载: $filename" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing

    Write-Host "解压: $filename" -ForegroundColor Yellow
    Expand-Archive -Path $output -DestinationPath $DownloadDir -Force

    Remove-Item $output -Force
    Write-Host "完成: $filename" -ForegroundColor Green
    Write-Host ""
}

Write-Host "所有模型下载完成！" -ForegroundColor Green
```

---

### Bash脚本（Linux/Mac）

```bash
#!/bin/bash

# 创建下载目录
DOWNLOAD_DIR="./paddlespeech_models"
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# 中文模型
urls=(
    # FastSpeech2-AISHELL3
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip"
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip"

    # VITS
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip"
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip"

    # HiFiGAN
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_csmsc_ckpt_0.1.1.zip"
    "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_aishell3_ckpt_0.2.0.zip"
)

# 下载并解压
for url in "${urls[@]}"; do
    filename=$(basename "$url")
    echo "下载: $filename"
    wget -q --show-progress "$url"

    echo "解压: $filename"
    unzip -q "$filename"
    rm "$filename"

    echo "完成: $filename"
    echo ""
done

echo "所有模型下载完成！"
```

---

## 📊 模型大小统计

### 中文模型总大小

| 模型组合 | 大小 |
|---------|------|
| FastSpeech2-CSMSC + PWG | 121 MB |
| FastSpeech2-AISHELL3 + PWG | 125 MB |
| VITS-CSMSC | 400 MB |
| VITS-AISHELL3 | 500 MB |
| HiFiGAN-CSMSC | 50 MB |
| HiFiGAN-AISHELL3 | 50 MB |
| SpeedySpeech-CSMSC | 12 MB |
| Tacotron2-CSMSC | 105 MB |
| Tacotron2-AISHELL3 | 110 MB |
| **总计** | **约 1.5 GB** |

---

## 💡 下载建议

### 最小配置（只需女声）
- FastSpeech2-CSMSC + PWG: 121 MB ✅ 已下载

### 推荐配置（支持男声）
- FastSpeech2-CSMSC + PWG: 121 MB ✅
- FastSpeech2-AISHELL3 + PWG: 125 MB
- **总计**: 246 MB

### 完整配置（所有功能）
- 所有中文模型: 约 1.5 GB
- 包含：女声、男声、多说话人、高质量、快速、粤语、中英混合

---

**Sources**:
- [PaddleSpeech Model Zoo](https://github.com/PaddlePaddle/PaddleSpeech/blob/develop/docs/source/released_model.md)
- [PaddleSpeech BOS Storage](https://paddlespeech.bj.bcebos.com/Parakeet/released_models/)
