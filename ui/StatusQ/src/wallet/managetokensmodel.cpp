#include "managetokensmodel.h"

#include <algorithm>

Q_LOGGING_CATEGORY(manageTokens, "status.models.manageTokens", QtInfoMsg)

ManageTokensModel::ManageTokensModel(QObject* parent) : QAbstractListModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &ManageTokensModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &ManageTokensModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &ManageTokensModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &ManageTokensModel::countChanged);
}

void ManageTokensModel::moveItem(int fromRow, int toRow)
{
    qCDebug(manageTokens) << Q_FUNC_INFO << "from" << fromRow << "to" << toRow;

    if (toRow < 0 || toRow >= rowCount() || fromRow < 0 || fromRow >= rowCount())
        return;

    auto destRow = toRow;
    if (toRow > fromRow)
        destRow++;

    beginMoveRows({}, fromRow, fromRow, {}, destRow);
    m_data.move(fromRow, toRow);
    endMoveRows();
    setDirty(true);
}

void ManageTokensModel::addItem(const TokenData& item, bool append)
{
    const auto destRow = append ? rowCount() : 0;
    beginInsertRows({}, destRow, destRow);
    append ? m_data.append(item) : m_data.prepend(item);
    endInsertRows();
}

std::optional<TokenData> ManageTokensModel::takeItem(const QString& key)
{
    const auto token =
        std::find_if(m_data.cbegin(), m_data.cend(), [key](const auto& item) { return key == item.key; });
    const auto row = std::distance(m_data.cbegin(), token);

    if (row < 0 || row >= rowCount())
        return {};

    beginRemoveRows({}, row, row);
    auto res = m_data.takeAt(row);
    endRemoveRows();
    return res;
}

QList<TokenData> ManageTokensModel::takeAllItems(const QString& groupId)
{
    QList<TokenData> result;
    QList<int> indexesToRemove;

    for (int i = 0; i < m_data.count(); i++) {
        const auto& token = m_data.at(i);
        if (token.communityId == groupId || token.collectionUid == groupId) {
            result.append(token);
            indexesToRemove.append(i);
        }
    }

    QList<int>::reverse_iterator its;
    for (its = indexesToRemove.rbegin(); its != indexesToRemove.rend(); ++its) {
        const auto row = *its;
        beginRemoveRows({}, row, row);
        m_data.removeAt(row);
        endRemoveRows();
    }

    return result;
}

int ManageTokensModel::rowForKey(const QString& key) const
{
    for (int i = 0; i < m_data.size(); ++i) {
        if (m_data.at(i).key == key)
            return i;
    }
    return -1;
}

void ManageTokensModel::notifyItemChanged(int row, const QList<int>& roles)
{
    if (row < 0 || row >= m_data.size())
        return;
    const auto idx = index(row, 0);
    emit dataChanged(idx, idx, roles);
}

void ManageTokensModel::clear()
{
    beginResetModel();
    m_data.clear();
    endResetModel();
    setDirty(false);
}

SerializedTokenData ManageTokensModel::save(bool isVisible, bool itemsAreGroups)
{
    saveCustomSortOrder();
    const auto size = rowCount();
    SerializedTokenData result;
    result.reserve(size);
    for (int i = 0; i < size; i++) {
        const auto& token = itemAt(i);
        const auto isCommunityGroup = !token.communityId.isEmpty();
        const auto isCollectionGroup = !token.collectionUid.isEmpty();
        result.insert(token.key,
                      TokenOrder{token.key,
                                 i,
                                 isVisible,
                                 isCommunityGroup,
                                 token.communityId,
                                 isCollectionGroup,
                                 token.collectionUid,
                                 tokenDataToCollectiblePreferencesItemType(isCommunityGroup, itemsAreGroups)});
    }
    setDirty(false);
    return result;
}

int ManageTokensModel::rowCount(const QModelIndex& parent) const { return m_data.size(); }

