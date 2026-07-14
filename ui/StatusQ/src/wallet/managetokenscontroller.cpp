#include "managetokenscontroller.h"

#include "tokendata.h"

#include <QJsonObject>
#include <QElapsedTimer>
#include <QTimer>

namespace
{
// Source roles whose changes are pure passthrough to token cells: they never
// affect which model a token lives in, group membership/metadata, group
// child-counts, or sort order. A dataChanged limited to these can be applied
// in place; anything else forces a full re-parse.
const QSet<QByteArray> kDataOnlyRoleNames{
    kEnabledNetworkBalanceRoleName,
    kEnabledNetworkCurrencyBalanceRoleName,
    kBalancesRoleName,
    kDecimalsRoleName,
    kMarketDetailsRoleName,
};
} // namespace

ManageTokensController::ManageTokensController(QObject* parent)
    : QObject(parent)
    , m_regularTokensModel(new ManageTokensModel(this))
    , m_collectionGroupsModel(new ManageTokensModel(this))
    , m_communityTokensModel(new ManageTokensModel(this))
    , m_communityTokenGroupsModel(new ManageTokensModel(this))
    , m_hiddenTokensModel(new ManageTokensModel(this))
    , m_hiddenCommunityTokenGroupsModel(new ManageTokensModel(this))
    , m_hiddenCollectionGroupsModel(new ManageTokensModel(this))
{
    for (auto model : m_allModels) {
        connect(model, &ManageTokensModel::dirtyChanged, this, &ManageTokensController::dirtyChanged);
    }

    m_sourceUpdateBatchTimer = new QTimer(this);
    m_sourceUpdateBatchTimer->setSingleShot(true);
    m_sourceUpdateBatchTimer->setInterval(0);
    connect(m_sourceUpdateBatchTimer, &QTimer::timeout, this, &ManageTokensController::flushPendingSourceUpdates);

    connect(this, &ManageTokensController::sourceModelChanged, this, [this]() {
        if (!m_sourceModel) {
            m_modelConnectionsInitialized = false;
            return;
        }
        if (m_modelConnectionsInitialized)
            return;
        connect(m_sourceModel,
                &QAbstractItemModel::rowsInserted,
                this,
                [this](const QModelIndex& parent, int first, int last) {
                    Q_UNUSED(parent)
                    // A structural change interleaving with queued in-place updates
                    // shifts row indices; fall back to a correct full re-parse.
                    if (hasPendingSourceUpdates()) {
                        parseSourceModel();
                        return;
                    }
#ifdef QT_DEBUG
                    QElapsedTimer t;
                    t.start();
                    qCDebug(manageTokens) << "!!! ADDING" << last - first + 1 << "NEW TOKENS";
#endif
                    for (int i = first; i <= last; i++)
                        addItem(i);

                    rebuildModels();

                    for (auto model : m_allModels) {
                        model->saveCustomSortOrder();
                    }
#ifdef QT_DEBUG
                    qCDebug(manageTokens)
                        << "!!! ADDING NEW SOURCE DATA TOOK" << t.nsecsElapsed() / 1'000'000.f << "ms";
#endif
                });
        connect(m_sourceModel, &QAbstractItemModel::rowsRemoved, this, &ManageTokensController::parseSourceModel);
        connect(m_sourceModel, &QAbstractItemModel::dataChanged, this, &ManageTokensController::onSourceDataChanged);
        m_modelConnectionsInitialized = true;
    });
}

void ManageTokensController::showHideRegularToken(const QString& key, bool flag)
{
    if (flag) { // show
        auto hiddenItem = m_hiddenTokensModel->takeItem(key);
        if (hiddenItem) {
            m_regularTokensModel->addItem(*hiddenItem);
            emit tokenShown(hiddenItem->key, hiddenItem->name);
        }
    } else { // hide
        auto shownItem = m_regularTokensModel->takeItem(key);
        if (shownItem) {
            m_hiddenTokensModel->addItem(*shownItem, false /*prepend*/);
            emit tokenHidden(shownItem->key, shownItem->name);
        }
    }
    emit requestSaveSettings(serializeSettingsAsJson());
}

