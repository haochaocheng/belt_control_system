/***********************************************************************************
**    Copyright (C) 2016  Petref Saraci
**    http://risip.io
**
**    This program is free software: you can redistribute it and/or modify
**    it under the terms of the GNU General Public License as published by
**    the Free Software Foundation, either version 3 of the License, or
**    (at your option) any later version.
**
**    This program is distributed in the hope that it will be useful,
**    but WITHOUT ANY WARRANTY; without even the implied warranty of
**    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**    GNU General Public License for more details.
**
**    You have received a copy of the GNU General Public License
**    along with this program. See LICENSE.GPLv3
**    A copy of the license can be found also here <http://www.gnu.org/licenses/>.
**
************************************************************************************/

#include "risip.h"

#include "risipglobals.h"
#include "risipbuddy.h"
#include "risipcall.h"
#include "risipaccountconfiguration.h"
#include "risipmedia.h"
#include "risipmessage.h"
#include "risipcallmanager.h"
#include "risipcontactmanager.h"
#include "risipphonecontact.h"
#include "risipphonenumber.h"
#include "risipratemanager.h"

#include "utils/stopwatch.h"
#include "utils/qqmlsortfilterproxymodel.h"

#include "models/risipcallhistorymodel.h"
#include "models/risipcountryratesmodel.h"
#include "models/risipphonecontactsmodel.h"
#include "models/risipphonenumbersmodel.h"
#include "models/risipaccountlistmodel.h"
#include "models/risipmodels.h"

#include "apploader/risipapplicationsettings.h"

#include <QQmlEngine>
#include <QSettings>
#include <QCoreApplication>

// ✅ 引入统一数据路径配置（用于持久化SIP账户配置）
#include "control/DataPathConfig.h"
#include <QDebug>
#include <QSortFilterProxyModel>

namespace risip {

class Risip::Private
{
public:
    RisipAccountListModel *accountsModel;
    RisipEndpoint sipEndpoint;
};

/**
 * @brief risipSingletonProvider
 * @param engine
 * @param scriptEngine
 * @return
 *
 * Risip singleton object provider for the QML engine.
 */
static QObject *risipSingletonProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return Risip::instance();
}

/**
 * @brief risipCallManagerSingletonProvider
 * @param engine
 * @param scriptEngine
 * @return
 *
 * RisipCallManager singleton object provider for the QML engine.
 */
static QObject *risipCallManagerSingletonProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return RisipCallManager::instance();
}

/**
 * @brief risipContactManagerSingletonProvider
 * @param engine
 * @param scriptEngine
 * @return
 *
 * RisipContactManager singleton object provider for the QML engine.
 */
static QObject *risipContactManagerSingletonProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return RisipContactManager::instance();
}

static QObject *risipRateManagerSingletonProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return RisipRateManager::instance();
}

static QObject *risipApplicationSingletonProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return RisipApplicationSettings::instance();
}


// Static member moved to function-local static to avoid Windows DLL export issues
Risip *Risip::instance()
{
    static Risip *m_risipInstance = nullptr;
    if(!m_risipInstance)
        m_risipInstance = new Risip;

    return m_risipInstance;
}

Risip::Risip(QObject *parent)
    :QObject (parent)
    ,m_data(new Private)
{
    m_data->accountsModel = new RisipAccountListModel(this);
    RisipGlobals::instance()->initializeCountries();
}

Risip::~Risip()
{
    m_data->sipEndpoint.stop();
    m_data->accountsModel->deleteLater();
    delete m_data;
    m_data = nullptr;
}

RisipEndpoint *Risip::sipEndpoint()
{
    return &m_data->sipEndpoint;
}

bool Risip::firstRun() const
{
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    QVariant val = settings.value(RisipSettingsParam::FirstRun);
    if(val.isNull())
        return true;

    return settings.value(RisipSettingsParam::FirstRun).toBool();
}

QAbstractItemModel *Risip::allAccountsModel() const
{
    return m_data->accountsModel;
}

RisipAccount *Risip::defaultAccount() const
{
    return m_data->accountsModel->defaultAccount();
}

void Risip::setDefaultAccount(const QString &uri)
{
    m_data->accountsModel->setDefaultAccountUri(uri);
    RisipCallManager::instance()->setActiveAccount(m_data->accountsModel->defaultAccount());
    RisipContactManager::instance()->setActiveAccount(m_data->accountsModel->defaultAccount());

    qDebug()<<"SIP DEFAULT ACCOUNT " << uri;
    emit defaultAccountChanged(m_data->accountsModel->defaultAccount());
}

