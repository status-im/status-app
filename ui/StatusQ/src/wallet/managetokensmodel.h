#pragma once

#include "tokendata.h"

#include <QAbstractListModel>
#include <QColor>
#include <QLoggingCategory>

#include <optional>

Q_DECLARE_LOGGING_CATEGORY(manageTokens)

namespace
{
const auto kKeyRoleName = "key";
const auto kTokenKeyRoleName = "tokenKey";
const auto kCrossChainIdRoleName = "crossChainId";
const auto kChainIdRoleName = "chainId";
const auto kAddressRoleName = "address";
const auto kSymbolRoleName = "symbol";
const auto kNameRoleName = "name";
const auto kCommunityIdRoleName = "communityId";
const auto kCommunityNameRoleName = "communityName";
const auto kCommunityImageRoleName = "communityImage";
const auto kCollectionUidRoleName = "collectionUid";
const auto kCollectionNameRoleName = "collectionName";
const auto kEnabledNetworkBalanceRoleName = "enabledNetworkBalance"; // TODO add an extra (separate role) for group->childCount
const auto kEnabledNetworkCurrencyBalanceRoleName = "enabledNetworkCurrencyBalance";
const auto kCustomSortOrderNoRoleName = "customSortOrderNo";
const auto kTokenImageUrlRoleName = "imageUrl";
const auto kTokenImageRoleName = "image";
const auto kCollectibleMediaUrlRoleName = "mediaUrl";
const auto kBackgroundColorRoleName = "backgroundColor";
const auto kBalancesRoleName = "balances";
const auto kDecimalsRoleName = "decimals";
const auto kMarketDetailsRoleName = "marketDetails";
const auto kIsSelfCollectionRoleName = "isSelfCollection";
// TODO add communityPrivilegesLevel for collectibles

// proxy roles
const auto kGroupNameRoleName = "groupName";
} // namespace

class ManageTokensModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged FINAL)

public:
    enum TokenDataRoles {
        KeyRole = Qt::UserRole + 1,
        TokenKeyRole,
        CrossChainIdRole,
        ChainIdRole,
        AddressRole,
        SymbolRole,
        NameRole,
        CommunityIdRole,
        CommunityNameRole,
        CommunityImageRole,
        CollectionUidRole,
        CollectionNameRole,
        BalanceRole,
        CurrencyBalanceRole,
        CustomSortOrderNoRole,
        TokenImageRole,
        TokenBackgroundColorRole,
        TokenBalancesRole,
        TokenDecimalsRole,
        TokenMarketDetailsRole,
        IsSelfCollectionRole,
        //proxy roles
        GroupNameRole,
    };
    Q_ENUM(TokenDataRoles)

    explicit ManageTokensModel(QObject* parent = nullptr);

    Q_INVOKABLE void moveItem(int fromRow, int toRow);

    void addItem(const TokenData& item, bool append = true);
    std::optional<TokenData> takeItem(const QString& key);
    QList<TokenData> takeAllItems(const QString& groupId);
    void clear();

    SerializedTokenData save(bool isVisible = true, bool itemsAreGroups = false);

    bool dirty() const;
    void setDirty(bool flag);

    void saveCustomSortOrder();
    void applySort();
    void applySortByTokensAmount();

    const TokenData& itemAt(int row) const { return m_data.at(row); }
    TokenData& itemAt(int row) { return m_data[row]; }

    /// Row holding the item with the given key, or -1 if absent.
    int rowForKey(const QString& key) const;
    /// Emit dataChanged for a single already-mutated row (used for in-place updates).
    void notifyItemChanged(int row, const QList<int>& roles);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;

signals:
    void countChanged();
    void dirtyChanged();

private:
    bool m_dirty{false};

    QList<TokenData> m_data;
};