void ManageTokensController::showHideCommunityToken(const QString& key, bool flag)
{
    if (flag) { // show
        auto hiddenItem = m_hiddenTokensModel->takeItem(key);
        if (hiddenItem) {
            m_communityTokensModel->addItem(*hiddenItem);
            emit tokenShown(hiddenItem->key, hiddenItem->name);
        }
    } else { // hide
        auto shownItem = m_communityTokensModel->takeItem(key);
        if (shownItem) {
            m_hiddenTokensModel->addItem(*shownItem, false /*prepend*/);
            emit tokenHidden(shownItem->key, shownItem->name);
        }
    }
    m_communityTokensModel->saveCustomSortOrder();
    rebuildCommunityTokenGroupsModel();
    rebuildHiddenCommunityTokenGroupsModel();
    emit requestSaveSettings(serializeSettingsAsJson());
}

void ManageTokensController::showHideGroup(const QString& groupId, bool flag)
{
    if (flag) { // show
        const auto tokens = m_hiddenTokensModel->takeAllItems(groupId);
        if (!tokens.isEmpty()) {
            for (const auto& token : tokens) {
                m_communityTokensModel->addItem(token);
            }
            emit communityTokenGroupShown(tokens.constFirst().communityName);
        }
        if (m_hiddenCommunityGroups.remove(groupId)) {
            emit hiddenCommunityGroupsChanged();
        }
    } else { // hide
        const auto tokens = m_communityTokensModel->takeAllItems(groupId);
        if (!tokens.isEmpty()) {
            for (const auto& token : tokens) {
                m_hiddenTokensModel->addItem(token, false /*prepend*/);
            }
            emit communityTokenGroupHidden(tokens.constFirst().communityName);
        }
        if (!m_hiddenCommunityGroups.contains(groupId)) {
            m_hiddenCommunityGroups.insert(groupId);
            emit hiddenCommunityGroupsChanged();
        }
    }
    rebuildCommunityTokenGroupsModel();
    m_communityTokenGroupsModel->applySort();
    rebuildHiddenCommunityTokenGroupsModel();
    emit requestSaveSettings(serializeSettingsAsJson());
}

void ManageTokensController::showHideCollectionGroup(const QString& groupId, bool flag)
{
    if (flag) { // show
        const auto tokens = m_hiddenTokensModel->takeAllItems(groupId);
        if (!tokens.isEmpty()) {
            for (const auto& token : tokens) {
                m_regularTokensModel->addItem(token);
            }
            emit collectionTokenGroupShown(tokens.constFirst().collectionName);
        }
        if (m_hiddenCollectionGroups.remove(groupId)) {
            emit hiddenCollectionGroupsChanged();
        }
    } else { // hide
        const auto tokens = m_regularTokensModel->takeAllItems(groupId);
        if (!tokens.isEmpty()) {
            for (const auto& token : tokens) {
                m_hiddenTokensModel->addItem(token, false /*prepend*/);
            }
            emit collectionTokenGroupHidden(tokens.constFirst().collectionName);
        }
        if (!m_hiddenCollectionGroups.contains(groupId)) {
            m_hiddenCollectionGroups.insert(groupId);
            emit hiddenCollectionGroupsChanged();
        }
    }
    rebuildCollectionGroupsModel();
    m_collectionGroupsModel->applySort();
    rebuildHiddenCollectionGroupsModel();
    emit requestSaveSettings(serializeSettingsAsJson());
}

// Used in testing
void ManageTokensController::clearQSettings()
{
    Q_ASSERT(!m_settingsKey.isEmpty());

    // clear the relevant QSettings group
    m_settings.beginGroup(settingsGroupName());
    m_settings.remove(QString());
    m_settings.endGroup();
    m_settings.sync();

    emit settingsDirtyChanged(false);
}


void ManageTokensController::setSettingsDirty(bool dirty)
{
    if (m_settingsDirty == dirty)
        return;
    m_settingsDirty = dirty;
    emit settingsDirtyChanged(m_settingsDirty);
}

void ManageTokensController::incRevision()
{
    m_revision++;
    emit revisionChanged();
}

QStringList ManageTokensController::hiddenCommunityGroups() const
{
    return {m_hiddenCommunityGroups.constBegin(), m_hiddenCommunityGroups.constEnd()};
}

QStringList ManageTokensController::hiddenCollectionGroups() const
{
    return {m_hiddenCollectionGroups.constBegin(), m_hiddenCollectionGroups.constEnd()};
}

void ManageTokensController::revert()
{
    emit requestLoadSettings();
}

