# 视频通话功能测试指南

## 已完成的修复

### 修复 1：cap_id=-1 Bug（上一个会话完成）
**问题**：PJSIP 源码在创建视频窗口时硬编码 `cap_id=-1`，导致无法找到捕获设备
**修复位置**：`F:\0\pjproject-2.15.1\pjproject-2.15.1\pjsip\src\pjsua-lib\pjsua_vid.c:1224`
**修复内容**：将 `PJSUA_INVALID_ID` 改为 `call_med->strm.v.cap_dev`（使用账户配置的捕获设备）
**验证状态**：✅ 已通过运行日志确认生效（cap_id 从 -1 变为 0）

### 修复 2：缺失渲染设备（本次会话完成）
**问题**：系统只有捕获设备（Integrated Webcam，Dir=1），没有渲染设备（Dir=2），导致错误：
```
Unable to find default video device (PJMEDIA_EVID_NODEFDEV)
```

**根本原因**：SDL2 渲染器在 PJSIP 配置中被禁用

**修复位置**：`F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h`
**修复内容**：启用 SDL2 支持
```c
// 修改前
#define PJMEDIA_VIDEO_DEV_HAS_SDL2 0   // SDL2 disabled

// 修改后
#define PJMEDIA_VIDEO_DEV_HAS_SDL2 1   // SDL2 enabled for video RENDERING
```

**已完成的编译步骤**：
1. ✅ 启用 SDL2 配置
2. ✅ 清理旧的视频设备库文件
3. ✅ 重新编译 PJSIP 库（包含 SDL2 渲染器支持）
4. ✅ 复制 20 个更新后的库文件到应用程序
5. ✅ 重新编译应用程序（28MB，编译时间 1分2秒）

---

## 测试步骤

### 第一步：运行应用程序并检查设备枚举

**期望结果**：启动日志应该显示 SDL2 渲染设备已被识别

#### 操作：
1. 双击运行：`E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe`
2. 在启动日志中查找 "RisipEndpoint: Total video devices:" 部分

#### 预期日志输出：
```
RisipEndpoint: Total video devices: 2  ← 应该从 1 变为 2（或更多）
  Device 0 : Integrated Webcam | Dir: 1 | Driver: DSHOW    ← 捕获设备
  Device 1 : SDL2 renderer | Dir: 2 | Driver: SDL2        ← 新增的渲染设备
  ✅ Selected 0 as default capture device: Integrated Webcam
```

**注意**：设备顺序可能不同，关键是要看到：
- 至少一个 Dir:1（CAPTURE）设备
- 至少一个 Dir:2（RENDER）设备，Driver 应该是 "SDL2"

#### 如果没有看到 SDL2 设备：
说明 SDL2 库未正确加载，需要检查：
1. SDL2.dll 是否在系统路径中：`C:\video_deps\SDL2-2.28.5\lib\x64\SDL2.dll`
2. 可能需要将 SDL2.dll 复制到应用程序目录：
   ```bash
   cp C:/video_deps/SDL2-2.28.5/lib/x64/SDL2.dll E:/2025/3_gongkongji/belt_control_system/build/bin_windows/
   ```

---

### 第二步：配置 SIP 账户

1. 在应用程序界面中，进入 SIP 设置页面
2. 输入 SIP 服务器信息（如果还没有配置）：
   - SIP 服务器地址
   - 用户名
   - 密码
   - 端口（默认 5060）
3. 点击"注册"或"登录"
4. 等待注册成功（服务器状态显示"已连接"）

---

### 第三步：发起视频通话测试

#### 操作：
1. 在拨号界面输入对方的 SIP 号码
2. 点击"视频通话"按钮（不是普通的音频通话按钮）
3. 观察日志输出和界面反应

#### 预期日志输出（成功案例）：
```
✅ Making call to: sip:1002@192.168.1.100 (Video)
✅ Refreshing video device configuration before call for: sip:1001@192.168.1.100
  Account 0 video device configured: vid_cap_dev=0
✅ Using real capture device ID from VideoCallManager: 0
✅ Creating video call with PJSIP API (video in initial INVITE)
✅ Found account ID: 0 for URI: sip:1001@192.168.1.100
✅ Calling pjsua_call_make_call with vid_cnt=1 to: sip:1002@192.168.1.100
✅ Video call created with ID: 0

// 通话建立后，应该看到视频窗口创建日志：
Creating video window: type=stream, cap_id=0, rend_id=-2
  ← 这里应该成功，不再报错 "Unable to find default video device"

Window 1 created  ← 成功创建视频窗口
```

#### 预期失败日志（如果还有问题）：
```
❌ pjsua_call_make_call failed: [错误信息]
🔄 Retrying with audio-only call as fallback
```

---

### 第四步：验证视频流

如果通话成功建立：

1. **本地视频预览**：
   - 应该能看到自己摄像头的画面
   - 位置：通话界面的预览窗口

2. **远程视频接收**：
   - 如果对方也启用视频，应该能看到对方的画面
   - 位置：通话界面的主视频窗口