void Risip::registerToQml()
{
    qmlRegisterSingletonType<Risip>(RisipSettingsParam::risipQmlURI, 1, 0, "Risip", risipSingletonProvider);
    qmlRegisterSingletonType<RisipCallManager>(RisipSettingsParam::risipQmlURI, 1, 0,
                                               "RisipCallManager", risipCallManagerSingletonProvider);
    qmlRegisterSingletonType<RisipContactManager>(RisipSettingsParam::risipQmlURI, 1, 0,
                                                  "RisipContactManager", risipContactManagerSingletonProvider);

    qmlRegisterSingletonType<RisipRateManager>(RisipSettingsParam::risipQmlURI, 1, 0,
                                               "RisipRateManager", risipRateManagerSingletonProvider);
    qmlRegisterSingletonType<RisipApplicationSettings>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipApplicationSettings",
                                                       risipApplicationSingletonProvider);

    qmlRegisterType<RisipEndpoint>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipEndpoint");
    qmlRegisterType<RisipAccount>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipAccount");
    qmlRegisterType<RisipBuddy>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipBuddy");
    qmlRegisterType<RisipCall>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipCall");
    qmlRegisterType<RisipAccountConfiguration>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipAccountConfiguration");
    qmlRegisterType<RisipMedia>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipMedia");
    qmlRegisterType<RisipMessage>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipMessage");
    qmlRegisterType<RisipCallHistoryModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipCallHistoryModel");
    qmlRegisterType<RisipBuddiesModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipBuddiesModel");
    qmlRegisterType<RisipContactHistoryModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipContactHistoryModel");
    qmlRegisterType<RisipPhoneContactsModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipPhoneContactsModel");
    qmlRegisterType<RisipPhoneContact>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipPhoneContact");
    qmlRegisterType<RisipPhoneNumber>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipPhoneNumber");
    qmlRegisterType<RisipPhoneNumbersModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipPhoneNumbersModel");
    qmlRegisterType<RisipCountryRatesModel>(RisipSettingsParam::risipQmlURI, 1, 0, "RisipCountryRatesModel");
    qmlRegisterType<StopWatch>(RisipSettingsParam::risipQmlURI, 1, 0, "StopWatch");
    qmlRegisterType<qqsfpm::QQmlSortFilterProxyModel>(RisipSettingsParam::risipQmlURI, 1, 0, "SortFilterProxyModel");
}

RisipAccount *Risip::accountForUri(const QString &accountUri)
{
    return m_data->accountsModel->account(accountUri);
}

/**
 * @brief Risip::accountForConfiguration
 * @param configuration
 * @return RisipAccount
 *
 * Retrieves existing account from the model for the given configuration. If there is no existing account
 * then it will create one
 */
RisipAccount *Risip::accountForConfiguration(RisipAccountConfiguration *configuration)
{
    if(configuration && configuration->valid()) {
        //return an existing account and update its configuration too
        if(m_data->accountsModel->exists(configuration->uri()))
            return m_data->accountsModel->account(configuration->uri());
        }

    return createAccount(configuration);
}

/**
 * @brief Risip::createAccount
 * @param configuration
 * @return RisipAccount
 *
 * Creates a RisipAccount based on the given configuration. If the configuration is not valid
 * then no account will be created
 */
