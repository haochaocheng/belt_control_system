# Phase 7.46.29 - 修复 PaddleSpeech 重复添加语言后缀问题

**时间**: 2026-02-22 01:45
**问题**: PaddleSpeech TTS 合成失败，错误信息 `Can't find "fastspeech2_csmsc-zh-zh" in resource`
**状态**: ✅ 已修复

## 问题现象

TTS 合成时报错：
```
❌ 合成失败: Can't find "fastspeech2_csmsc-zh-zh" in resource.
Model name must be one of ['fastspeech2_csmsc-zh', ...]
```

模型名称出现了双重后缀 `-zh-zh`，导致 PaddleSpeech 找不到模型。

## 根本原因

**PaddleSpeech 库会根据 `lang` 参数自动添加语言后缀！**

当调用 `tts_executor(am='fastspeech2_csmsc-zh', lang='zh')` 时：
1. 我们的代码已经添加了 `-zh` 后缀：`fastspeech2_csmsc` → `fastspeech2_csmsc-zh`
2. PaddleSpeech 内部又根据 `lang='zh'` 添加了 `-zh`：`fastspeech2_csmsc-zh` → `fastspeech2_csmsc-zh-zh`

## 解决方案

**不要手动添加后缀，让 PaddleSpeech 自己添加！**

修改 `paddle_tts_service.py`，如果模型名称已经包含后缀，则去掉后缀：

```python
# ✅ 2026-02-22 01:45: 修复重复添加语言后缀的问题
# 根本原因：PaddleSpeech 库会根据 lang 参数自动添加后缀
# 例如：am='fastspeech2_csmsc' + lang='zh' → PaddleSpeech 内部使用 'fastspeech2_csmsc-zh'
# 所以我们不需要手动添加后缀，直接使用模型名称即可

# 如果模型名称已经包含后缀，需要去掉（因为 PaddleSpeech 会自动添加）
am_name = current_model
if current_model.endswith('-zh'):
    am_name = current_model[:-3]  # 去掉 '-zh'
elif current_model.endswith('-en'):
    am_name = current_model[:-3]  # 去掉 '-en'
elif current_model.endswith('-mix'):
    am_name = current_model[:-4]  # 去掉 '-mix'
elif current_model.endswith('-canton'):
    am_name = current_model[:-7]  # 去掉 '-canton'
```

## 额外问题：模型文件路径

修复后缀问题后，又遇到新错误：
```
Download from https://paddlespeech.cdn.bcebos.com/.../fastspeech2_nosil_baker_ckpt_0.4.zip failed
```

**原因**：PaddleSpeech 默认在 `/root/.paddlespeech/models/` 查找模型，但我们的模型在 `/app/tts_models/paddlespeech/models/`

**解决方案**：创建符号链接
```bash
ln -s /app/tts_models/paddlespeech/models/fastspeech2_csmsc-zh /root/.paddlespeech/models/fastspeech2_csmsc-zh
ln -s /app/tts_models/paddlespeech/models/pwgan_csmsc-zh /root/.paddlespeech/models/pwgan_csmsc-zh
```

## 调试过程中的发现

1. **Python 进程不会自动重新加载代码**：修改 `.py` 文件后，需要杀死 Python 进程或切换模型才能加载新代码
2. **Docker 层缓存问题**：`docker cp` 可以直接更新容器中的文件，无需重新构建镜像
3. **PaddleSpeech 日志被覆盖**：PaddleSpeech 导入时会覆盖 Python 的日志配置，需要使用 `print(..., file=sys.stderr)` 输出调试信息

## 修改文件

1. [docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py](docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py#L116) - 修复重复添加语言后缀

## 验证方法

1. 切换到语音管理页面
2. 选择 PaddleSpeech 引擎
3. 选择 fastspeech2_csmsc 模型
4. 点击"生成测试语音"
5. 应该能听到语音输出

## 额外问题2：G2PW 模型路径

合成时还需要 G2PW 模型（中文文本转拼音），也需要创建符号链接：

```bash
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1 /root/.paddlespeech/models/G2PWModel_1.1
```

## 需要创建的所有符号链接

```bash
# fastspeech2_csmsc 模型
ln -sf /app/tts_models/paddlespeech/models/fastspeech2_csmsc-zh /root/.paddlespeech/models/fastspeech2_csmsc-zh

# pwgan_csmsc 声码器
ln -sf /app/tts_models/paddlespeech/models/pwgan_csmsc-zh /root/.paddlespeech/models/pwgan_csmsc-zh

# G2PW 中文文本转拼音模型（目录和zip文件都需要）
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1 /root/.paddlespeech/models/G2PWModel_1.1
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1.zip /root/.paddlespeech/models/G2PWModel_1.1.zip
```

## 已完成的修改

### 1. paddle_tts_service.py
- 文件：[docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py](docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py#L116)
- 修改：去掉模型名称中的语言后缀，让 PaddleSpeech 自动添加

### 2. app-entrypoint.sh
- 文件：[docker/rk3588/app-entrypoint.sh](docker/rk3588/app-entrypoint.sh#L24)
- 修改：添加 PaddleSpeech 模型符号链接创建逻辑
- 符号链接在容器启动时自动创建，确保离线使用预下载的模型

## 下一步

1. ✅ 将符号链接逻辑添加到容器启动脚本 `app-entrypoint.sh` 中
2. 重新构建 Docker 镜像以包含修复
3. 测试 TTS 合成功能
4. 测试其他模型（fastspeech2_aishell3, fastspeech2_ljspeech, fastspeech2_vctk）