void ManageTokensController::savingStarted()
{
    setSettingsDirty(true);
    m_settings.beginGroup(settingsGroupName());

    m_settings.setValue(QStringLiteral("ArrangeByCommunity"), m_arrangeByCommunity);
    m_settings.setValue(QStringLiteral("ArrangeByCollection"), m_arrangeByCollection);

    m_settings.endGroup();
    m_settings.sync();
}

void ManageTokensController::savingFinished()
{
    // unset dirty
    for (auto model : m_allModels)
        model->setDirty(false);

    setSettingsDirty(false);
    emit requestLoadSettings();

    incRevision();
}

void ManageTokensController::loadingStarted()
{
    setSettingsDirty(true);
    m_settingsData.clear();

    m_settings.beginGroup(settingsGroupName());

    setArrangeByCommunity(m_settings.value(QStringLiteral("ArrangeByCommunity"), false).toBool());
    setArrangeByCollection(m_settings.value(QStringLiteral("ArrangeByCollection"), false).toBool());

    m_settings.endGroup();
}

void ManageTokensController::loadingFinished(const QString& jsonData)
{
    if (!jsonData.isEmpty()) {
        auto result = tokenOrdersFromJson(jsonData, m_serializeAsCollectibles);
        if (result != m_settingsData) {
            m_settingsData = result;
        }
    }

    parseSourceModel();
    setSettingsDirty(false);
}

QString ManageTokensController::serializeSettingsAsJson()
{
    SerializedTokenData result;
    for (auto model : {m_regularTokensModel, m_communityTokensModel})
        result.insert(model->save());
    if (m_arrangeByCommunity)
        result.insert(m_communityTokenGroupsModel->save(true /* visible */, true /* itemsAreGroups */));
    if (m_arrangeByCollection)
        result.insert(m_collectionGroupsModel->save(true /* visible */, true /* itemsAreGroups */));
    result.insert(m_hiddenTokensModel->save(false));
    auto json = tokenOrdersToJson(result, m_serializeAsCollectibles);
    return json;
}

QString ManageTokensController::settingsGroupName() const
{
    return QStringLiteral("ManageTokens-%1").arg(m_settingsKey);
}

bool ManageTokensController::hasSettings() const
{
    return !m_settingsData.isEmpty();
}

int ManageTokensController::order(const QString& key) const
{
    const auto entry = m_settingsData.value(key, TokenOrder());
    return entry.visible ? entry.sortOrder : undefinedTokenOrder;
}

int ManageTokensController::compareTokens(const QString& lhsKey, const QString& rhsKey) const
{
    const auto left = m_settingsData.value(lhsKey, TokenOrder());
    const auto right = m_settingsData.value(rhsKey, TokenOrder());

    // check if visible
    auto leftPos = left.visible ? left.sortOrder : undefinedTokenOrder;
    auto rightPos = right.visible ? right.sortOrder : undefinedTokenOrder;

    if (leftPos < rightPos)
        return -1;
    if (leftPos > rightPos)
        return 1;
    return 0;
}

bool ManageTokensController::filterAcceptsKey(const QString& key) const
{
    if (key.isEmpty())
        return true;

    if (!m_settingsData.contains(key)) {
        return true;
    }
    return m_settingsData.value(key).visible;
}

QJsonObject ManageTokensController::getOwnershipTotalBalanceAndLastTimestamp(QAbstractItemModel *model, const QStringList &filterList) const
{
    if (!model)
        return {};

    constexpr auto roleByName = [](QAbstractItemModel* model, const auto &roleName) {
        return model->roleNames().key(roleName, -1);
    };

    qint64 balance = 0;
    double timestamp = 0.;

    const auto ownershipCount = model->rowCount();
    const auto accountAddressRole = roleByName(model, "accountAddress");

    for (int i = 0; i < ownershipCount; i++) {
        const auto accountAddress = model->data(model->index(i, 0), accountAddressRole).toString();
        if (accountAddress.isEmpty() || !filterList.contains(accountAddress, Qt::CaseInsensitive))
            continue;

        bool tokenBalanceOk;
        const auto tokenBalance = model->data(model->index(i, 0), roleByName(model, "balance")).toLongLong(&tokenBalanceOk);
        if (tokenBalanceOk)
            balance += tokenBalance;

        bool txTimestampOk;
        const auto txTimestamp = model->data(model->index(i, 0), roleByName(model, "txTimestamp")).toDouble(&txTimestampOk);
        if (txTimestampOk)
            timestamp = std::max(timestamp, txTimestamp);
    }

    return {{"balance", balance}, {"timestamp", timestamp}};
}

