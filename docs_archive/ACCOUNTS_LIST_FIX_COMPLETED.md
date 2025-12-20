# 已保存账户列表显示问题 - 修复完成

## 修复时间
2025-11-28 17:04

## 问题描述
1. **主要问题**: 已保存的 SIP 账户在"设置"页面的账户列表中显示为空
   - C++ 模型中有账户数据 (count: 1)
   - QML ListView 显示 "暂无保存的账号"

2. **次要问题**: Qt 虚拟键盘显示过大,无法使用

## 根本原因分析

### 1. QML 可见性循环依赖
```qml
// 错误代码 (原来的实现)
Rectangle {
    visible: accountsListView.count > 0  // ❌ 循环依赖!

    ListView {
        id: accountsListView
        model: accountsModel
    }
}
```

**问题**:
- ListView 的父容器只有在 count > 0 时才可见
- 但如果父容器不可见,ListView 不会初始化
- ListView 不初始化,model 绑定不生效
- count 永远是 0
- 死循环!

### 2. Q_INVOKABLE vs Q_PROPERTY
```qml
// 错误代码
property var accountsModel: SipPhoneManager.getAllAccountsModel()
model: accountsModel
```

**问题**: 使用函数调用无法让 QML 监控 C++ 模型的变化,需要使用 Q_PROPERTY

### 3. endInsertColumns() 错误
```cpp
// risipaccountlistmodel.cpp:165
endInsertColumns();  // ❌ 错误! 应该是 endInsertRows()
```

**问题**: 使用 beginInsertRows() 但用 endInsertColumns() 结束,导致 Qt 模型系统状态不一致

## 已完成的修复

### 修复 1: 添加 Q_PROPERTY (SipPhoneManager.h)
```cpp
// Line 31: 新增属性
Q_PROPERTY(QObject* accountsModel READ accountsModel NOTIFY accountsModelChanged)

// Line 48: 新增 getter
QObject* accountsModel() const;

// Line 96: 新增信号
void accountsModelChanged();
```

### 修复 2: 实现 accountsModel getter (SipPhoneManager.cpp:162-179)
```cpp
QObject* SipPhoneManager::accountsModel() const
{
    if (!d->risipInstance) {
        qDebug() << "[DEBUG] accountsModel() called but risipInstance is null";
        return nullptr;
    }

    QObject* model = d->risipInstance->allAccountsModel();
    if (model) {
        QAbstractItemModel* itemModel = qobject_cast<QAbstractItemModel*>(model);
        if (itemModel) {
            qDebug() << "[DEBUG] accountsModel() returning model with"
                     << itemModel->rowCount() << "accounts";
        }
    } else {
        qDebug() << "[DEBUG] accountsModel() returning nullptr";
    }
    return model;
}
```

### 修复 3: 修正 endInsertRows (risipaccountlistmodel.cpp:165)
```cpp
// 修复前
endInsertColumns();  // ❌

// 修复后
endInsertRows();  // ✅
```

### 修复 4: 修复 QML 可见性和绑定 (SipSettingsPage.qml:274-319)
```qml
Rectangle {
    Layout.fillWidth: true
    implicitHeight: Math.max(accountsListView.contentHeight + 40, 100)
    visible: true  // ✅ 修复: 始终可见,不再依赖 count
    color: "#0f3460"
    radius: 10
    border.color: "#00d4ff"
    border.width: 1

    ListView {
        id: accountsListView
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        clip: true

        // ✅ 修复: 使用 Q_PROPERTY 而不是函数调用
        model: SipPhoneManager.accountsModel

        Component.onCompleted: {
            console.log("[QML] ListView initialized, model:", model)
            console.log("[QML] Model count:", count)
        }

        delegate: Rectangle {
            width: accountsListView.width
            height: 60
            color: "#1a4d7a"
            radius: 8
            border.color: index === 0 ? "#00d4ff" : "#2980b9"
            border.width: index === 0 ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: model.uri || "未知账户"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: model.serverAddress || "未知服务器"
                        font.pixelSize: 11
                        color: "#95a5a6"
                    }
                }

                Rectangle {
                    visible: index === 0
                    width: 60
                    height: 25
                    color: "#27ae60"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "默认"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#ffffff"
                    }
                }
            }
        }

        // ✅ 修复: 空状态提示放在 ListView 内部
        Text {
            anchors.centerIn: parent
            visible: accountsListView.count === 0
            text: "暂无保存的账号,请先注册一个账户"
            font.pixelSize: 14
            color: "#95a5a6"
        }
    }
}
```

### 修复 5: 扩展模型字段 (risipaccountlistmodel.h:35-43)
```cpp
enum RisipAccountListDataRole {
    AccountURI = Qt::UserRole + 1,
    UserName,
    Password,
    Uri,              // ✅ 新增: QML 兼容别名
    Username,         // ✅ 新增: QML 兼容别名
    ServerAddress,    // ✅ 新增: 服务器地址
    IsDefault         // ✅ 新增: 是否默认账户
};
```

### 修复 6: 禁用虚拟键盘 (SipPhoneWindow.qml:151-158)
```qml
// Virtual keyboard disabled - using system keyboard
// InputPanel {
//     id: inputPanel
//     ...
// }
```

### 额外功能: 自动登录开关 (SipSettingsPage.qml:198-264)
按照用户要求,在设置页面添加了自动登录选项:

```qml
Rectangle {
    Layout.fillWidth: true
    height: 70
    color: "#0f3460"
    radius: 10
    border.color: "#00d4ff"
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "应用启动时自动登录"
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
            }

            Text {
                text: "启用后应用启动时将自动注册已保存的账户"
                font.pixelSize: 12
                color: "#95a5a6"
            }
        }

        Switch {
            id: autoLoginSwitch
            checked: SipPhoneManager.getAutoSignIn()

            onToggled: {
                SipPhoneManager.setAutoSignInEnabled(checked)
                console.log("Auto-login toggled:", checked)
            }

            indicator: Rectangle {
                implicitWidth: 48
                implicitHeight: 26
                radius: 13
                color: autoLoginSwitch.checked ? "#27ae60" : "#7f8c8d"
                border.color: autoLoginSwitch.checked ? "#2ecc71" : "#95a5a6"
                border.width: 2

                Rectangle {
                    x: autoLoginSwitch.checked ? parent.width - width - 3 : 3
                    y: 3
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"

                    Behavior on x {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
        }
    }
}
```

## 测试计划

### 步骤 1: 启动应用
```bash
cd e:\2025\3_gongkongji\belt_control_system\build\bin_windows
belt_control_system.exe
```

### 步骤 2: 打开 SIP 电话窗口
点击主界面的 "SIP电话" 按钮

### 步骤 3: 切换到设置页面
点击底部导航的 "设置" 标签 (最右边)

### 步骤 4: 验证账户列表显示
**预期结果**:
- ✅ 应该看到已保存的账户 (账号: 1000)
- ✅ 账户显示服务器地址
- ✅ 第一个账户标记为 "默认"
- ✅ 控制台输出: `[DEBUG] accountsModel() returning model with 1 accounts`
- ✅ 控制台输出: `[QML] ListView initialized`

### 步骤 5: 验证自动登录开关
**预期结果**:
- ✅ 在账户列表上方看到 "应用启动时自动登录" 开关
- ✅ 可以切换开关状态
- ✅ 控制台输出: `Auto-login toggled: true/false`
- ✅ 控制台输出: `Auto sign-in preference saved`

### 步骤 6: 测试账户注册
1. 在 "拨号" 页面输入账号 1001
2. 点击 "注册账户"
3. 返回 "设置" 页面
4. **预期**: 看到两个账户 (1000 和 1001)

## 编译信息
```
编译时间: 2025-11-28 17:04
可执行文件: build/bin_windows/belt_control_system.exe
文件大小: 14MB

编译输出:
[ 94%] Building CXX object src/qml/.../SipSettingsPage_qml.cpp.obj
[ 95%] Running rcc for resource qmake_BeltControlQml
[ 96%] Building CXX object src/qml/.../qrc_qmake_BeltControlQml.cpp.obj
[100%] Linking CXX executable belt_control_system.exe
[100%] Built target belt_control_system
```

## 调试日志说明

### C++ 端日志
启动应用后,在控制台应该看到:
```
[DEBUG] SipPhoneManager created
[DEBUG] Risip SDK initialized successfully
[DEBUG] RisipAccountListModel::addSipAccount() - Before add, count: 0
[DEBUG]   Adding account URI: 1000
[DEBUG]   Server address: 192.168.1.100:5060
[DEBUG] RisipAccountListModel::addSipAccount() - After add, count: 1
[DEBUG]   Total accounts in hash: 1
```

### QML 端日志
切换到设置页面时,应该看到:
```
[DEBUG] accountsModel() returning model with 1 accounts
[QML] ListView initialized, model: RisipAccountListModel(...)
[QML] Model count: 1
```

如果看到 count: 0,说明:
1. 账户未保存到配置文件
2. 配置文件加载失败
3. 模型数据丢失

## 相关文件修改清单

### C++ 文件
1. [src/sip_phone/SipPhoneManager.h](src/sip_phone/SipPhoneManager.h) - 添加 Q_PROPERTY
2. [src/sip_phone/SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp) - 实现 accountsModel()
3. [src/risip/models/risipaccountlistmodel.cpp](src/risip/models/risipaccountlistmodel.cpp) - 修复 endInsertRows
4. [src/risip/core/models/risipaccountlistmodel.h](src/risip/core/models/risipaccountlistmodel.h) - 扩展字段枚举

### QML 文件
1. [src/qml/components/sip_phone/pages/SipSettingsPage.qml](src/qml/components/sip_phone/pages/SipSettingsPage.qml) - 修复可见性和绑定
2. [src/qml/components/sip_phone/SipPhoneWindow.qml](src/qml/components/sip_phone/SipPhoneWindow.qml) - 禁用虚拟键盘

## 技术要点

### Qt Model/View 架构
- 必须正确调用 beginInsertRows/endInsertRows 配对
- 修改数据后必须 emit layoutChanged()
- QML 绑定需要 Q_PROPERTY 而不是 Q_INVOKABLE

### QML 属性绑定
- `property var x: func()` - 只调用一次,无响应
- `property var x: objectProperty` - 响应式绑定 ✅

### QML 可见性
- visible 属性影响组件初始化
- 避免 visible 依赖子组件状态 (循环依赖)

## 下一步
如果测试发现账户列表仍然为空:
1. 检查控制台是否有 `[DEBUG] accountsModel()` 输出
2. 检查 `[QML] ListView initialized` 是否出现
3. 检查账户数据是否保存到配置文件
4. 提供完整的控制台日志用于分析

---
**状态**: ✅ 所有代码修复已完成并编译通过
**下一步**: 用户测试并提供反馈