RisipAccount *Risip::createAccount(RisipAccountConfiguration *configuration)
{
    qDebug() << "[DEBUG] 🔹 createAccount() 开始";
    if(configuration && configuration->valid()) {
        qDebug() << "[DEBUG] 🔹 配置有效，URI:" << configuration->uri();
        //create a new account with the given configuration

        //FIXME avoid copy - this is a workaround - configuration in QML deleted
        qDebug() << "[DEBUG] 🔹 创建配置副本...";
        RisipAccountConfiguration *config = new RisipAccountConfiguration;
        config->setUri(configuration->uri());
        config->setUserName(configuration->userName());
        config->setPassword(configuration->password());
        config->setNetworkProtocol(configuration->networkProtocol());
        config->setServerAddress(configuration->serverAddress());
        config->setProxyServer(configuration->proxyServer());
        config->setLocalPort(configuration->localPort());
        config->setRandomLocalPort(configuration->randomLocalPort());
        config->setScheme(configuration->scheme());
        qDebug() << "[DEBUG] ✅ 配置副本创建完成";

        qDebug() << "[DEBUG] 🔹 创建RisipAccount对象...";
        RisipAccount *account = new RisipAccount(m_data->accountsModel);
        qDebug() << "[DEBUG] ✅ RisipAccount对象创建完成";

        qDebug() << "[DEBUG] 🔹 先设置配置（避免信号处理中访问未初始化的配置）...";
        account->setConfiguration(config);
        qDebug() << "[DEBUG] ✅ setConfiguration()完成";

        // ✅ setConfiguration()已经复制了配置内容，现在可以安全删除临时config对象
        // ⚠️ 使用 deleteLater() 而不是立即删除，避免信号槽机制中的竞态条件
        qDebug() << "[DEBUG] 🗑️ 标记临时config副本稍后删除...";
        config->deleteLater();
        config = nullptr;
        qDebug() << "[DEBUG] ✅ 临时config副本已标记为稍后删除";

        // ⚠️ 注意：传入的 configuration 参数不在这里删除，由调用者管理（tempParent）

        qDebug() << "[DEBUG] 🔹 获取sipEndpoint指针:" << (void*)sipEndpoint();
        if (!sipEndpoint()) {
            qDebug() << "[DEBUG] ❌❌❌ 严重错误：sipEndpoint()返回NULL！";
        } else {
            qDebug() << "[DEBUG] ✅ sipEndpoint()指针有效";
        }

        qDebug() << "[DEBUG] 🔹 调用account->setSipEndPoint()...";
        account->setSipEndPoint(sipEndpoint());
        qDebug() << "[DEBUG] ✅ setSipEndPoint()完成";

        qDebug() << "[DEBUG] 🔹 添加到账户模型...";
        m_data->accountsModel->addSipAccount(account);
        qDebug() << "[DEBUG] ✅ addSipAccount()完成";

        qDebug() << "[DEBUG] 🔹 为账户创建联系人模型...";
        RisipContactManager::instance()->createModelsForAccount(account);
        qDebug() << "[DEBUG] ✅ createModelsForAccount()完成";

        qDebug() << "[DEBUG] 🔹 为账户创建通话模型...";
        RisipCallManager::instance()->createModelsForAccount(account);
        qDebug() << "[DEBUG] ✅ createModelsForAccount()完成";

        qDebug() << "[DEBUG] ✅ createAccount()完成，返回账户对象";
        return account;
    }

    qDebug() << "[DEBUG] ⚠️ 配置无效或为NULL，删除配置并返回空账户";
    configuration->deleteLater();
    return new RisipAccount(this);
}

bool Risip::removeAccount(const QString &accountUri)
{
    if(m_data->accountsModel->exists(accountUri)) {
        m_data->accountsModel->removeSipAccount(accountUri);
        RisipContactManager::instance()->removeModelsForAccount(accountForUri(accountUri));
        RisipCallManager::instance()->removeModelsForAccount(accountForUri(accountUri));
        return true;
    }

    return false;
}

bool Risip::removeAccount(RisipAccountConfiguration *configuration)
{
    if(configuration)
        return removeAccount(configuration->uri());

    return false;
}

bool Risip::readSettings()
{
    // ✅ 使用统一数据路径配置（持久化到Docker卷）
    QString configPath = DataPathConfig::getSipAccountsConfigPath();
    qDebug() << "📖 [Risip] 从持久化位置读取SIP账户配置:" << configPath;
    QSettings settings(configPath, QSettings::IniFormat);
    int totaltAccounts = settings.value(RisipSettingsParam::TotalAccounts).toInt();

    qDebug() << "[DEBUG] 🔍 总账户数量:" << totaltAccounts;

    QString defaultAccountUri = settings.value(RisipSettingsParam::DefaultAccount).toString();
    qDebug() << "[DEBUG] 📖 从配置文件读取的defaultAccount:" << defaultAccountUri;

    // ✅ CRITICAL FIX: If defaultAccount is empty or invalid (like "sip:@"),
    // we'll use the first account's URI later
    bool needFixDefaultAccount = defaultAccountUri.isEmpty() ||
                                  defaultAccountUri == "sip:@" ||
                                  !defaultAccountUri.contains('@');

    RisipAccountConfiguration *configuration = NULL;
    settings.beginGroup(RisipSettingsParam::AccountGroup);
    for(int i=0; i<totaltAccounts; ++i) {
        qDebug() << "[DEBUG] 📝 开始读取账户" << i;
        settings.beginReadArray(QString("account" + QString::number(i))); //settings array for account

        // ✅ 创建配置对象（无父对象）
        configuration = new RisipAccountConfiguration;
        configuration->setUri(settings.value(RisipSettingsParam::Uri).toString());
        configuration->setUserName(settings.value(RisipSettingsParam::Username).toString());
        configuration->setPassword(settings.value(RisipSettingsParam::Password).toString());
        configuration->setNetworkProtocol(settings.value(RisipSettingsParam::NetworkType).toInt());
        configuration->setServerAddress(settings.value(RisipSettingsParam::ServerAddress).toString());
        configuration->setProxyServer(settings.value(RisipSettingsParam::ProxyServer).toString());
        configuration->setLocalPort(settings.value(RisipSettingsParam::LocalPort).toInt());
        configuration->setRandomLocalPort(settings.value(RisipSettingsParam::RandomLocalPort).toInt());
        configuration->setScheme(settings.value(RisipSettingsParam::Scheme).toString());

        qDebug() << "[DEBUG] ✅ 账户配置创建完成，URI:" << configuration->uri();

        // ✅ CRITICAL FIX: 在调用createAccount()之前保存URI（因为createAccount会删除configuration）
        QString accountUri = configuration->uri();
        if (needFixDefaultAccount && i == 0) {
            defaultAccountUri = accountUri;
            qDebug() << "[DEBUG] 🔧 修复：使用第一个账户的URI作为默认账户:" << defaultAccountUri;
        }

        qDebug() << "[DEBUG] 🚀 准备调用createAccount()...";
        RisipAccount *acc = createAccount(configuration); //creating account (内部会复制config内容)
        qDebug() << "[DEBUG] ✅ createAccount()返回成功";
        acc->setAutoSignIn(settings.value(RisipSettingsParam::AutoSignIn).toBool());
        qDebug() << "[DEBUG] ✅ 账户" << i << "加载完成";
        settings.endArray();

        // ✅ createAccount()内部已使用deleteLater()标记config副本删除
        // 现在手动删除传入的configuration对象
        qDebug() << "[DEBUG] 🗑️ 使用deleteLater()标记configuration删除";
        configuration->deleteLater();
        configuration = nullptr;
    }

    qDebug() << "[DEBUG] 🎯 准备设置默认账户:" << defaultAccountUri;
    setDefaultAccount(defaultAccountUri);
    qDebug() << "[DEBUG] ✅ readSettings()完成";
    return true;
}

