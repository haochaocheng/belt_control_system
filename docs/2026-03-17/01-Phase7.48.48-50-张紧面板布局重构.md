# Phase 7.48.48~50 张紧传感器配置面板布局重构

## 修改文件
- `src/qml/components/device_info/pages/TensionControlConfigPanel.qml`

## Phase 7.48.48 (2026-03-16)
- rowSpacing 14→8，匹配制动器面板行间距
- 16个字段从 Layout.fillWidth 改为 Layout.preferredWidth: root.fldW（固定120px）

## Phase 7.48.49 (2026-03-17)
- ComboBox（单位/保护类型/模块类型）宽度从 fldW:120 改为 cmbW:160，修复中文截断
- 重构为 ColumnLayout > GridLayout + 分隔线 + RowLayout(语音) + 弹性空间
- 语音字段移出GridLayout，去掉无效的columnSpan

## Phase 7.48.50 (2026-03-17)
- 8列GridLayout改为6列（3对标签+输入框），匹配制动器3列风格
- 启动/停止按钮从顶部移到底部RowLayout
- 新增张紧打开/关闭LED状态指示灯
- ColumnLayout结构完全匹配BrakeConfigPanel（header→margins:10→GridLayout→分隔线→语音→弹性空间→按钮行）
- 清理重复代码（787→563行）

## Phase 7.48.48 完整重写 (2026-03-17 下午)

### 修改文件
- `src/qml/components/device_info/pages/TensionControlConfigPanel.qml` — 完整重写(976→493行)
- `src/qml/components/device_info/pages/TensionControlPage.qml` — 导航数组更新

### 8项修改内容
1. **修改1**: header高度50→40px，content margins 15→10，移除ScrollView包装
2. **修改2**: 新增"传感器启用"Switch在第一行，"使用反馈"Switch在第二行
3. **修改3**: 8列GridLayout，反馈通道和超时向右移动一列（3对标签+输入框+2列填充）
4. **修改4**: 统一输入框宽度fldW:120，标签宽度lblW:130，移除所有Layout.maximumWidth:300
5. **修改5**: Item{columnSpan:2, fillWidth:true}填充，三列平均分配页面宽度
6. **修改6**: 预警语音/失败语音标签字体统一为21px/#9E9E9E
7. **修改7**: buildAudioPath函数验证，启动按钮预警语音→Timer延时→MQTT命令
8. **修改8**: 复制NLTK数据(cmudict+averaged_perceptron_tagger)到linaro@192.168.10.151

### 导航数组更新
- 旧: `[[0,2],[2,3],[5,4],[9,4],[13,4],[17,1],[18,2]]` (20个参数)
- 新: `[[0,2],[2,2],[4,3],[7,3],[10,3],[13,2],[15,2]]` (17个参数，索引0-16)
- 按钮区Up返回索引: 19→16

### 参数布局(focusParamIndex)
| 行 | 参数 |
|---|---|
| 0 | 名称(0), 单位(1) |
| 1 | 反馈通道(2), 超时(3) |
| 2 | 输入类型(4), 模块类型(5), 寄存器地址(6) |
| 3 | 保护延时(7), 上限值(8), 量程(9) |
| 4 | 额定值(10), 播放次数(11), 播放时长(12) |
| 5 | TTS文本(13) / 音频文件(14) |
| 6 | 预警语音(15), 失败语音(16) |

## 参照
- BrakeConfigPanel.qml: ColumnLayout + GridLayout(8列) + RowLayout(语音) + RowLayout(LED+按钮)