void ManageTokensController::classBegin()
{
    // empty on purpose
}

void ManageTokensController::componentComplete()
{
    emit requestLoadSettings();
}

void ManageTokensController::setSourceModel(QAbstractItemModel* newSourceModel)
{
    if (m_sourceModel == newSourceModel)
        return;

    if (!newSourceModel) {
        disconnect(sourceModel());
        cancelPendingSourceUpdates();
        // clear all the models
        for (auto model : m_allModels)
            model->clear();
        m_settingsData.clear();
        m_hiddenCommunityGroups.clear();
        m_hiddenCollectionGroups.clear();
        setSettingsDirty(false);
        m_sourceModel = newSourceModel;
        emit sourceModelChanged();
        return;
    }

    m_sourceModel = newSourceModel;

    connect(m_sourceModel, &QAbstractItemModel::modelReset, this, &ManageTokensController::parseSourceModel);

    if (m_sourceModel && m_sourceModel->roleNames().isEmpty()) { // workaround for when a model has no roles and roles
                                                                 // are added when the model is populated (ListModel)
        // QTBUG-57971
        connect(m_sourceModel, &QAbstractItemModel::rowsInserted, this, &ManageTokensController::parseSourceModel);
        return;
    } else {
        emit requestLoadSettings();
    }
}

void ManageTokensController::parseSourceModel()
{
    if (!m_sourceModel)
        return;

    // A full re-parse rebuilds everything from scratch, superseding any queued
    // in-place updates.
    cancelPendingSourceUpdates();

    disconnect(m_sourceModel, &QAbstractItemModel::rowsInserted, this, &ManageTokensController::parseSourceModel);

#ifdef QT_DEBUG
    QElapsedTimer t;
    t.start();
#endif

    // clear all the models
    for (auto model : m_allModels)
        model->clear();

    // read and transform the original data
    const auto newSize = m_sourceModel->rowCount();
    qCDebug(manageTokens) << "!!! PARSING" << newSize << "TOKENS";
    for (auto i = 0; i < newSize; i++) {
        addItem(i);
    }

    rebuildModels();

#ifdef QT_DEBUG
    qCDebug(manageTokens) << "!!! PARSING SOURCE DATA TOOK" << t.nsecsElapsed() / 1'000'000.f << "ms";
#endif

    emit sourceModelChanged();
}

bool ManageTokensController::hasPendingSourceUpdates() const
{
    return m_pendingFullReparse || !m_pendingChangedRows.isEmpty();
}

void ManageTokensController::cancelPendingSourceUpdates()
{
    if (m_sourceUpdateBatchTimer)
        m_sourceUpdateBatchTimer->stop();
    m_pendingFullReparse = false;
    m_pendingChangedRows.clear();
    m_pendingChangedRoleNames.clear();
}

void ManageTokensController::scheduleSourceUpdateFlush()
{
    if (m_sourceUpdateBatchTimer && !m_sourceUpdateBatchTimer->isActive())
        m_sourceUpdateBatchTimer->start();
}

void ManageTokensController::onSourceDataChanged(const QModelIndex& topLeft,
                                                 const QModelIndex& bottomRight,
                                                 const QList<int>& roles)
{
    if (!m_sourceModel)
        return;

    // An empty roles list means "every role changed" — treat as structural.
    if (roles.isEmpty()) {
        m_pendingFullReparse = true;
    } else if (!m_pendingFullReparse) {
        const auto sourceRoleNames = m_sourceModel->roleNames();
        for (const auto roleId : roles) {
            const auto roleName = sourceRoleNames.value(roleId);
            if (kDataOnlyRoleNames.contains(roleName))
                m_pendingChangedRoleNames.insert(roleName);
            else
                m_pendingFullReparse = true;
        }
    }

    if (!m_pendingFullReparse) {
        for (int row = topLeft.row(); row <= bottomRight.row(); ++row)
            m_pendingChangedRows.insert(row);
    }

    scheduleSourceUpdateFlush();
}

void ManageTokensController::flushPendingSourceUpdates()
{
    if (!m_sourceModel) {
        cancelPendingSourceUpdates();
        return;
    }

    if (m_pendingFullReparse) {
        parseSourceModel(); // clears pending state itself
        return;
    }

    const auto rows = m_pendingChangedRows;
    for (const auto row : rows)
        applyIncrementalDataUpdate(row);

    cancelPendingSourceUpdates();
}

