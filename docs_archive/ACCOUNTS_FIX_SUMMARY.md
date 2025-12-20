# 账户列表显示修复 - 快速总结

## ✅ 已修复 (2025-12-03 08:40)

### 问题
设置页面的"已保存账户"列表显示为空,即使账户已保存。

### 根本原因
**缺少 `emit accountsModelChanged()` 信号!**

QML 通过 Q_PROPERTY 绑定模型:
```qml
model: SipPhoneManager.accountsModel
```

但 C++ 端在加载账户后从未发出 `accountsModelChanged()` 信号,导致 QML 不知道要重新获取模型。

### 修复内容

#### 1. 在账户加载后发出信号
**文件**: SipPhoneManager.cpp:302-304

```cpp
bool settingsLoaded = d->risipInstance->readSettings();
if (settingsLoaded) {
    qDebug() << "Saved accounts loaded successfully";

    emit accountsModelChanged();  // ← 新增!
    qDebug() << "Emitted accountsModelChanged() signal to QML";
    // ...
}
```

#### 2. 在注册新账户后发出信号
**文件**: SipPhoneManager.cpp:469-471

```cpp
if (d->risipInstance->saveSettings()) {
    qDebug() << "Account configuration saved successfully";

    emit accountsModelChanged();  // ← 新增!
    qDebug() << "Emitted accountsModelChanged() after adding new account";
}
```

## 🚀 测试步骤

### 1. 启动应用
```bash
build\bin_windows\belt_control_system.exe
```

### 2. 验证已保存账户显示
1. 打开 "SIP电话" 窗口
2. 点击 "设置" 标签
3. **应该看到**: 已保存的账户列表 (例如账号 1000)
4. **不应该看到**: "暂无保存的账号" 提示

### 3. 验证新账户注册
1. 切换到 "拨号" 页面
2. 输入新账号 (例如 1001) 并注册
3. 返回 "设置" 页面
4. **应该看到**: 两个账户 (1000 和 1001)

### 4. 检查日志
应该看到这些新日志:
```
[DEBUG] Emitted accountsModelChanged() signal to QML
[DEBUG] accountsModel() returning model with 1 accounts
[QML] ListView initialized
[QML] Model count: 1
```

## 📚 详细文档

完整的技术分析和修复过程请查看:
- [ACCOUNTS_MODEL_SIGNAL_FIX.md](ACCOUNTS_MODEL_SIGNAL_FIX.md) - 根本原因分析和修复详情
- [ACCOUNTS_LIST_FIX_COMPLETED.md](ACCOUNTS_LIST_FIX_COMPLETED.md) - 之前的可见性修复

## 🔑 关键知识点

### Q_PROPERTY 的 NOTIFY 机制
```cpp
Q_PROPERTY(QObject* accountsModel READ accountsModel NOTIFY accountsModelChanged)
```

- NOTIFY 信号不是可选的!
- 即使返回同一个对象引用
- 也必须 emit 信号来触发 QML 重新绑定

### 时序图
```
修复前:
  QML 获取空模型 → 加载账户 → 模型有数据,但 QML 不知道 → 显示空 ❌

修复后:
  QML 获取空模型 → 加载账户 → emit accountsModelChanged() → QML 重新获取 → 显示数据 ✅
```

---

**编译状态**: ✅ [100%] Built target belt_control_system
**修复文件**: SipPhoneManager.cpp (2 处修改)
**新增日志**: "Emitted accountsModelChanged() signal to QML"
**下一步**: 运行应用测试
