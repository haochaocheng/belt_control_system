# 多账号管理支持 - 实现完成

## 日期
2025-11-28

## 已完成功能

### C++后端支持

在 [SipPhoneManager.h:64-67](src/sip_phone/SipPhoneManager.h#L64-L67) 和 [SipPhoneManager.cpp:403-451](src/sip_phone/SipPhoneManager.cpp#L403-L451) 添加了三个新方法:

#### 1. getAllAccountsModel()

```cpp
QObject* SipPhoneManager::getAllAccountsModel()
```

**功能**: 返回Risip的账号列表模型,可在QML中作为ListView的model使用

**使用**:
```qml
ListView {
    model: SipPhoneManager.getAllAccountsModel()
    delegate: ItemDelegate {
        text: model.uri  // sip:1000@192.168.10.243
        // model roles: uri, username, serverAddress, etc.
    }
}
```

#### 2. removeAccount(accountUri)

```cpp
bool SipPhoneManager::removeAccount(const QString &accountUri)
```

**功能**: 删除指定账号并自动保存配置

**使用**:
```qml
Button {
    text: "删除"
    onClicked: {
        SipPhoneManager.removeAccount("sip:1000@192.168.10.243")
    }
}
```

#### 3. setAsDefaultAccount(accountUri)

```cpp
bool SipPhoneManager::setAsDefaultAccount(const QString &accountUri)
```

**功能**: 将指定账号设为默认(启动时自动登录)

**使用**:
```qml
Button {
    text: "设为默认"
    onClicked: {
        SipPhoneManager.setAsDefaultAccount("sip:1000@192.168.10.243")
    }
}
```

## 下一步: UI实现

您可以在 `SipSettingsPage.qml` 中添加账号列表和选择功能。

### 方案1: 账号选择下拉框

在服务器地址输入框上方添加:

```qml
ColumnLayout {
    spacing: 10

    Text {
        text: "已保存的账号:"
        color: "#ffffff"
    }

    ComboBox {
        id: accountSelector
        Layout.fillWidth: true
        model: SipPhoneManager.getAllAccountsModel()
        textRole: "uri"  // 显示 sip:1000@192.168.10.243

        onCurrentIndexChanged: {
            if (currentIndex >= 0) {
                var accountModel = SipPhoneManager.getAllAccountsModel()
                // 填充表单
                var serverAddr = accountModel.data(accountModel.index(currentIndex, 0), /* ServerAddressRole */ 260)
                var username = accountModel.data(accountModel.index(currentIndex, 0), /* UsernameRole */ 261)

                // 解析服务器和端口
                var parts = serverAddr.split(":")
                serverInput.text = parts[0]
                if (parts.length > 1) {
                    portInput.text = parts[1]
                }
                usernameInput.text = username
            }
        }
    }

    // 或者新建账号按钮
    Button {
        text: "新建账号"
        onClicked: {
            // 清空表单
            accountSelector.currentIndex = -1
            serverInput.text = ""
            usernameInput.text = ""
            passwordInput.text = ""
        }
    }
}
```

### 方案2: 账号列表(更直观)

```qml
ColumnLayout {
    Text {
        text: "已保存的账号:"
        color: "#ffffff"
        font.bold: true
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        model: SipPhoneManager.getAllAccountsModel()
        clip: true

        delegate: ItemDelegate {
            width: ListView.view.width
            height: 60

            background: Rectangle {
                color: ListView.isCurrentItem ? "#2980b9" : "#0f3460"
                border.color: "#00d4ff"
                border.width: 1
                radius: 5
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Column {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: model.uri
                        color: "#ffffff"
                        font.bold: true
                    }

                    Text {
                        text: "服务器: " + model.serverAddress
                        color: "#95a5a6"
                        font.pixelSize: 12
                    }
                }

                Button {
                    text: "使用"
                    onClicked: {
                        // 填充表单
                        var parts = model.serverAddress.split(":")
                        serverInput.text = parts[0]
                        portInput.text = parts.length > 1 ? parts[1] : "5060"
                        usernameInput.text = model.username
                        // 密码不显示
                    }
                }

                Button {
                    text: "删除"
                    onClicked: {
                        SipPhoneManager.removeAccount(model.uri)
                    }
                }

                Button {
                    text: model.isDefault ? "★默认" : "设为默认"
                    enabled: !model.isDefault
                    onClicked: {
                        SipPhoneManager.setAsDefaultAccount(model.uri)
                    }
                }
            }
        }
    }
}
```

## 账号模型的数据角色 (Roles)

Risip的账号模型提供以下数据:

- `uri` - SIP URI (如 "sip:1000@192.168.10.243")
- `username` - 用户名
- `serverAddress` - 服务器地址:端口
- `isDefault` - 是否为默认账号(布尔值)
- 其他字段: password, proxyServer, etc.

## 工作流程

### 添加新账号
1. 用户输入服务器、用户名、密码
2. 点击"注册"
3. `registerAccount()` 调用 `createAccount()` 和 `saveSettings()`
4. 新账号自动出现在列表中

### 切换账号
1. 用户从下拉框或列表选择账号
2. 自动填充表单
3. 点击"注册"使用该账号登录

### 删除账号
1. 用户点击账号旁的"删除"按钮
2. 调用 `removeAccount(uri)`
3. 账号从列表移除并保存

### 设置默认账号
1. 用户点击"设为默认"
2. 调用 `setAsDefaultAccount(uri)`
3. 下次启动自动使用此账号

## 优势

✅ **完全使用Risip内置功能** - 不需要自己管理账号存储
✅ **自动保存** - 每次操作后自动持久化
✅ **模型自动更新** - 添加/删除账号时ListView自动刷新
✅ **类型安全** - 使用Qt Model/View框架

## 测试建议

1. 添加第一个账号并验证保存
2. 添加第二个账号
3. 在两个账号间切换
4. 删除一个账号
5. 设置默认账号并重启验证

---

**实现状态**: ✅ C++后端完成,UI待实现
**预计UI工作量**: 1-2小时
**优先级**: 中 (实用功能,可改善UX)