void ManageTokensController::applyIncrementalDataUpdate(int sourceRow)
{
    if (!m_sourceModel || sourceRow < 0 || sourceRow >= m_sourceModel->rowCount())
        return;

    const auto sourceRoleNames = m_sourceModel->roleNames();
    const auto srcIndex = m_sourceModel->index(sourceRow, 0);
    const auto key = srcIndex.data(sourceRoleNames.key(kKeyRoleName, -1)).toString();
    if (key.isEmpty())
        return;

    // The token lives in exactly one leaf model. Group models are aggregates that
    // don't display these data-only roles, so they need no update here.
    for (auto model : {m_regularTokensModel, m_communityTokensModel, m_hiddenTokensModel}) {
        const auto row = model->rowForKey(key);
        if (row < 0)
            continue;

        TokenData& token = model->itemAt(row);
        QList<int> changedRoles;

        const auto dataForRole = [&](const QByteArray& rolename) {
            return srcIndex.data(sourceRoleNames.key(rolename, -1));
        };

        for (const auto& roleName : m_pendingChangedRoleNames) {
            if (roleName == kEnabledNetworkBalanceRoleName) {
                token.balance = dataForRole(kEnabledNetworkBalanceRoleName);
                changedRoles << ManageTokensModel::BalanceRole;
            } else if (roleName == kEnabledNetworkCurrencyBalanceRoleName) {
                token.currencyBalance = dataForRole(kEnabledNetworkCurrencyBalanceRoleName);
                changedRoles << ManageTokensModel::CurrencyBalanceRole;
            } else if (roleName == kBalancesRoleName) {
                token.balances = dataForRole(kBalancesRoleName);
                changedRoles << ManageTokensModel::TokenBalancesRole;
            } else if (roleName == kDecimalsRoleName) {
                token.decimals = dataForRole(kDecimalsRoleName);
                changedRoles << ManageTokensModel::TokenDecimalsRole;
            } else if (roleName == kMarketDetailsRoleName) {
                token.marketDetails = dataForRole(kMarketDetailsRoleName);
                changedRoles << ManageTokensModel::TokenMarketDetailsRole;
            }
        }

        if (!changedRoles.isEmpty())
            model->notifyItemChanged(row, changedRoles);
        return;
    }
}

void ManageTokensController::rebuildModels()
{
    // build community groups model
    rebuildCommunityTokenGroupsModel();
    rebuildHiddenCommunityTokenGroupsModel();

    // build collections
    rebuildCollectionGroupsModel();
    rebuildHiddenCollectionGroupsModel();

    // (pre)sort
    for (auto model : m_allModels) {
        model->applySort();
        model->setDirty(false);
    }
}

void ManageTokensController::addItem(int index)
{
    const auto sourceRoleNames = m_sourceModel->roleNames();

    const auto dataForIndex = [&](const QModelIndex& idx, const QByteArray& rolename) -> QVariant {
        const auto key = sourceRoleNames.key(rolename, -1);
        if (key == -1)
            return {};
        return idx.data(key);
    };

    const auto srcIndex = m_sourceModel->index(index, 0);
    const auto key = dataForIndex(srcIndex, kKeyRoleName).toString();
    const auto communityId = dataForIndex(srcIndex, kCommunityIdRoleName).toString();
    const auto communityName = dataForIndex(srcIndex, kCommunityNameRoleName).toString();
    const auto visible = m_settingsData.contains(key) ? m_settingsData.value(key).visible : true;
    const auto bgColor = dataForIndex(srcIndex, kBackgroundColorRoleName).value<QColor>();
    const auto collectionUid = dataForIndex(srcIndex, kCollectionUidRoleName).toString();

    TokenData token;
    token.key = key;
    token.tokenKey = dataForIndex(srcIndex, kTokenKeyRoleName).toString();
    token.crossChainId = dataForIndex(srcIndex, kCrossChainIdRoleName).toString();
    token.symbol = dataForIndex(srcIndex, kSymbolRoleName).toString();
    token.name = dataForIndex(srcIndex, kNameRoleName).toString();
    token.image = dataForIndex(srcIndex, kTokenImageUrlRoleName).toString();
    if (token.image.isEmpty()) {
        token.image = dataForIndex(srcIndex, kTokenImageRoleName).toString();
    }
    if (token.image.isEmpty()) {
        token.image = dataForIndex(srcIndex, kCollectibleMediaUrlRoleName).toString();
    }
    if (bgColor.isValid())
        token.backgroundColor = bgColor;
    token.communityId = communityId;
    token.communityName = !communityName.isEmpty() ? communityName : communityId;
    token.communityImage = dataForIndex(srcIndex, kCommunityImageRoleName).toString();
    token.collectionUid = !collectionUid.isEmpty() ? collectionUid : key;
    token.isSelfCollection = collectionUid.isEmpty();
    token.collectionName = dataForIndex(srcIndex, kCollectionNameRoleName).toString();
    token.balance = dataForIndex(srcIndex, kEnabledNetworkBalanceRoleName);
    token.currencyBalance = dataForIndex(srcIndex, kEnabledNetworkCurrencyBalanceRoleName);
    token.balances = dataForIndex(srcIndex, kBalancesRoleName);
    token.decimals = dataForIndex(srcIndex, kDecimalsRoleName);
    token.marketDetails = dataForIndex(srcIndex, kMarketDetailsRoleName);

    // proxy roles
    token.groupName = !communityId.isEmpty() ? token.communityName : token.collectionName;

    token.customSortOrderNo = m_settingsData.contains(key) ? m_settingsData.value(key).sortOrder
                                                              : (visible ? undefinedTokenOrder : 0); // append/prepend

    if (!visible)
        m_hiddenTokensModel->addItem(token, /*append*/ false);
    else if (!communityId.isEmpty())
        m_communityTokensModel->addItem(token);
    else
        m_regularTokensModel->addItem(token);
}

