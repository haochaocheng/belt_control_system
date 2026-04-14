# Phase 7.48.88.137-142 集控收尾修复 + Mosquitto 本机部署

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix + feat

---

## 修复总览

| Phase | 提交 | 类型 | 内容 |
|---|---|---|---|
| 7.48.88.137 | 84dae2b | fix | Component.onCompleted 重复定义编译错误 |
| 7.48.88.138 | 44e10d0 | fix | 集控配置 appdata 持久化——重新部署不丢失 |
| 7.48.88.139 | e6c4c55 | feat | 每台设备自带 Mosquitto——解决多设备 Client ID 冲突 |
| 7.48.88.140 | 6a2f2b4 | fix | Luckfox 5台设备 SSH 改 MQTT Broker 地址 |
| 7.48.88.141 | 98c03c1 | fix | Mosquitto 移至基础层——避免每次重编译安装 |
| 7.48.88.142 | 87565d5 | fix | 集控分站通信三项修复 |
| 7.48.88.142 | ca2626d | fix | gzip 命令在 Windows 不可用 |

---

## Phase 7.48.88.137 修复 Component.onCompleted 重复定义

**问题**：编译报错：
```
CentralControlPage.qml:304:5: error: Property value set multiple times
```

**原因**：Phase 7.48.88.135 新增了第一个 `Component.onCompleted`（第 47 行）用于初始化 `mqttModule7Connected`，与原有第 304 行冲突。QML 中同一对象只能有一个 `Component.onCompleted`。

**修复**：删除第 47 行多余的 `Component.onCompleted`，将初始化代码合并到原有的处理器中。

**文件**：`src/qml/components/device_info/pages/CentralControlPage.qml`

---

## Phase 7.48.88.138 集控配置 appdata 持久化

**问题**：集控管理保存 IP 等配置后，重新部署容器配置恢复为空。

**根本原因**：`CentralizedControlManager` 使用 `QSettings("BeltControl", "CentralizedControl")` 保存到容器内 `~/.config/`，容器重新部署时被清除。

```cpp
// 旧（容器重启丢失）
QSettings("BeltControl", "CentralizedControl")
→ ~/.config/BeltControl/CentralizedControl.conf

// 新（持久化）
QSettings(DataPathConfig::getDataDirectory() + "/centralized_control.ini", IniFormat)
→ /app/appdata/centralized_control.ini（Docker volume 挂载到宿主机）
```

**参考**：`DeviceRoleManager.cpp` Phase 7.48.88.18 的同类修复。

**文件**：`src/control/CentralizedControlManager.cpp`

---

## Phase 7.48.88.139 每台设备自带 Mosquitto——解决多设备 Client ID 冲突

**问题**：两台设备连接同一 EMQX Broker，MQTT 模块 Client ID 相同互相踢下线，日志现象：所有模块每 4 秒全部断开再重连。

**根本原因**：
```
EMQX Broker (192.168.10.142)
  ├── 设备1 → belt_control_module_1 ~ belt_control_module_7
  └── 设备2 → belt_control_module_1 ~ belt_control_module_7  ← 冲突！
```

MQTT 规定：同一 Broker 上 Client ID 必须全局唯一。两台设备连进来用同一套 ID，Broker 踢先来的，先来的立刻重连又踢后来的，无限循环。

**方案**：每台设备自带本机 Mosquitto Broker，模块 0-6 连本机 `127.0.0.1`，各自独立。

**三处修改**：

1. **Dockerfile.ubuntu24-apt** — 安装 Mosquitto + 生成配置（监听 `0.0.0.0:1883`）
2. **app-entrypoint.sh** — 应用启动前先 `mosquitto -d`
3. **MQTTController.cpp** — 默认 brokerHost `192.168.10.142` → `127.0.0.1`（3处）

**最终架构**：
```
每台设备（批量生产，配置相同）
┌──────────────────────────────┐
│ Mosquitto:127.0.0.1:1883     │
│   ↑                          │
│   模块0-6（DI/AI/DO/CS采集） │  ← 各自独立，无 Client ID 冲突
│                              │
│   模块7（集控专用）──────────┼→ 主站 Mosquitto（单独配置 IP）
└──────────────────────────────┘
```

---

## Phase 7.48.88.140 Luckfox 5台设备 SSH 改 MQTT Broker 地址

**背景**：5台 Luckfox Lyra RK3506 模块设备（DI/AI/CS）通过 WiFi 连接，MQTT Broker 地址还是旧的 `192.168.10.142`（开发机），需要改为 `192.168.10.151`（皮带控制设备）。

**操作**：通过 Python paramiko 库 SSH 逐台进入设备，用 SFTP 读写文件方式替换 BROKER 地址，并重启脚本。

**设备一览**：

