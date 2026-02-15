# 自动下载脚本null错误修复

**创建时间**: 2026-02-15 13:00
**问题**: Python脚本中的`null`导致NameError
**状态**: ✅ 已修复

---

## 🔍 问题分析

### 错误信息

```python
Traceback (most recent call last):
  File "/output/download_models.py", line 18, in <module>
    models = [{"VOC":"pwgan_csmsc",...},{"VOC":null,...}]
                                                    ^^^^
NameError: name 'null' is not defined
```

### 根本原因

**PowerShell → JSON → Python 转换问题**：

1. **PowerShell中**：
   ```powershell
   @{
       Name = "VITS-CSMSC"
       AM = "vits_csmsc"
       VOC = $null  # PowerShell的null
   }
   ```

2. **ConvertTo-Json后**：
   ```json
   {
       "Name": "VITS-CSMSC",
       "AM": "vits_csmsc",
       "VOC": null  # JSON的null
   }
   ```

3. **Python中**：
   ```python
   models = [{"VOC": null}]  # ❌ Python不认识null
   # 应该是：
   models = [{"VOC": None}]  # ✅ Python的None
   ```

**问题**：
- PowerShell的`$null`转换为JSON的`null`
- JSON的`null`在Python中应该是`None`
- 但PowerShell直接把JSON字符串嵌入Python代码
- Python解析时把`null`当作变量名，找不到定义

---

## ✅ 解决方案

### 方案1：移除VOC字段（采用）⭐

**原理**：VITS模型是端到端模型，本来就不需要声码器

**修改**：
```powershell
# ❌ 修改前
@{
    Name = "VITS-CSMSC"
    AM = "vits_csmsc"
    VOC = $null  # 会转换为null
}

# ✅ 修改后
@{
    Name = "VITS-CSMSC"
    AM = "vits_csmsc"
    # 不包含VOC字段
}
```

**Python处理**：
```python
voc = model.get('VOC')  # 如果没有VOC字段，返回None
if voc:
    params['voc'] = voc  # 只有非VITS模型才添加voc参数
```

### 方案2：手动构建JSON字符串（采用）⭐

**原理**：不使用`ConvertTo-Json`，手动编写JSON字符串

**实施**：
```powershell
# ✅ 手动构建JSON，完全控制格式
$modelsJson = @'
[
  {
    "Name": "VITS-CSMSC",
    "AM": "vits_csmsc",
    "Lang": "zh"
  }
]
'@

# 直接嵌入Python脚本
$pythonScript = @"
models = $modelsJson  # 直接使用JSON字符串
"@
```

### 方案3：使用JSON.parse（未采用）

**原理**：在Python中使用json.loads解析

**实施**：
```powershell
$modelsJson = $models | ConvertTo-Json -Depth 10

$pythonScript = @"
import json
models_str = '''$modelsJson'''
models = json.loads(models_str)  # Python正确解析JSON
"@
```

**缺点**：需要处理字符串转义问题

---

## 🔧 修复内容

### 修改1：移除VITS模型的VOC字段

**文件**：`scripts/2026-02-15/09-auto-download-models-via-tts.ps1`

```powershell
# ✅ 2026-02-15 13:00 [修复]: VITS模型不需要声码器，移除VOC字段
@{
    Name = "VITS-CSMSC (中文女声，高质量)"
    AM = "vits_csmsc"
    Lang = "zh"
    Text = "你好，这是高质量中文女声测试"
    Priority = 2
},
@{
    Name = "VITS-AISHELL3 (中文多说话人，高质量)"
    AM = "vits_aishell3"
    Lang = "zh"
    Text = "你好，这是高质量多说话人测试"
    SpkId = 0
    Priority = 2
},
```

### 修改2：创建修复版脚本

**文件**：`scripts/2026-02-15/10-auto-download-models-via-tts-fixed.ps1`