QHash<int, QByteArray> ManageTokensModel::roleNames() const
{
    static const QHash<int, QByteArray> roles{
        {KeyRole, kKeyRoleName},
        {TokenKeyRole, kTokenKeyRoleName},
        {CrossChainIdRole, kCrossChainIdRoleName},
        {ChainIdRole, kChainIdRoleName},
        {AddressRole, kAddressRoleName},
        {SymbolRole, kSymbolRoleName},
        {NameRole, kNameRoleName},
        {CommunityIdRole, kCommunityIdRoleName},
        {CommunityNameRole, kCommunityNameRoleName},
        {CommunityImageRole, kCommunityImageRoleName},
        {CollectionUidRole, kCollectionUidRoleName},
        {CollectionNameRole, kCollectionNameRoleName},
        {BalanceRole, kEnabledNetworkBalanceRoleName},
        {CurrencyBalanceRole, kEnabledNetworkCurrencyBalanceRoleName},
        {CustomSortOrderNoRole, kCustomSortOrderNoRoleName},
        {TokenImageRole, kTokenImageUrlRoleName},
        {TokenBackgroundColorRole, kBackgroundColorRoleName},
        {TokenBalancesRole, kBalancesRoleName},
        {TokenDecimalsRole, kDecimalsRoleName},
        {TokenMarketDetailsRole, kMarketDetailsRoleName},
        {IsSelfCollectionRole, kIsSelfCollectionRoleName},
        {GroupNameRole, kGroupNameRoleName},
    };

    return roles;
}

QVariant ManageTokensModel::data(const QModelIndex& index, int role) const
{
    if (!checkIndex(index,
                    QAbstractItemModel::CheckIndexOption::IndexIsValid |
                        QAbstractItemModel::CheckIndexOption::ParentIsInvalid))
        return {};

    const auto& token = m_data.at(index.row());

    switch (static_cast<TokenDataRoles>(role)) {
    case KeyRole:
        return token.key;
    case TokenKeyRole:
        return token.tokenKey;
    case CrossChainIdRole:
        return token.crossChainId;
    case ChainIdRole:
        return token.chainId;
    case AddressRole:
        return token.address;
    case SymbolRole:
        return token.symbol;
    case NameRole:
        return token.name;
    case CommunityIdRole:
        return token.communityId;
    case CommunityNameRole:
        return token.communityName;
    case CommunityImageRole:
        return token.communityImage;
    case CollectionUidRole:
        return token.collectionUid;
    case CollectionNameRole:
        return token.collectionName;
    case BalanceRole:
        return token.balance;
    case CurrencyBalanceRole:
        return token.currencyBalance;
    case CustomSortOrderNoRole:
        return token.customSortOrderNo;
    case TokenImageRole:
        return token.image;
    case TokenBackgroundColorRole:
        return token.backgroundColor;
    case TokenBalancesRole:
        return token.balances;
    case TokenDecimalsRole:
        return token.decimals;
    case TokenMarketDetailsRole:
        return token.marketDetails;
    case IsSelfCollectionRole:
        return token.isSelfCollection;
    case GroupNameRole:
        return token.groupName;
    }

    return {};
}

bool ManageTokensModel::dirty() const { return m_dirty; }

void ManageTokensModel::setDirty(bool flag)
{
    if (m_dirty == flag)
        return;
    m_dirty = flag;
    emit dirtyChanged();
}

void ManageTokensModel::saveCustomSortOrder()
{
    const auto count = rowCount();
    for (auto i = 0; i < count; i++) {
        m_data[i].customSortOrderNo = i;
    }
    if (count > 0)
        emit dataChanged(index(0, 0), index(count - 1, 0), {TokenDataRoles::CustomSortOrderNoRole});
}

void ManageTokensModel::applySort()
{
    emit layoutAboutToBeChanged({}, QAbstractItemModel::VerticalSortHint);

    // clazy:exclude=clazy-detaching-member
    std::stable_sort(m_data.begin(), m_data.end(), [this](const TokenData& lhs, const TokenData& rhs) {
        return lhs.customSortOrderNo < rhs.customSortOrderNo;
    });

    emit layoutChanged({}, QAbstractItemModel::VerticalSortHint);
}

void ManageTokensModel::applySortByTokensAmount()
{
    emit layoutAboutToBeChanged({}, QAbstractItemModel::VerticalSortHint);

    // clazy:exclude=clazy-detaching-member
    std::stable_sort(m_data.begin(), m_data.end(), [this](const TokenData& lhs, const TokenData& rhs) {
        return lhs.balance.toLongLong() > rhs.balance.toLongLong();
    });

    emit layoutChanged({}, QAbstractItemModel::VerticalSortHint);
}
