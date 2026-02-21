# Phase 7.46.24 - 修复 PaddleSpeech 模型名称错误

**时间**: 2026-02-21 21:30
**问题**: PaddleSpeech 合成失败，提示找不到模型
**状态**: 🔧 修复中

## 问题分析

### 错误信息
```
❌ 合成失败: Can't find "/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc-zh" in resource.
Model name must be one of ['fastspeech2_csmsc-zh', 'fastspeech2_ljspeech-en', ...]
```

### 根本原因
1. **C++ 端传递的是完整路径**：
   ```
   /home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc
   ```

2. **PaddleSpeech 期望的是预定义模型名称**：
   ```
   fastspeech2_csmsc-zh  （不带路径，带语言后缀）
   ```

3. **Python 代码直接将路径作为模型名称**：
   ```python
   am_name = current_model  # 这是完整路径，不是模型名称
   tts_executor(am=am_name, ...)  # 传递错误的参数
   ```

### 为什么会有这个问题？
- PaddleSpeech 有两种使用方式：
  1. **预定义模型名称**：使用 `fastspeech2_csmsc-zh`，会自动下载模型
  2. **本地模型路径**：需要使用 `am_ckpt`, `am_config` 等参数（更复杂）

- 我们的代码混淆了这两种方式：
  - 传递的是本地路径
  - 但使用的是预定义模型名称的参数

## 解决方案

### 方案选择
使用**预定义模型名称**方式（简单可靠）：
1. 从完整路径中提取模型名称：`fastspeech2_csmsc`
2. 根据模型名称确定语言后缀：`-zh` 或 `-en`
3. 组合成完整的模型名称：`fastspeech2_csmsc-zh`
4. 让 PaddleSpeech 使用预定义模型（自动下载）

### 修改内容

**文件**: `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

#### 1. 修改 `initialize_paddlespeech` 函数
```python
def initialize_paddlespeech(model_name):
    """
    初始化 PaddleSpeech TTS

    Args:
        model_name: 模型路径或名称
                   如: "/home/pi/.../fastspeech2_csmsc" 或 "fastspeech2_csmsc"

    Returns:
        bool: 是否成功
    """
    global tts_executor, current_model

    try:
        logger.info(f"🔧 初始化 PaddleSpeech - 模型: {model_name}")

        # ✅ 2026-02-21 21:30: 从路径中提取模型名称
        # 原因：PaddleSpeech 期望预定义模型名称，不是文件路径
        # 效果：支持路径和名称两种输入方式

        # 如果是路径，提取最后一部分作为模型名称
        if '/' in model_name or '\\' in model_name:
            model_name = os.path.basename(model_name)
            logger.info(f"📝 提取模型名称: {model_name}")

        # 导入 PaddleSpeech
        from paddlespeech.cli.tts.infer import TTSExecutor

        # 创建 TTS 执行器
        tts_executor = TTSExecutor()

        # 保存模型名称（不带语言后缀）
        current_model = model_name

        logger.info("✅ PaddleSpeech 初始化成功")
        return True

    except Exception as e:
        logger.error(f"❌ 初始化失败: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False
```

#### 2. 修改 `synthesize_speech` 函数
```python
def synthesize_speech(text, output_path, speaker_id=0, speed=1.0, volume=0.8):
    """
    合成语音
    """
    global tts_executor, current_model

    if tts_executor is None:
        logger.error("❌ TTS 未初始化")
        return False

    try:
        logger.info(f"🎙️ 合成语音 - 文本: {text}, 说话人ID: {speaker_id}, 语速: {speed}")

        # ✅ 2026-02-21 21:30: 使用预定义模型名称（带语言后缀）
        # 原因：PaddleSpeech 期望 'fastspeech2_csmsc-zh' 而不是路径
        # 效果：让 PaddleSpeech 使用预定义模型（自动下载）

        # 根据模型名称确定语言和声码器
        if 'csmsc' in current_model or 'aishell3' in current_model or 'canton' in current_model:
            # 中文模型
            am_name = f"{current_model}-zh"  # 添加 -zh 后缀
            voc_name = 'pwgan_csmsc'
            lang = 'zh'
        elif 'ljspeech' in current_model or 'vctk' in current_model:
            # 英文模型
            am_name = f"{current_model}-en"  # 添加 -en 后缀
            voc_name = 'hifigan_ljspeech'
            lang = 'en'
        elif 'mix' in current_model:
            # 混合语言模型
            am_name = f"{current_model}-mix"  # 添加 -mix 后缀
            voc_name = 'pwgan_csmsc'
            lang = 'mix'
        else:
            # 默认使用中文
            am_name = f"{current_model}-zh"
            voc_name = 'pwgan_csmsc'
            lang = 'zh'

        logger.info(f"📦 使用模型: am={am_name}, voc={voc_name}, lang={lang}")

        # 调用 PaddleSpeech 合成
        tts_executor(
            text=text,
            output=output_path,
            am=am_name,        # 预定义模型名称，如 'fastspeech2_csmsc-zh'
            voc=voc_name,      # 预定义声码器名称，如 'pwgan_csmsc'
            lang=lang,         # 语言：'zh' 或 'en'
            spk_id=speaker_id  # 说话人ID
        )

        # 检查输出文件
        if not os.path.exists(output_path):
            logger.error(f"❌ 输出文件不存在: {output_path}")
            return False

        # 调整音量（使用 pydub）
        if volume != 1.0:
            try:
                from pydub import AudioSegment
                audio = AudioSegment.from_wav(output_path)
                audio = audio + (20 * (volume - 1.0))  # 调整音量
                audio.export(output_path, format="wav")
                logger.info(f"✅ 音量已调整: {volume}")
            except Exception as e:
                logger.warning(f"⚠️ 音量调整失败: {e}")

        logger.info(f"✅ 合成成功: {output_path}")
        return True

    except Exception as e:
        logger.error(f"❌ 合成失败: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False
```

## 预期效果

修改后：
1. ✅ 从路径中提取模型名称：`fastspeech2_csmsc`
2. ✅ 自动添加语言后缀：`fastspeech2_csmsc-zh`
3. ✅ PaddleSpeech 使用预定义模型（自动下载）
4. ✅ TTS 合成成功

## 注意事项

1. **模型下载**：
   - PaddleSpeech 会自动下载预定义模型到 `~/.paddlespeech/`
   - 首次使用需要网络连接
   - 下载的模型会被缓存，后续使用不需要重新下载

2. **本地模型**：
   - 我们之前下载的本地模型暂时不会被使用
   - 后续可以研究如何使用本地模型（需要使用 `am_ckpt`, `am_config` 等参数）

3. **语言后缀规则**：
   - 中文模型（csmsc, aishell3, canton）：`-zh`
   - 英文模型（ljspeech, vctk）：`-en`
   - 混合语言模型（mix）：`-mix`

## 下一步

1. 修改 Python 代码
2. 重新构建 Docker 镜像
3. 部署到设备测试
4. 验证 TTS 合成功能