| 设备 | WiFi IP | 脚本 | 密码 | 特殊情况 |
|---|---|---|---|---|
| 设备1 | 192.168.10.177 | `mqtt_di_publisher.py` | luckfox | - |
| 设备2 | 192.168.10.119 | `mqtt_di_publisher.py` | luckfox | - |
| 设备3 | 192.168.10.101 | `mqtt_ai_publisher.py` | luckfox | - |
| 设备4 | 192.168.10.235 | `mqtt_cs_publisher.py` | luckfox | - |
| 设备5 | 192.168.10.140 | `mqtt_ai_publisher.py` | **root** | 双进程问题 |

**设备5 额外问题**：同时存在 `/etc/init.d/S98mqtt_ai` 和 `/etc/systemd/system/mqtt-ai.service` 两套启动机制，导致两个 Python 进程同时运行，互相用相同 `luckfox-ai-module-2` Client ID 踢下线。解决：禁用 systemd service：
```bash
systemctl stop mqtt-ai
systemctl disable mqtt-ai
```

**注意**：设备3 须用 SFTP 直接读写文件，sed 命令在该设备上不生效。

---

## Phase 7.48.88.141 Mosquitto 移至基础层

**问题**：每次编译应用层（约每天一次）都要重新执行 `apt-get install mosquitto`（约 30 秒），浪费时间。

**原因**：Mosquitto 放在了应用层 `Dockerfile.ubuntu24-apt`，应用层每次代码更新都重建。

**修复**：将 Mosquitto 安装移至基础层 `Dockerfile.ubuntu24-base`：
- 基础层：只在 `Dockerfile.ubuntu24-base` 或 Python 依赖变化时才重建
- 应用层：保留 Mosquitto 配置文件生成（< 1 秒，无网络操作）

**效果**：日常应用层编译不再安装 Mosquitto，节省 30 秒/次。

---

## Phase 7.48.88.142（1）集控分站通信三项修复

**背景**：两台设备 151（主站）和 186（分站2）配置好后，主站分站管理仍显示"未配置"，分站状态无法同步。

**三处根本原因**：

### 问题1：findSlotByDeviceId key 不匹配
```cpp
// 主站配置时存的 key 是 "targetDeviceId"
centralControlManager.setSlotParam(slotIndex, "targetDeviceId", value)

// 但 findSlotByDeviceId 读的 key 是 "deviceId"
int slotDevId = m_slots[i].protocolParams.value("deviceId", -1).toInt();
```
结果：收到分站2发来的状态消息，找不到对应槽位，消息被丢弃。

**修复**：`findSlotByDeviceId` 改为读 `"targetDeviceId"`。

### 问题2：分站 enterSubStationMode 未配置模块7 Broker 地址
```cpp
// 分站进入sub模式后，模块7需要连接"主站的MQTT地址"
// 但代码只调用 connectToModule(7) 连接默认 Broker（127.0.0.1）
// 而未将模块7的 Broker 更新为主站 IP
```
**修复**：`enterSubStationMode()` 中，将模块7的 brokerHost 设为 `m_mqttBrokerIP`（集控配置的主站 MQTT 地址）。

### 问题3：loadConfig() 不触发模式切换
```cpp
// 构造函数中：
loadConfig()  // 读取 stationRole = "sub"
// 但模式切换逻辑（enterSubStationMode）不会被调用
// 需要外部调用 setStationRole() 才能触发
```
**修复**：新增 `activateLoadedRole()` 方法，在依赖注入完成后由 `main.cpp` 调用，自动根据已保存的角色激活对应模式（master/sub）。

---

## Phase 7.48.88.142（2）gzip 命令在 Windows 不可用

**问题**：`build-ubuntu24-apt.ps1` 基础镜像备份时报错：
```
gzip: The term 'gzip' is not recognized...
```

**原因**：`docker save $id | gzip > backup.tar.gz` 使用了 Unix 命令 `gzip`，Windows PowerShell 无此命令。

**修复**：改用 `docker save -o backup.tar $id`（Docker 原生参数，跨平台兼容）。

---

## 今日关键经验补充

6. **QSettings 保存路径**：Docker 容器内 `~/.config/` 在重新部署时丢失，必须使用 `DataPathConfig::getDataDirectory()`（即 `/app/appdata/`，通过 Volume 挂载到宿主机）

7. **批量生产设备的 MQTT 架构**：每台设备自带轻量级 Mosquitto，模块连本机 `127.0.0.1`，集控模块单独配置主站 IP，彻底解决 Client ID 冲突

8. **SSH 远程修改文件**：当 sed 不可用时，用 Python paramiko + SFTP 直接读写文件是可靠的替代方案

9. **Qt.callLater 不能赋值绑定属性**：Qt.callLater 中对 `item.focusSubArea = value` 会永久破坏 `Qt.binding`，只能通过修改源属性（`root.focusSubArea`）间接更新

10. **PowerShell 无 Unix 命令**：构建脚本中不能使用 `gzip`、`grep` 等 Unix 命令，需用 PowerShell 原生或 Docker 参数代替
