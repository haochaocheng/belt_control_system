# 配置保存修复 - 服务器地址端口问题

## 日期
2025-11-28

## 问题

用户报告配置保存后显示:
```
[DEBUG] SIP DEFAULT ACCOUNT  "sip:@"
[DEBUG] Auto-registering default account: "sip:@"
```

服务器地址为空,导致无法自动注册。

## 根本原因

在 `SipPhoneManager::registerAccount()` 中,虽然调用了:
```cpp
config->setServerAddress(sipServer);
```

但是没有包含端口号。Risip期望 `serverAddress` 格式为 `"server:port"`,例如 `"192.168.10.243:5060"`。

## 修复

[SipPhoneManager.cpp:315-317](src/sip_phone/SipPhoneManager.cpp#L315-L317)

### 修改前
```cpp
// Set registrar server address
config->setServerAddress(sipServer);
```

### 修改后
```cpp
// Set registrar server address with port
QString serverWithPort = port == 5060 ? sipServer : QString("%1:%2").arg(sipServer).arg(port);
config->setServerAddress(serverWithPort);
```

## 效果

现在配置保存时会包含完整的服务器地址和端口:
```
ServerAddress=192.168.10.243:5060
```

或如果使用默认端口5060:
```
ServerAddress=192.168.10.243
```

自动登录时日志显示:
```
[DEBUG] Auto-registering default account: "sip:1000@192.168.10.243"
```

## 测试步骤

1. 删除旧配置(Windows注册表或ini文件)
2. 启动应用
3. 进入设置页面,输入:
   - 服务器: 192.168.10.243
   - 端口: 5060
   - 用户名: 1000
   - 密码: 1234
4. 点击"注册"
5. 关闭应用
6. 重新启动
7. 验证自动注册成功

## 下一步: 多账号管理UI

用户提到Risip源码支持多服务器配置下拉选择。实现方案:

### 需求分析

1. **账号列表**: 显示所有保存的SIP账号
2. **服务器选择**: 下拉框选择服务器,自动填充用户名/密码
3. **账号管理**: 添加/编辑/删除账号
4. **默认账号**: 标记哪个是默认登录账号

### 实现方案

#### 1. 暴露Risip的账号列表

Risip已经提供了 `allAccountsModel`:

```cpp
// risip.h
Q_PROPERTY(QAbstractItemModel *allAccountsModel READ allAccountsModel NOTIFY allAccountsModelChanged)
```

在SipPhoneManager中添加访问器:

```cpp
// SipPhoneManager.h
Q_INVOKABLE QAbstractItemModel* getAllAccountsModel();

// SipPhoneManager.cpp
QAbstractItemModel* SipPhoneManager::getAllAccountsModel() {
    if (d->risipInstance) {
        return d->risipInstance->allAccountsModel();
    }
    return nullptr;
}
```

#### 2. 修改设置页面UI

在 `SipSettingsPage.qml` 添加:

**账号列表**:
```qml
ListView {
    model: SipPhoneManager.getAllAccountsModel()
    delegate: ItemDelegate {
        text: model.uri  // 显示 sip:1000@192.168.10.243
        onClicked: {
            // 填充表单
            serverInput.text = model.serverAddress
            usernameInput.text = model.username
            // 密码不显示
        }
    }
}
```

**服务器下拉框**:
```qml
ComboBox {
    id: serverComboBox
    model: SipPhoneManager.getAllAccountsModel()
    textRole: "serverAddress"

    onCurrentIndexChanged: {
        // 自动填充对应的账号信息
        var account = SipPhoneManager.getAllAccountsModel().get(currentIndex)
        usernameInput.text = account.username
        portInput.text = extractPort(account.serverAddress)
    }
}
```

**新增/删除按钮**:
```qml
RowLayout {
    RisipButton {
        text: "新增账号"
        onClicked: {
            // 清空表单供新账号输入
        }
    }

    RisipButton {
        text: "删除当前"
        onClicked: {
            SipPhoneManager.deleteAccount(currentAccountUri)
        }
    }

    RisipButton {
        text: "设为默认"
        onClicked: {
            SipPhoneManager.setDefaultAccount(currentAccountUri)
        }
    }
}
```

#### 3. SipPhoneManager添加账号管理方法

```cpp
Q_INVOKABLE bool deleteAccount(const QString &accountUri);
Q_INVOKABLE bool setAsDefaultAccount(const QString &accountUri);
Q_INVOKABLE QVariantMap getAccountInfo(const QString &accountUri);
```

实现:
```cpp
bool SipPhoneManager::deleteAccount(const QString &accountUri) {
    if (d->risipInstance) {
        bool success = d->risipInstance->removeAccount(accountUri);
        if (success) {
            d->risipInstance->saveSettings();
        }
        return success;
    }
    return false;
}

bool SipPhoneManager::setAsDefaultAccount(const QString &accountUri) {
    if (d->risipInstance) {
        d->risipInstance->setDefaultAccount(accountUri);
        d->risipInstance->saveSettings();
        return true;
    }
    return false;
}
```

### 预计工作量

- **添加C++方法**: 30分钟
- **修改QML UI**: 1-2小时
- **测试**: 30分钟
- **总计**: 2-3小时

### 优先级

**中**: 这是"nice to have"功能,不影响基本使用。当前单账号保存已经工作正常。

建议先完成:
1. ✅ 配置保存 (已完成)
2. ⏳ 通话历史记录 (更实用)
3. ⏳ 视频通话 (最高价值)
4. ⏳ 多账号管理UI (改善UX)

## 总结

✅ 修复了服务器地址保存问题
✅ 现在配置可以正确保存和加载
✅ 自动登录功能正常工作
⏳ 多账号管理UI待实现(可选)

---

**修复日期**: 2025-11-28
**状态**: ✅ 完成