bool ManageTokensController::dirty() const
{
    return std::any_of(m_allModels.cbegin(), m_allModels.cend(), [](auto model) { return model->dirty(); });
}

bool ManageTokensController::arrangeByCommunity() const { return m_arrangeByCommunity; }

void ManageTokensController::setArrangeByCommunity(bool newArrangeByCommunity)
{
    if (m_arrangeByCommunity == newArrangeByCommunity)
        return;
    m_arrangeByCommunity = newArrangeByCommunity;
    if (m_arrangeByCommunity) {
        rebuildCommunityTokenGroupsModel();
        m_communityTokenGroupsModel->applySortByTokensAmount();
        m_communityTokenGroupsModel->setDirty(true);
    }
    emit arrangeByCommunityChanged();
}

bool ManageTokensController::arrangeByCollection() const { return m_arrangeByCollection; }

void ManageTokensController::setArrangeByCollection(bool newArrangeByCollection)
{
    if (m_arrangeByCollection == newArrangeByCollection)
        return;
    m_arrangeByCollection = newArrangeByCollection;
    if (m_arrangeByCollection) {
        rebuildCollectionGroupsModel();
        m_collectionGroupsModel->applySortByTokensAmount();
        m_collectionGroupsModel->setDirty(true);
    }
    emit arrangeByCollectionChanged();
}

void ManageTokensController::rebuildCommunityTokenGroupsModel()
{
    QStringList communityIds;
    QList<TokenData> result;

    const auto count = m_communityTokensModel->rowCount();
    for (auto i = 0; i < count; i++) {
        const auto& communityToken = m_communityTokensModel->itemAt(i);
        const auto communityId = communityToken.communityId;
        if (!communityIds.contains(communityId)) { // insert into groups
            communityIds.append(communityId);

            const auto collectionName =
                !communityToken.collectionName.isEmpty() ? communityToken.collectionName : communityToken.name;

            TokenData tokenGroup;
            tokenGroup.key = communityToken.key;
            tokenGroup.tokenKey = communityToken.tokenKey;
            tokenGroup.crossChainId = communityToken.crossChainId;
            tokenGroup.symbol = communityToken.symbol;
            tokenGroup.communityId = communityToken.communityId;
            tokenGroup.collectionName = collectionName;
            tokenGroup.communityName = communityToken.communityName;
            tokenGroup.communityImage = communityToken.communityImage;
            tokenGroup.backgroundColor = communityToken.backgroundColor;
            tokenGroup.balance = 1;
            tokenGroup.groupName = !communityId.isEmpty() ? tokenGroup.communityName : tokenGroup.collectionName;

            if (m_settingsData.contains(communityId)) {
                tokenGroup.customSortOrderNo = m_settingsData.value(communityId).sortOrder;
            }

            result.append(tokenGroup);
        } else { // update group's childCount
            const auto tokenGroup = std::find_if(result.cbegin(), result.cend(), [communityId](const auto& item) {
                return communityId == item.communityId;
            });
            if (tokenGroup != result.cend()) {
                const auto row = std::distance(result.cbegin(), tokenGroup);
                TokenData& updTokenGroup = result[row];
                updTokenGroup.balance = updTokenGroup.balance.toInt() + 1;
            }
        }
    }

    m_communityTokenGroupsModel->clear();
    for (const auto& group : std::as_const(result))
        m_communityTokenGroupsModel->addItem(group);

    // rebuild hidden community groups
    m_hiddenCommunityGroups.clear();
    for (auto i = 0; i < m_communityTokenGroupsModel->rowCount(); i++) {
        const auto& group = m_communityTokenGroupsModel->itemAt(i);
        if (m_settingsData.contains(group.communityId) && !m_settingsData.value(group.communityId).visible) {
            m_hiddenCommunityGroups.insert(group.communityId);
        }
    }
    emit hiddenCommunityGroupsChanged();

    qCDebug(manageTokens) << "!!! GROUPS MODEL REBUILT WITH GROUPS:" << communityIds;
}