bool Risip::saveSettings()
{
    // ✅ 使用统一数据路径配置（持久化到Docker卷）
    QString configPath = DataPathConfig::getSipAccountsConfigPath();
    qDebug() << "💾 [Risip] 保存SIP账户配置到持久化位置:" << configPath;
    QSettings settings(configPath, QSettings::IniFormat);
    settings.setValue(RisipSettingsParam::TotalAccounts, m_data->accountsModel->rowCount());
    settings.setValue(RisipSettingsParam::FirstRun, true); //FIXME always to true for testing

    if(defaultAccount()) {
        qDebug()<<"SAVING DEFAULT ACCOUNT " << defaultAccount()->configuration()->uri();
        settings.setValue(RisipSettingsParam::DefaultAccount, defaultAccount()->configuration()->uri());
    }

    RisipAccount *account = NULL;
    settings.beginGroup(RisipSettingsParam::AccountGroup);
    for(int i=0; i<m_data->accountsModel->rowCount(); ++i) {
        settings.beginWriteArray(QString("account" + QString::number(i)), 9); //settings array for account
        account = m_data->accountsModel->account(i);// accounts[m_data->accounts.keys()[i]];
        settings.setValue(RisipSettingsParam::Uri, account->configuration()->uri());
        settings.setValue(RisipSettingsParam::Username, account->configuration()->userName());
        settings.setValue(RisipSettingsParam::Password, account->configuration()->password());
        settings.setValue(RisipSettingsParam::NetworkType, account->configuration()->networkProtocol());
        settings.setValue(RisipSettingsParam::ServerAddress, account->configuration()->serverAddress());
        settings.setValue(RisipSettingsParam::ProxyServer, account->configuration()->proxyServer());
        settings.setValue(RisipSettingsParam::Scheme, account->configuration()->scheme());
        settings.setValue(RisipSettingsParam::LocalPort, account->configuration()->localPort());
        settings.setValue(RisipSettingsParam::RandomLocalPort, account->configuration()->randomLocalPort());
        settings.setValue(RisipSettingsParam::AutoSignIn, account->autoSignIn());
        settings.endArray(); //end settings array for account
    }

    settings.endGroup();
    return true;
}

bool Risip::resetSettings()
{
    m_data->accountsModel->clear();
    // ✅ 使用统一数据路径配置（持久化到Docker卷）
    QString configPath = DataPathConfig::getSipAccountsConfigPath();
    qDebug() << "🗑️  [Risip] 清除SIP账户配置:" << configPath;
    QSettings settings(configPath, QSettings::IniFormat);
    settings.clear();
    settings.sync();
    return true;
}

void Risip::accessPhoneContacts()
{
    RisipContactManager::instance()->fetchPhoneContacts();
}

void Risip::accessPhoneMedia()
{
    RisipMedia media;
    media.loopAudioTest();
}

void Risip::accessPhoneLocation()
{
}

} //end of risip namespace
