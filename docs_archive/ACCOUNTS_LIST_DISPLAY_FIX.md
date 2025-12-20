# 修复已保存账户列表显示为空的问题

## 日期
2025-11-28

## 问题描述

用户报告:
> "已保存账户，下面，暂无保存的账号，请先注册一个账户"

即使已经注册并保存了账户(如 1000@192.168.10.243),设置界面的"已保存账户"列表仍然显示为空。

C++ 日志显示:
```
[DEBUG] RisipAccountListModel::addSipAccount() - After add, count: 1
[DEBUG]   Total accounts in hash: 1
```

但 QML 界面不显示任何账户。

## 根因分析

### 问题1: QML 无法正确绑定到 C++ 函数返回的模型

**原始代码** ([SipSettingsPage.qml:292](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L292)):
```qml
property var accountsModel: SipPhoneManager.getAllAccountsModel()
model: accountsModel
```

**问题**:
- `getAllAccountsModel()` 是一个 **Q_INVOKABLE 函数**,不是 Q_PROPERTY
- QML 在页面加载时调用一次该函数,获取当时的模型引用
- 但模型在之后发生变化时(如添加账户),QML **不会收到通知**
- QML 的 property binding 无法追踪函数返回值的变化

### 问题2: endInsertColumns() 与 endInsertRows() 不匹配

**原始代码** ([risipaccountlistmodel.cpp:170](src/risip/models/risipaccountlistmodel.cpp#L170)):
```cpp
beginInsertRows(QModelIndex(), rowCount(), rowCount());
emit layoutAboutToBeChanged();

m_data->accounts.insert(account->configuration()->uri(), account);
account->setParent(this);

endInsertColumns();  // ❌ 错误! 应该是 endInsertRows()
```

**问题**:
- `beginInsertRows()` 告诉 Qt 即将插入行
- `endInsertColumns()` 告诉 Qt 列插入完成
- 不匹配导致 Qt 模型/视图系统混乱,QML ListView 不更新

### 问题3: 缺少 console.log() 输出

**观察**:
- QML 中添加了大量 `console.log()` 调试语句
- 但运行时**没有任何 QML 日志输出**
- 只有 C++ 日志正常输出

**可能原因**:
- Qt 默认可能过滤 `console.log()` 输出
- QML 页面可能未正确加载或编译

## 修复方案

### 修复1: 将 getAllAccountsModel() 改为 Q_PROPERTY

**目的**: 让 QML 能够正确绑定到模型,并在模型变化时收到通知

#### 1.1 添加 Q_PROPERTY ([SipPhoneManager.h:31](src/sip_phone/SipPhoneManager.h#L31))

```cpp
Q_PROPERTY(QString serverStatus READ serverStatus NOTIFY serverStatusChanged)
Q_PROPERTY(QObject* accountsModel READ accountsModel NOTIFY accountsModelChanged)  // 新增
```

#### 1.2 添加 getter 方法声明 ([SipPhoneManager.h:49](src/sip_phone/SipPhoneManager.h#L49))

```cpp
QString serverStatus() const;
QObject* accountsModel() const;  // 新增
```

#### 1.3 添加信号声明 ([SipPhoneManager.h:102](src/sip_phone/SipPhoneManager.h#L102))

```cpp
void serverStatusChanged(const QString &status);
void accountsModelChanged();  // 新增
```

#### 1.4 实现 getter 方法 ([SipPhoneManager.cpp:162-179](src/sip_phone/SipPhoneManager.cpp#L162-L179))

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
            qDebug() << "[DEBUG] accountsModel() returning model with" << itemModel->rowCount() << "accounts";
        }
    } else {
        qDebug() << "[DEBUG] accountsModel() returning nullptr";
    }
    return model;
}
```

**为什么这样修复有效?**

1. **Q_PROPERTY 支持属性绑定**: QML 引擎可以监听 `accountsModelChanged()` 信号
2. **自动更新**: 当模型发生变化时(如添加账户),可以 emit `accountsModelChanged()`,QML 自动刷新
3. **调试增强**: 每次访问属性都会打印调试信息,方便追踪

### 修复2: 修正 endInsertColumns() 为 endInsertRows()

**文件**: [risipaccountlistmodel.cpp:175](src/risip/models/risipaccountlistmodel.cpp#L175)

**修改**:
```cpp
beginInsertRows(QModelIndex(), rowCount(), rowCount());
emit layoutAboutToBeChanged();

m_data->accounts.insert(account->configuration()->uri(), account);
account->setParent(this);

endInsertRows();  // ✅ 修正: 改为 endInsertRows()
emit layoutChanged();
```

**为什么这样修复有效?**

- Qt 模型/视图框架要求 `begin*` 和 `end*` 调用成对
- 修正后,Qt 正确通知所有视图(包括 QML ListView)行数发生变化
- ListView 收到通知后会自动重新查询模型并更新显示

### 修复3: 更新 QML 绑定 ([SipSettingsPage.qml:292-309](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L292-L309))

**修改前**:
```qml
property var accountsModel: SipPhoneManager.getAllAccountsModel()
model: accountsModel
```

**修改后**:
```qml
// Use property binding to SipPhoneManager.accountsModel
model: SipPhoneManager.accountsModel

// Debug: Print model info when component loads
Component.onCompleted: {
    console.log("[QML] ListView initialized")
    console.log("[QML] Model object:", SipPhoneManager.accountsModel)
    console.log("[QML] Model count:", count)
}

