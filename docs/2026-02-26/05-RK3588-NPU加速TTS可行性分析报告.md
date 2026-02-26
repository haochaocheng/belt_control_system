# RK3588 NPU 加速 TTS 可行性分析报告

**创建时间**: 2026-02-26 11:30
**分析类型**: 技术可行性评估
**状态**: 📊 分析完成

---

## 📋 背景

### 当前状态
- **设备**: RK3588 (6 TOPS NPU)
- **TTS 引擎**: PaddleSpeech (FastSpeech2 + HiFiGAN)
- **当前运行方式**: CPU (ARM Cortex-A76/A55)
- **性能**: 约 2-3 秒/句

### 目标
评估将 TTS 模型部署到 RK3588 NPU 的可行性，以提升合成速度。

---

## 🔍 技术分析

### 1. RKNN Toolkit2 支持的模型格式

根据 [Firefly Wiki](https://wiki.t-firefly.com/en/3399pro_npu/npu_rknn_toolkit.html) 和 [NPU Programming Guide](https://wiki.youyeetoo.com/en/r1/DCnpu)：

| 格式 | 支持情况 |
|------|----------|
| Caffe | ✅ 支持 |
| TensorFlow | ✅ 支持 |
| TensorFlow Lite | ✅ 支持 |
| ONNX | ✅ 支持 |
| PyTorch | ⚠️ 需先转 ONNX |
| Darknet | ✅ 支持 |
| PaddlePaddle | ❌ 不直接支持 |

### 2. FastSpeech2 模型转换挑战

根据 GitHub Issues 分析：

#### 2.1 ONNX 转换问题
- [FastSpeech2 does not convert to ONNX](https://github.com/TensorSpeech/TensorFlowTTS/issues/501)
- [How FastSpeech2 export onnx?](https://github.com/ming024/FastSpeech2/issues/98)
- [Need help converting FastSpeech model to ONNX](https://github.com/ming024/FastSpeech2/issues/107)

**主要问题**：
1. **动态输入长度** - 文本长度不固定，ONNX 需要特殊处理
2. **不支持的算子** - 部分 PyTorch 算子在 ONNX 中不支持
3. **Attention 机制** - Self-Attention 的动态计算难以转换

#### 2.2 RKNN 动态 Shape 限制
根据 [Using dynamic input shapes on RKNN/RK3588](https://clehaxze.tw/gemlog/2023/12-18-using-dynamic-input-shapes-on-rknn-rk3588.gmi)：

> "RKNN traditionally requires you to specify the input shape of the model during build time. This doesn't work for me as it is really impossible to force sentences to be of a certain length."

**关键限制**：
- RKNN 要求在编译时指定固定输入形状
- TTS 的文本输入长度是动态的
- 需要 padding 到固定长度，影响效率

### 3. TTS 模型架构分析

#### FastSpeech2 架构
```
文本 → Encoder (Transformer) → Variance Adaptor → Decoder (Transformer) → Mel谱
```

#### HiFiGAN 声码器架构
```
Mel谱 → Generator (CNN) → 波形
```

| 组件 | 算子类型 | RKNN 支持 | 难度 |
|------|----------|-----------|------|
| Transformer Encoder | Multi-Head Attention | ⚠️ 有限 | 高 |
| Variance Adaptor | Duration/Pitch/Energy | ⚠️ 复杂 | 高 |
| Transformer Decoder | Multi-Head Attention | ⚠️ 有限 | 高 |
| HiFiGAN Generator | Conv1D, Upsample | ✅ 支持 | 中 |

### 4. 已知成功案例分析

根据搜索结果，RK3588 NPU 成功部署的模型类型：

| 模型类型 | 成功案例 | 特点 |
|----------|----------|------|
| YOLOv5 | ✅ 多个 | 固定输入尺寸 |
| ResNet | ✅ 多个 | 简单 CNN |
| LPRNet | ✅ 有 | 固定输入 |
| OpenPose | ✅ 有 | CNN 为主 |
| **TTS (FastSpeech2)** | ❌ 未找到 | 动态输入 + Transformer |

---

## ⚠️ 主要障碍

### 1. 不可解决的问题

| 问题 | 描述 | 影响 |
|------|------|------|
| **动态输入长度** | TTS 文本长度不固定，RKNN 要求固定 shape | 🔴 致命 |
| **Transformer 支持有限** | RKNN 对 Attention 机制支持不完善 | 🔴 致命 |
| **PaddlePaddle 不支持** | 需要先转 ONNX，增加复杂度 | 🟡 严重 |

### 2. 可能解决但代价高的问题

| 问题 | 解决方案 | 代价 |
|------|----------|------|
| 模型转换 | 重写模型，使用支持的算子 | 工作量巨大 |
| 动态 shape | Padding 到最大长度 | 效率低下 |
| 精度损失 | INT8 量化 | 音质可能下降 |

### 3. 不确定因素

| 因素 | 不确定性 | 风险 |
|------|----------|------|
| 转换后精度 | 未知 | 高 |
| 实际加速比 | 未知 | 中 |
| 音质影响 | 未知 | 高 |
| 调试难度 | 未知 | 高 |

---

## 📊 工作量估算

### 如果强行实施

| 阶段 | 工作内容 | 预估时间 |
|------|----------|----------|
| 1. 模型导出 | PaddlePaddle → ONNX | 1-2 周 |
| 2. 算子适配 | 替换不支持的算子 | 2-4 周 |
| 3. RKNN 转换 | ONNX → RKNN | 1-2 周 |
| 4. 精度调优 | 量化、校准 | 2-4 周 |
| 5. 集成测试 | C++ 集成、性能测试 | 1-2 周 |
| **总计** | | **7-14 周** |

### 成功概率评估

| 场景 | 概率 |
|------|------|
| 完全成功（性能提升 + 音质不变） | 10% |
| 部分成功（性能提升但音质下降） | 30% |
| 失败（无法转换或性能无提升） | 60% |

---

## 🎯 替代方案

### 方案 1：继续使用 CPU（推荐）

**优点**：
- ✅ 已经可用
- ✅ 音质有保证
- ✅ 无额外开发成本

**缺点**：
- ❌ 速度较慢（2-3 秒/句）

**建议**：当前性能对于工业场景已足够，无需优化。

### 方案 2：使用 Sherpa-ONNX

**优点**：
- ✅ 已集成到项目
- ✅ 针对 ARM 优化
- ✅ 支持多种 TTS 模型

**缺点**：
- ❌ 中文模型选择有限

### 方案 3：预生成语音文件

**优点**：
- ✅ 播放速度极快
- ✅ 音质最好
- ✅ 无运行时计算

**缺点**：
- ❌ 不支持动态文本
- ❌ 需要大量存储空间

---

## 📝 结论与建议

### 最终结论

**❌ 不建议实施 NPU 加速**

理由：
1. **技术障碍过大** - 动态输入 + Transformer 架构与 RKNN 不兼容
2. **成功概率低** - 预估只有 10% 概率完全成功
3. **投入产出比差** - 7-14 周工作量，收益不确定
4. **当前方案可用** - CPU 运行已满足工业场景需求

### 建议行动

1. **短期**：继续使用 CPU 运行 PaddleSpeech
2. **中期**：考虑预生成常用语音文件，减少实时合成需求
3. **长期**：关注 RKNN Toolkit 更新，等待 Transformer 支持改善

---

## 📚 参考资料

1. [RKNN Toolkit — Firefly Wiki](https://wiki.t-firefly.com/en/3399pro_npu/npu_rknn_toolkit.html)
2. [NPU Programming Guide](https://wiki.youyeetoo.com/en/r1/DCnpu)
3. [Using dynamic input shapes on RKNN/RK3588](https://clehaxze.tw/gemlog/2023/12-18-using-dynamic-input-shapes-on-rknn-rk3588.gmi)
4. [FastSpeech2 ONNX Issues](https://github.com/ming024/FastSpeech2/issues/98)
5. [RKNN Toolkit2 GitHub](https://github.com/airockchip/rknn-toolkit2)
6. [Rockchip RK3588 NPU Benchmarks](https://tinycomputers.io/posts/rockchip-rk3588-npu-benchmarks.html)

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 11:45