void ManageTokensController::rebuildHiddenCommunityTokenGroupsModel()
{
    QStringList communityIds;
    QList<TokenData> result;

    const auto count = m_hiddenTokensModel->rowCount();
    for (auto i = 0; i < count; i++) {
        const auto& communityToken = m_hiddenTokensModel->itemAt(i);
        const auto communityId = communityToken.communityId;
        if (communityId.isEmpty())
            continue;
        if (!communityIds.contains(communityId) &&
            m_hiddenCommunityGroups.contains(communityId)) { // insert into groups
            communityIds.append(communityId);

            const auto collectionName =
                !communityToken.collectionName.isEmpty() ? communityToken.collectionName : communityToken.name;

            TokenData tokenGroup;
            tokenGroup.key = communityToken.key;
            tokenGroup.tokenKey = communityToken.tokenKey;
            tokenGroup.crossChainId = communityToken.crossChainId;
            tokenGroup.symbol = communityToken.symbol;
            tokenGroup.communityId = communityToken.communityId;
            tokenGroup.collectionName = collectionName;
            tokenGroup.communityName = communityToken.communityName;
            tokenGroup.communityImage = communityToken.communityImage;
            tokenGroup.backgroundColor = communityToken.backgroundColor;
            tokenGroup.balance = 1;
            tokenGroup.groupName = !communityId.isEmpty() ? tokenGroup.communityName : collectionName;
            result.append(tokenGroup);
        } else { // update group's childCount
            const auto tokenGroup = std::find_if(result.cbegin(), result.cend(), [communityId](const auto& item) {
                return communityId == item.communityId;
            });
            if (tokenGroup != result.cend()) {
                const auto row = std::distance(result.cbegin(), tokenGroup);
                TokenData& updTokenGroup = result[row];
                updTokenGroup.balance = updTokenGroup.balance.toInt() + 1;
            }
        }
    }

    m_hiddenCommunityTokenGroupsModel->clear();
    for (const auto& group : std::as_const(result))
        m_hiddenCommunityTokenGroupsModel->addItem(group);

    qCDebug(manageTokens) << "!!! HIDDEN GROUPS MODEL REBUILT WITH GROUPS:" << communityIds;
}