Connections {
    target: SipPhoneManager.accountsModel
    function onLayoutChanged() {
        console.log("[QML] Model layout changed, new count:", accountsListView.count)
    }
    function onRowsInserted() {
        console.log("[QML] Rows inserted, new count:", accountsListView.count)
    }
}
```

**改进点**:
1. **直接绑定 Q_PROPERTY**: `model: SipPhoneManager.accountsModel`
2. **添加 Connections**: 监听模型的 `layoutChanged` 和 `rowsInserted` 信号
3. **增强调试**: 打印模型对象和 count

## Q_PROPERTY vs Q_INVOKABLE 对比

| 特性 | Q_INVOKABLE 函数 | Q_PROPERTY |
|------|------------------|-----------|
| QML 调用方式 | `SipPhoneManager.getAllAccountsModel()` | `SipPhoneManager.accountsModel` |
| 返回值缓存 | 每次调用都执行 | Qt 自动缓存 |
| 变化通知 | 无 | 通过 NOTIFY 信号 |
| QML 属性绑定 | ❌ 不支持 | ✅ 支持 |
| 用途 | 一次性调用的方法 | 需要监听变化的属性 |

**结论**: 对于需要在 QML 中**实时反映 C++ 状态变化**的数据,必须使用 **Q_PROPERTY**,而不是 Q_INVOKABLE。

## 测试计划

### 测试1: 验证模型绑定

**步骤**:
1. 清除旧配置(删除 Windows 注册表 `HKEY_CURRENT_USER\Software\BeltControl\SipPhone`)
2. 启动应用
3. 打开设置页面,观察日志

**预期结果**:
```
[DEBUG] accountsModel() returning model with 0 accounts
[QML] ListView initialized
[QML] Model object: <RisipAccountListModel地址>
[QML] Model count: 0
```

### 测试2: 验证账户添加后列表更新

**步骤**:
1. 注册账户: `1000` @ `192.168.10.243`
2. 打开设置页面
3. 观察日志和界面

**预期结果**:
```
[DEBUG] RisipAccountListModel::addSipAccount() - After add, count: 1
[DEBUG] accountsModel() returning model with 1 accounts
[QML] Model layout changed, new count: 1
```

**界面显示**:
- ✅ 显示 1 个账户卡片
- ✅ 显示账户 URI: `sip:1000@192.168.10.243`
- ✅ 显示服务器地址: `192.168.10.243`
- ✅ 显示"★默认"标签

### 测试3: 验证应用重启后列表保留

**步骤**:
1. 完成测试2
2. 关闭应用
3. 重新启动应用
4. 打开设置页面

**预期结果**:
- ✅ 自动加载已保存的账户
- ✅ 列表显示 1 个账户
- ✅ 账户信息完整

## 相关文件

| 文件 | 修改内容 |
|------|----------|
| [SipPhoneManager.h:31](src/sip_phone/SipPhoneManager.h#L31) | 添加 `accountsModel` Q_PROPERTY |
| [SipPhoneManager.h:49](src/sip_phone/SipPhoneManager.h#L49) | 添加 `accountsModel()` getter 声明 |
| [SipPhoneManager.h:102](src/sip_phone/SipPhoneManager.h#L102) | 添加 `accountsModelChanged()` 信号 |
| [SipPhoneManager.cpp:162-179](src/sip_phone/SipPhoneManager.cpp#L162-L179) | 实现 `accountsModel()` getter |
| [risipaccountlistmodel.cpp:175](src/risip/models/risipaccountlistmodel.cpp#L175) | 修正 endInsertRows() |
| [SipSettingsPage.qml:292-309](src/qml/components/sip_phone/pages/SipSettingsPage.qml#L292-L309) | 改为绑定 Q_PROPERTY |

## 技术细节

### Qt 模型/视图架构

Qt 的模型/视图框架要求:
1. **数据变化通知**: 使用 `beginInsertRows()` / `endInsertRows()` 等方法
2. **信号发送**: `layoutChanged()`, `rowsInserted()` 等信号
3. **视图更新**: QML ListView 监听信号并自动刷新

**关键**:
- `begin*` 和 `end*` **必须成对且类型匹配**
- `beginInsertRows()` → `endInsertRows()` ✅
- `beginInsertRows()` → `endInsertColumns()` ❌

### QML 属性绑定机制

QML 的属性绑定是**响应式的**:
```qml
model: SipPhoneManager.accountsModel
```

当 `SipPhoneManager.accountsModel` 发生变化时(通过 `emit accountsModelChanged()`),QML 引擎会:
1. 重新读取属性值
2. 更新绑定到该属性的所有 UI 元素
3. 触发 ListView 的 `count` 属性更新
4. 重新渲染委托(delegate)

## 参考文档

- [DEFAULT_ACCOUNT_URI_FIX.md](DEFAULT_ACCOUNT_URI_FIX.md) - 默认账户 URI 修复
- [Qt Documentation: Q_PROPERTY](https://doc.qt.io/qt-6/properties.html)
- [Qt Documentation: Model/View Programming](https://doc.qt.io/qt-6/model-view-programming.html)
- [Qt Documentation: QAbstractItemModel](https://doc.qt.io/qt-6/qabstractitemmodel.html)

## 总结

✅ **根因已找到**:
1. 使用 Q_INVOKABLE 函数而非 Q_PROPERTY - QML 无法监听模型变化
2. `endInsertColumns()` 与 `beginInsertRows()` 不匹配 - 模型通知机制失效

✅ **修复已完成**:
1. 添加 `accountsModel` Q_PROPERTY 及相关信号
2. 修正 `endInsertRows()` 调用
3. 更新 QML 绑定到 Q_PROPERTY

✅ **预期效果**:
- 注册账户后,设置页面立即显示账户列表 ✅
- 应用重启后,账户列表自动加载 ✅
- 删除/设为默认等操作实时更新 UI ✅

---

**修复日期**: 2025-11-28
**状态**: ✅ 代码完成,待编译和测试
**下一步**: 编译成功后,运行应用验证账户列表显示功能
