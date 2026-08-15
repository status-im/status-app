#pragma once

#include <QObject>
#include <QVariantList>

#include "generatedlistmodel.h"

// Deterministic generator for a large wallet profile: accounts, per-chain token
// groups, per-(token, chain, account) balances, the terminal assets view and a
// paginated collectibles universe. Everything derives from `seed`, so a page
// reload with the same knobs produces byte-identical data.
//
// The heavy models are built here rather than in JS because at 10x the realistic
// profile (~20k asset groups, ~5k collectibles) JS generation would dominate any
// measurement taken through the page.
class WalletMockProfile : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int seed READ seed WRITE setSeed NOTIFY seedChanged)
    Q_PROPERTY(int accountCount READ accountCount WRITE setAccountCount NOTIFY accountCountChanged)
    Q_PROPERTY(int assetGroupCount READ assetGroupCount WRITE setAssetGroupCount
               NOTIFY assetGroupCountChanged)
    Q_PROPERTY(int collectibleCount READ collectibleCount WRITE setCollectibleCount
               NOTIFY collectibleCountChanged)
    Q_PROPERTY(int communityCount READ communityCount WRITE setCommunityCount
               NOTIFY communityCountChanged)
    Q_PROPERTY(int savedAddressCount READ savedAddressCount WRITE setSavedAddressCount
               NOTIFY savedAddressCountChanged)
    Q_PROPERTY(int followingAddressCount READ followingAddressCount WRITE setFollowingAddressCount
               NOTIFY followingAddressCountChanged)
    Q_PROPERTY(int collectiblesPageSize READ collectiblesPageSize WRITE setCollectiblesPageSize
               NOTIFY collectiblesPageSizeChanged)
    Q_PROPERTY(bool watchOnlyOnly READ watchOnlyOnly WRITE setWatchOnlyOnly NOTIFY watchOnlyOnlyChanged)
    // Chain ids the generated tokens spread over, taken from the storybook
    // networks model so the harness and the networks mock agree.
    Q_PROPERTY(QVariantList chainIds READ chainIds WRITE setChainIds NOTIFY chainIdsChanged)

    Q_PROPERTY(GeneratedListModel* assetsModel READ assetsModel CONSTANT)
    Q_PROPERTY(GeneratedListModel* tokenGroupsModel READ tokenGroupsModel CONSTANT)
    Q_PROPERTY(GeneratedListModel* groupedAccountAssetsModel READ groupedAccountAssetsModel CONSTANT)
    Q_PROPERTY(GeneratedListModel* collectiblesModel READ collectiblesModel CONSTANT)

public:
    explicit WalletMockProfile(QObject* parent = nullptr);

    int seed() const { return m_seed; }
    void setSeed(int seed);
    int accountCount() const { return m_accountCount; }
    void setAccountCount(int value);
    int assetGroupCount() const { return m_assetGroupCount; }
    void setAssetGroupCount(int value);
    int collectibleCount() const { return m_collectibleCount; }
    void setCollectibleCount(int value);
    int communityCount() const { return m_communityCount; }
    void setCommunityCount(int value);
    int savedAddressCount() const { return m_savedAddressCount; }
    void setSavedAddressCount(int value);
    int followingAddressCount() const { return m_followingAddressCount; }
    void setFollowingAddressCount(int value);
    int collectiblesPageSize() const { return m_collectiblesPageSize; }
    void setCollectiblesPageSize(int value);
    bool watchOnlyOnly() const { return m_watchOnlyOnly; }
    void setWatchOnlyOnly(bool value);
    QVariantList chainIds() const { return m_chainIds; }
    void setChainIds(const QVariantList& chainIds);

    GeneratedListModel* assetsModel() const { return m_assetsModel; }
    GeneratedListModel* tokenGroupsModel() const { return m_tokenGroupsModel; }
    GeneratedListModel* groupedAccountAssetsModel() const { return m_groupedAccountAssetsModel; }
    GeneratedListModel* collectiblesModel() const { return m_collectiblesModel; }

    // Fills every model. Small collections (accounts, communities, addresses)
    // are returned as plain lists for the QML mocks to append into ListModels.
    Q_INVOKABLE void generate();
    Q_INVOKABLE void clear();

    Q_INVOKABLE QVariantList accounts() const { return m_accounts; }
    Q_INVOKABLE QVariantList communities() const { return m_communities; }
    Q_INVOKABLE QVariantList savedAddresses() const { return m_savedAddresses; }
    // Paginated like the backend's fetchFollowingAddresses.
    Q_INVOKABLE QVariantList followingAddresses(const QString& search, int limit, int offset) const;
    Q_INVOKABLE int followingAddressesTotal(const QString& search) const;

    Q_INVOKABLE QString accountAddress(int index) const;
    Q_INVOKABLE QVariantMap accountByAddress(const QString& address) const;

    // Re-sorts the terminal assets view, like walletSectionAssetsView.sortBy.
    Q_INVOKABLE void sortAssets(const QString& roleName, int order);

    // Account-switch / reload dynamics: flip the loading flags and perturb the
    // balances so the whole assets chain re-evaluates the way a reload does.
    Q_INVOKABLE void setAssetsLoading(bool loading);
    Q_INVOKABLE void refreshBalances();

    Q_INVOKABLE void loadMoreCollectibles();

    Q_INVOKABLE QString uidForCollectible(const QString& tokenId, const QString& contractAddress,
                                          int chainId) const;

signals:
    void seedChanged();
    void accountCountChanged();
    void assetGroupCountChanged();
    void collectibleCountChanged();
    void communityCountChanged();
    void savedAddressCountChanged();
    void followingAddressCountChanged();
    void collectiblesPageSizeChanged();
    void watchOnlyOnlyChanged();
    void chainIdsChanged();
    void generated();

private:
    void generateAccounts();
    void generateCommunities();
    void generateTokens();
    void generateCollectibles();
    void generateAddressBooks();

    QList<int> effectiveChainIds() const;

    int m_seed = 1;
    int m_accountCount = 8;
    int m_assetGroupCount = 2000;
    int m_collectibleCount = 500;
    int m_communityCount = 5;
    int m_savedAddressCount = 20;
    int m_followingAddressCount = 120;
    int m_collectiblesPageSize = 100;
    bool m_watchOnlyOnly = false;
    QVariantList m_chainIds;

    GeneratedListModel* m_assetsModel = nullptr;
    GeneratedListModel* m_tokenGroupsModel = nullptr;
    GeneratedListModel* m_groupedAccountAssetsModel = nullptr;
    GeneratedListModel* m_collectiblesModel = nullptr;

    QVariantList m_accounts;
    QVariantList m_communities;
    QVariantList m_savedAddresses;
    QVariantList m_following;
};
