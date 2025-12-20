# 待完成任务列表

## 已完成 ✅
1. **Git提交** - 已提交IOCP和UI修复到本地仓库 (commit 7d8c1a9)
   - 远程服务器暂时无法连接,等网络恢复后执行 `git push`

## 进行中任务

### 1. 修复历史记录未记录问题 🔧

**问题**: 通话历史记录没有保存

**原因**:
- `RisipCallHistoryModel` 已存在于Risip SDK中
- 但 `SipPhoneManager` 未集成历史记录功能
- 需要在通话结束时调用 `addCallRecord()`

**解决方案**:
1. 在 `SipPhoneManager::Private` 中添加 `RisipCallHistoryModel`
2. 连接通话状态信号,在通话结束时记录
3. 暴露历史模型给QML
4. 确保历史记录持久化到数据库/文件

---

### 2. 实现多账号管理和配置保存功能 🔧

**问题描述**:
- 目前每次注册都需要手动输入服务器地址、账号、密码
- 无法保存多个SIP账号配置
- 日志显示: `Configs files cannot be found nor be read!!`

**Risip SDK已有功能**:
- `RisipAccountConfiguration` - 账号配置类
- `RisipAccount` - 账号管理
- 原risip示例支持多账号

**需要实现**:
1. **配置文件持久化**:
   ```cpp
   // 使用QSettings保存账号列表
   QSettings settings("BeltControl", "SipPhone");
   settings.setValue("accounts", accountList);
   ```

2. **账号列表UI**:
   - 设置页面添加"账号管理"部分
   - 显示已保存账号列表
   - 添加/删除/编辑账号
   - 选择默认账号

3. **自动登录功能**:
   - 启动时自动加载上次使用的账号
   - 自动注册(如果用户启用)

**文件修改**:
- `src/sip_phone/SipPhoneManager.h/.cpp` - 添加账号管理方法
- `src/qml/components/sip_phone/pages/SipSettingsPage.qml` - UI改进

---

### 3. 修复右上角按钮叠加问题 🔧

**问题**: 注册状态指示器与关闭按钮位置重叠

**当前布局** (SipPhoneWindow.qml):
```
+----------------------------------+
|  SIP电话  [最小化] [关闭]        |  ← 窗口标题栏
+----------------------------------+
|  📞 SIP 电话  [通话中] [已注册]   |  ← SipMainPage 顶部
+----------------------------------+
```

**可能原因**:
1. SipPhoneWindow 有自己的标题栏和关闭按钮
2. SipMainPage 也有顶部栏和状态指示器
3. 两者在z-index或位置上冲突

**解决方案**:
- 检查 `SipPhoneWindow.qml` 和 `SipMainPage.qml` 的布局
- 调整margin/padding确保不重叠
- 或者将关闭按钮移到非重叠位置

---

### 4. 添加视频通话功能 (Windows平台) 📹

**挑战**: PJSIP目前禁用了视频支持

**当前状态**:
- `src/risip/pjsip_stub/pjmedia_vid_dev_stub.c` - 视频设备存根
- `pj/config_site.h` 中可能禁用了视频: `#define PJMEDIA_HAS_VIDEO 0`

**实现步骤**:

#### 步骤1: 重新编译PJSIP启用视频
```makefile
# F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h
#define PJMEDIA_HAS_VIDEO 1  // 启用视频

# 需要视频编解码器支持
#define PJMEDIA_HAS_VID_TOOLBOX_CODEC 0  // macOS only
#define PJMEDIA_VIDEO_DEV_HAS_DSHOW 1     // Windows DirectShow
#define PJMEDIA_VIDEO_DEV_HAS_CBAR_SRC 1  // 测试用彩条
```

#### 步骤2: Windows视频驱动依赖
- DirectShow (Windows自带)
- 或 OpenH264 (需要额外库)
- 确保CMakeLists.txt链接视频库: `libpjmedia-videodev-x86_64-pc-mingw32.a`

#### 步骤3: UI改造
1. 添加视频窗口组件
2. 视频控制按钮(开关摄像头)
3. 本地预览 + 远程视频

#### 步骤4: C++集成
```cpp
// SipPhoneManager中添加
void startVideo();
void stopVideo();
QObject* getLocalVideoSurface();
QObject* getRemoteVideoSurface();
```

---

### 5. 跨平台视频支持预编译配置 🌍

**目标平台**:
- ✅ Windows (x86_64-mingw32)
- 🔜 Linux ARM64 (aarch64-linux-gnu)

**方案**:

#### 方案A: 条件编译
```cmake
if(WIN32)
    set(PJSIP_LIBS_DIR "${CMAKE_SOURCE_DIR}/libs/pjsip/windows-x64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(PJSIP_LIBS_DIR "${CMAKE_SOURCE_DIR}/libs/pjsip/linux-aarch64")
endif()
```

#### 方案B: 预编译库包
```
libs/pjsip/
├── windows-x64/          # Windows MinGW64
│   ├── libpj-*.a
│   └── ...
├── linux-aarch64/        # ARM64 Linux
│   ├── libpj-*.a
│   └── ...
└── README.md             # 编译说明
```

#### ARM64编译流程:
```bash
# 在ARM64 Linux上:
cd /path/to/pjproject
./configure --host=aarch64-linux-gnu
make dep && make
# 复制 */lib/*.a 到项目 libs/pjsip/linux-aarch64/
```

---

## 优先级

1. ⭐⭐⭐ **修复右上角按钮叠加** - UI体验问题
2. ⭐⭐⭐ **多账号配置保存** - 实用功能
3. ⭐⭐ **历史记录修复** - 数据记录
4. ⭐ **视频通话** - 高级功能,需要大量工作
5. ⭐ **跨平台配置** - 为未来部署做准备

---

## 备注

- Git远程仓库地址: `http://192.168.0.60:3000/haochaocheng/belt_control_system.git`
- PJSIP源码位置: `F:\0\pjproject-2.15.1\pjproject-2.15.1`
- 最近一次提交: `7d8c1a9` (本地,未推送)