void ManageTokensController::rebuildCollectionGroupsModel()
{
    QStringList collectionIds;
    QList<TokenData> result;

    const auto count = m_regularTokensModel->rowCount();
    for (auto i = 0; i < count; i++) {
        const auto& collectionToken = m_regularTokensModel->itemAt(i);
        const auto collectionId = collectionToken.collectionUid;
        const auto isSelfCollection = collectionToken.isSelfCollection;
        if (!collectionIds.contains(collectionId)) { // insert into groups
            collectionIds.append(collectionId);

            const auto collectionName =
                !collectionToken.collectionName.isEmpty() ? collectionToken.collectionName : collectionToken.name;

            TokenData tokenGroup;
            tokenGroup.key = collectionToken.key;
            tokenGroup.tokenKey = collectionToken.tokenKey;
            tokenGroup.crossChainId = collectionToken.crossChainId;
            tokenGroup.symbol = collectionToken.symbol;
            tokenGroup.collectionUid = collectionToken.collectionUid;
            tokenGroup.isSelfCollection = isSelfCollection;
            tokenGroup.collectionName = collectionName;
            tokenGroup.image = collectionToken.image;
            tokenGroup.backgroundColor = collectionToken.backgroundColor;
            tokenGroup.balance = 1;
            tokenGroup.groupName = collectionName;

            if (m_settingsData.contains(collectionId)) {
                tokenGroup.customSortOrderNo = m_settingsData.value(collectionId).sortOrder;
            }

            result.append(tokenGroup);
        } else if (!isSelfCollection) { // update group's childCount
            const auto tokenGroup = std::find_if(result.cbegin(), result.cend(), [collectionId](const auto& item) {
                return collectionId == item.collectionUid;
            });
            if (tokenGroup != result.cend()) {
                const auto row = std::distance(result.cbegin(), tokenGroup);
                TokenData& updTokenGroup = result[row];
                updTokenGroup.balance = updTokenGroup.balance.toInt() + 1;
            }
        }
    }

    m_collectionGroupsModel->clear();
    for (const auto& group : std::as_const(result))
        m_collectionGroupsModel->addItem(group);

    // rebuild hidden collection groups
    m_hiddenCollectionGroups.clear();
    for (auto i = 0; i < m_collectionGroupsModel->rowCount(); i++) {
        const auto& group = m_collectionGroupsModel->itemAt(i);
        if (m_settingsData.contains(group.collectionUid) && !m_settingsData.value(group.collectionUid).visible) {
            m_hiddenCollectionGroups.insert(group.collectionUid);
        }
    }
    emit hiddenCollectionGroupsChanged();


    qCDebug(manageTokens) << "!!! COLLECTION MODEL REBUILT WITH GROUPS:" << collectionIds;
}

void ManageTokensController::rebuildHiddenCollectionGroupsModel()
{
    QStringList collectionIds;
    QList<TokenData> result;

    const auto count = m_hiddenTokensModel->rowCount();
    for (auto i = 0; i < count; i++) {
        const auto& collectionToken = m_hiddenTokensModel->itemAt(i);
        const auto collectionId = collectionToken.collectionUid;
        const auto isSelfCollection = collectionToken.isSelfCollection;
        if (!collectionIds.contains(collectionId) &&
            m_hiddenCollectionGroups.contains(collectionId)) { // insert into groups
            collectionIds.append(collectionId);

            const auto collectionName =
                !collectionToken.collectionName.isEmpty() ? collectionToken.collectionName : collectionToken.name;

            TokenData tokenGroup;
            tokenGroup.key = collectionToken.key;
            tokenGroup.tokenKey = collectionToken.tokenKey;
            tokenGroup.crossChainId = collectionToken.crossChainId;
            tokenGroup.symbol = collectionToken.symbol;
            tokenGroup.collectionUid = collectionToken.collectionUid;
            tokenGroup.isSelfCollection = isSelfCollection;
            tokenGroup.collectionName = collectionName;
            tokenGroup.image = collectionToken.image;
            tokenGroup.backgroundColor = collectionToken.backgroundColor;
            tokenGroup.balance = 1;
            tokenGroup.groupName = collectionName;
            result.append(tokenGroup);
        } else if (!isSelfCollection) { // update group's childCount
            const auto tokenGroup = std::find_if(result.cbegin(), result.cend(), [collectionId](const auto& item) {
                return collectionId == item.collectionUid;
            });
            if (tokenGroup != result.cend()) {
                const auto row = std::distance(result.cbegin(), tokenGroup);
                TokenData& updTokenGroup = result[row];
                updTokenGroup.balance = updTokenGroup.balance.toInt() + 1;
            }
        }
    }

    m_hiddenCollectionGroupsModel->clear();
    for (const auto& group : std::as_const(result))
        m_hiddenCollectionGroupsModel->addItem(group);

    qCDebug(manageTokens) << "!!! HIDDEN COLLECTION GROUPS MODEL REBUILT WITH GROUPS:" << collectionIds;
}

QString ManageTokensController::settingsKey() const { return m_settingsKey; }

void ManageTokensController::setSettingsKey(const QString& newSettingsKey)
{
    if (m_settingsKey == newSettingsKey)
        return;
    m_settingsKey = newSettingsKey;
    emit settingsKeyChanged();
}

bool ManageTokensController::serializeAsCollectibles() const { return m_serializeAsCollectibles; }

void ManageTokensController::setSerializeAsCollectibles(const bool newSerializeAsCollectibles)
{
    if (m_serializeAsCollectibles == newSerializeAsCollectibles)
        return;
    m_serializeAsCollectibles = newSerializeAsCollectibles;
    emit serializeAsCollectiblesChanged();
}