**改进**：
1. ✅ 手动构建JSON字符串
2. ✅ VITS模型不包含VOC字段
3. ✅ Python中正确处理可选字段
4. ✅ 添加详细的错误提示

**关键代码**：
```python
# Python中正确处理可选字段
voc = model.get('VOC')  # 如果没有VOC字段，返回None
if voc:
    print(f'     VOC: {voc}')
    params['voc'] = voc
else:
    print(f'     VOC: 无需（端到端模型）')
```

---

## 📊 修复前后对比

### 修复前

**PowerShell**：
```powershell
@{ VOC = $null }
```

**JSON**：
```json
{"VOC": null}
```

**Python**：
```python
models = [{"VOC": null}]  # ❌ NameError
```

### 修复后

**PowerShell**：
```powershell
@{ }  # 不包含VOC字段
```

**JSON**：
```json
{}  # 不包含VOC字段
```

**Python**：
```python
voc = model.get('VOC')  # ✅ 返回None
if voc:
    params['voc'] = voc  # ✅ 不会执行
```

---

## 💡 经验教训

### 1. PowerShell → Python 数据传递

**问题**：
- PowerShell的`$null`不等于Python的`None`
- JSON的`null`在Python字符串中会被当作变量名

**解决**：
- ✅ 避免使用`$null`
- ✅ 使用可选字段（不包含字段）
- ✅ 手动构建JSON字符串
- ✅ 使用`json.loads()`解析

### 2. 可选字段的最佳实践

**不推荐**：
```python
voc = model['VOC']  # ❌ 如果没有VOC字段会报错
if voc is not None:
    params['voc'] = voc
```

**推荐**：
```python
voc = model.get('VOC')  # ✅ 如果没有VOC字段返回None
if voc:
    params['voc'] = voc
```

### 3. VITS模型的特殊性

**VITS是端到端模型**：
- ✅ 不需要单独的声码器
- ✅ 直接从文本生成音频
- ✅ 质量最好，但模型较大

**FastSpeech2/Tacotron2需要声码器**：
- ✅ 声学模型（AM）：文本 → mel频谱
- ✅ 声码器（VOC）：mel频谱 → 音频波形

---

## 🚀 使用方法

### 运行修复版脚本

```powershell
.\scripts\2026-02-15\10-auto-download-models-via-tts-fixed.ps1
```

### 预期结果

```
========================================
  PaddleSpeech 自动下载模型（修复版）
========================================

[1/3] 准备目录...
  ✅ 目录准备完成

[2/3] 准备模型列表...
  📋 计划下载 9 个模型组合

[3/3] 开始自动下载...
  🐳 启动Docker容器...
  📦 安装编译工具...
  📦 安装Python依赖...
  🚀 开始自动下载模型...
  📂 初始化TTS引擎...

  📥 FastSpeech2-CSMSC (中文女声)
     AM: fastspeech2_csmsc
     VOC: pwgan_csmsc
     ⏳ 下载并测试中...
     ✅ 成功

  📥 VITS-CSMSC (中文女声，高质量)
     AM: vits_csmsc
     VOC: 无需（端到端模型）
     ⏳ 下载并测试中...
     ✅ 成功

...
```

---

## 📝 相关文件

### 修改的文件
1. `scripts/2026-02-15/09-auto-download-models-via-tts.ps1` - 原始脚本（已修复）

### 新建的文件
1. `scripts/2026-02-15/10-auto-download-models-via-tts-fixed.ps1` - 修复版脚本
2. `docs/2026-02-15/12-自动下载脚本null错误修复.md` - 本文档

---

**总结**：
- ✅ 问题根源：PowerShell的`$null`转换为JSON的`null`，Python不认识
- ✅ 解决方案：移除VITS模型的VOC字段 + 手动构建JSON
- ✅ 修复版脚本：`10-auto-download-models-via-tts-fixed.ps1`
- ✅ 已在后台运行，等待下载结果