3. **视频控制**：
   - 测试关闭/开启摄像头按钮
   - 测试切换摄像头功能（如果有多个摄像头）

---

## 故障排查

### 问题 1：仍然报错 "Unable to find default video device"

**可能原因**：
1. SDL2.dll 未加载
2. PJSIP 库未正确重新编译
3. 应用程序使用的是旧的库文件

**解决方法**：
```bash
# 1. 检查 SDL2.dll
ls -lh C:/video_deps/SDL2-2.28.5/lib/x64/SDL2.dll

# 2. 复制 SDL2.dll 到应用程序目录
cp C:/video_deps/SDL2-2.28.5/lib/x64/SDL2.dll E:/2025/3_gongkongji/belt_control_system/build/bin_windows/

# 3. 验证 PJSIP 库是否包含 SDL2 支持
strings E:/2025/3_gongkongji/belt_control_system/libs/pjsip/libpjmedia-videodev-x86_64-w64-mingw32.a | grep -i sdl2
```

### 问题 2：视频窗口不显示

**可能原因**：
- SDL2 渲染器初始化失败
- 窗口句柄未正确传递给 PJSIP

**调试方法**：
查看日志中的：
```
Creating video window: type=stream, cap_id=X, rend_id=Y
```
- `cap_id` 应该是 0（Integrated Webcam）
- `rend_id` 应该是 -2（自动选择默认渲染器）或具体的 SDL2 设备 ID

### 问题 3：音频通话正常，但视频通话失败

**可能原因**：
- 账户配置中的视频设备未正确设置
- SDP 协商失败

**调试方法**：
检查 `SipPhoneManager::configureAccountVideoDevice()` 是否被调用，日志应显示：
```
✅ Account 0 video device configured: vid_cap_dev=0
```

---

## 技术说明

### 为什么需要 SDL2？

PJSIP 的视频子系统需要两类设备：
1. **捕获设备（Capture Device）**：从摄像头获取视频（本例：DirectShow 驱动的 Integrated Webcam）
2. **渲染设备（Render Device）**：显示视频画面到屏幕（本例：SDL2 渲染器）

在 Windows 上：
- DirectShow 只提供捕获能力（Dir=1）
- SDL2 提供渲染能力（Dir=2）
- 两者配合才能实现完整的视频通话

### 修复的两个 Bug

#### Bug 1：cap_id=-1（源码级别）
**PJSIP 官方代码问题**：`pjsua_vid.c:1224` 硬编码 `PJSUA_INVALID_ID`（即 -1）作为捕获设备 ID

**错误机制**：
```c
// 官方代码（错误）
status = create_vid_win(PJSUA_WND_TYPE_STREAM,
                        &media_port->info.fmt,
                        call_med->strm.v.rdr_dev,  // 渲染设备（正确）
                        PJSUA_INVALID_ID,          // ❌ 硬编码 -1（错误）
                        ...);
```

**修复后**：
```c
// 修复后的代码
status = create_vid_win(PJSUA_WND_TYPE_STREAM,
                        &media_port->info.fmt,
                        call_med->strm.v.rdr_dev,    // 渲染设备
                        call_med->strm.v.cap_dev,    // ✅ 使用账户配置的捕获设备
                        ...);
```

#### Bug 2：缺失渲染设备（配置问题）
**问题**：`config_site.h` 中 SDL2 被禁用，导致系统只有捕获设备，没有渲染设备

**错误流程**：
1. PJSIP 尝试查找默认渲染设备（rend_id=-2）
2. 调用 `lookup_dev(-2)` 查找 `PJMEDIA_VID_DEFAULT_RENDER_DEV`
3. 遍历所有驱动，查找 `drv->rend_dev_idx >= 0` 的驱动
4. 只有 DirectShow 驱动（只提供捕获，`rend_dev_idx=-1`）
5. 没有找到任何渲染设备
6. 返回错误：`PJMEDIA_EVID_NODEFDEV`（520006）

**修复后**：
- SDL2 驱动被编译进 PJSIP
- SDL2 提供渲染设备（`rend_dev_idx >= 0`）
- `lookup_dev(-2)` 能找到 SDL2 渲染器
- 视频窗口创建成功

---

## 预期测试结果总结

✅ **成功标志**：
1. 启动日志显示至少 2 个视频设备（1 个捕获 + 1 个渲染）
2. 视频通话拨号时日志显示 "✅ Video call created with ID: X"
3. 通话建立后日志显示 "Window 1 created"
4. 界面上能看到本地和远程视频画面

❌ **失败标志**：
1. 只有 1 个视频设备（只有 Integrated Webcam）
2. 日志仍然报错 "Unable to find default video device"
3. 通话建立后没有视频窗口创建
4. 界面上看不到视频画面

---

## 联系我

如果测试过程中遇到任何问题，请提供：
1. 完整的启动日志（特别是设备枚举部分）
2. 视频通话拨号时的日志
3. 任何错误消息的完整文本
4. 界面截图（如果有）

祝测试顺利！🎉
