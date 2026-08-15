#include "walletmockprofile.h"

#include "generatedlistmodel.h"

#include <QStringList>
#include <QVariantMap>

#include <array>

namespace {

// splitmix64 — deterministic, seed-derived, no global state. Every generated
// value is a pure function of (seed, index, salt), so the profile is
// reproducible across runs and across the interactive/validator profiles.
quint64 mix(quint64 x)
{
    x += 0x9e3779b97f4a7c15ULL;
    x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
    x = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
    return x ^ (x >> 31);
}

quint64 hash2(int seed, int index, quint64 salt)
{
    return mix((quint64(quint32(seed)) << 32) ^ (quint64(quint32(index)) * 0x100000001b3ULL) ^ salt);
}

double unitOf(quint64 h)
{
    return double(h % 1000000ULL) / 1000000.0;
}

QString addressFor(quint64 h)
{
    return QStringLiteral("0x%1%2").arg(h, 16, 16, QLatin1Char('0'))
            .arg(mix(h), 24, 16, QLatin1Char('0'));
}

struct CuratedToken {
    const char* symbol;
    const char* name;
    int decimals;
    double price;
};

// A realistic head so symbols, decimals and price magnitudes look like a real
// whale address; the procedural tail behind it only needs to reach scale.
constexpr std::array<CuratedToken, 40> curatedTokens{{
    {"ETH", "Ether", 18, 3120.44},
    {"USDC", "USD Coin", 6, 1.0},
    {"USDT", "Tether USD", 6, 1.0},
    {"DAI", "Dai Stablecoin", 18, 1.0},
    {"WBTC", "Wrapped Bitcoin", 8, 64150.0},
    {"SNT", "Status Network Token", 18, 0.0412},
    {"WETH", "Wrapped Ether", 18, 3119.10},
    {"stETH", "Lido Staked Ether", 18, 3110.02},
    {"LINK", "Chainlink", 18, 17.23},
    {"UNI", "Uniswap", 18, 9.84},
    {"AAVE", "Aave", 18, 92.11},
    {"MKR", "Maker", 18, 2480.0},
    {"CRV", "Curve DAO Token", 18, 0.51},
    {"LDO", "Lido DAO Token", 18, 2.07},
    {"ARB", "Arbitrum", 18, 1.13},
    {"OP", "Optimism", 18, 2.35},
    {"MATIC", "Polygon", 18, 0.72},
    {"COMP", "Compound", 18, 58.4},
    {"SUSHI", "SushiSwap", 18, 1.09},
    {"1INCH", "1inch Network", 18, 0.44},
    {"GRT", "The Graph", 18, 0.27},
    {"BAT", "Basic Attention Token", 18, 0.24},
    {"ENS", "Ethereum Name Service", 18, 24.7},
    {"RPL", "Rocket Pool", 18, 27.9},
    {"FRAX", "Frax", 18, 0.998},
    {"LUSD", "Liquity USD", 18, 1.002},
    {"RAI", "Rai Reflex Index", 18, 2.86},
    {"BAL", "Balancer", 18, 3.61},
    {"YFI", "yearn.finance", 18, 6840.0},
    {"SAND", "The Sandbox", 18, 0.39},
    {"MANA", "Decentraland", 18, 0.42},
    {"APE", "ApeCoin", 18, 1.16},
    {"BLUR", "Blur", 18, 0.21},
    {"PEPE", "Pepe", 18, 0.0000082},
    {"SHIB", "Shiba Inu", 18, 0.0000175},
    {"GNO", "Gnosis", 18, 214.5},
    {"CVX", "Convex Finance", 18, 2.74},
    {"FXS", "Frax Share", 18, 2.31},
    {"SYN", "Synapse", 18, 0.48},
    {"ZRX", "0x Protocol", 18, 0.33},
}};

const QStringList assetRoles{
    QStringLiteral("key"), QStringLiteral("name"), QStringLiteral("symbol"),
    QStringLiteral("logoUri"), QStringLiteral("balance"), QStringLiteral("balanceText"),
    QStringLiteral("balanceLoading"), QStringLiteral("error"), QStringLiteral("marketPrice"),
    QStringLiteral("marketChangePct24hour"), QStringLiteral("marketDetailsAvailable"),
    QStringLiteral("marketDetailsLoading"), QStringLiteral("communityId"),
    QStringLiteral("communityName"), QStringLiteral("communityImage"),
    QStringLiteral("canBeHidden"), QStringLiteral("position"), QStringLiteral("visible"),
    QStringLiteral("isCommunity"), QStringLiteral("marketBalance"),
    QStringLiteral("change1DayFiat"), QStringLiteral("chainIds"), QStringLiteral("soulbound"),
    QStringLiteral("ownerToken")};

const QStringList tokenGroupRoles{
    QStringLiteral("key"), QStringLiteral("name"), QStringLiteral("symbol"),
    QStringLiteral("decimals"), QStringLiteral("logoUri"), QStringLiteral("tokens"),
    QStringLiteral("communityId"), QStringLiteral("soulbound"), QStringLiteral("ownerToken"),
    QStringLiteral("type"), QStringLiteral("websiteUrl"), QStringLiteral("description"),
    QStringLiteral("marketDetails"), QStringLiteral("detailsLoading"),
    QStringLiteral("marketDetailsLoading"), QStringLiteral("visible"), QStringLiteral("position")};

const QStringList tokenRoles{
    QStringLiteral("key"), QStringLiteral("groupKey"), QStringLiteral("crossChainId"),
    QStringLiteral("address"), QStringLiteral("name"), QStringLiteral("symbol"),
    QStringLiteral("decimals"), QStringLiteral("chainId"), QStringLiteral("image"),
    QStringLiteral("customToken"), QStringLiteral("communityId")};

const QStringList groupedAssetRoles{QStringLiteral("key"), QStringLiteral("balances")};

const QStringList balanceRoles{
    QStringLiteral("account"), QStringLiteral("groupKey"), QStringLiteral("tokenKey"),
    QStringLiteral("chainId"), QStringLiteral("tokenAddress"), QStringLiteral("balance"),
    QStringLiteral("loading")};

const QStringList collectibleRoles{
    QStringLiteral("uid"), QStringLiteral("chainId"), QStringLiteral("contractAddress"),
    QStringLiteral("tokenId"), QStringLiteral("name"), QStringLiteral("mediaUrl"),
    QStringLiteral("mediaType"), QStringLiteral("imageUrl"), QStringLiteral("thumbnailUrl"),
    QStringLiteral("backgroundColor"), QStringLiteral("collectionUid"),
    QStringLiteral("collectionName"), QStringLiteral("collectionSlug"),
    QStringLiteral("collectionImageUrl"), QStringLiteral("isLoading"), QStringLiteral("ownership"),
    QStringLiteral("communityId"), QStringLiteral("communityPrivilegesLevel"),
    QStringLiteral("tokenType"), QStringLiteral("soulbound")};

const QStringList ownershipRoles{QStringLiteral("accountAddress"), QStringLiteral("balance"),
                                 QStringLiteral("txTimestamp")};

QVariantMap currencyAmount(double amount, int displayDecimals)
{
    return QVariantMap{{QStringLiteral("amount"), amount},
                       {QStringLiteral("symbol"), QStringLiteral("USD")},
                       {QStringLiteral("displayDecimals"), displayDecimals},
                       {QStringLiteral("stripTrailingZeroes"), false}};
}

} // namespace

WalletMockProfile::WalletMockProfile(QObject* parent)
    : QObject(parent)
    , m_assetsModel(new GeneratedListModel(this))
    , m_tokenGroupsModel(new GeneratedListModel(this))
    , m_groupedAccountAssetsModel(new GeneratedListModel(this))
    , m_collectiblesModel(new GeneratedListModel(this))
{
    m_assetsModel->setRoles(assetRoles);
    m_tokenGroupsModel->setRoles(tokenGroupRoles);
    m_groupedAccountAssetsModel->setRoles(groupedAssetRoles);
    m_collectiblesModel->setRoles(collectibleRoles);
    m_collectiblesModel->setPageSize(m_collectiblesPageSize);
}

#define WALLET_MOCK_SETTER(Type, setter, member, signalName)                                       \
    void WalletMockProfile::setter(Type value)                                                     \
    {                                                                                              \
        if (member == value)                                                                       \
            return;                                                                                \
        member = value;                                                                            \
        emit signalName();                                                                         \
    }

WALLET_MOCK_SETTER(int, setSeed, m_seed, seedChanged)
WALLET_MOCK_SETTER(int, setAccountCount, m_accountCount, accountCountChanged)
WALLET_MOCK_SETTER(int, setAssetGroupCount, m_assetGroupCount, assetGroupCountChanged)
WALLET_MOCK_SETTER(int, setCollectibleCount, m_collectibleCount, collectibleCountChanged)
WALLET_MOCK_SETTER(int, setCommunityCount, m_communityCount, communityCountChanged)
WALLET_MOCK_SETTER(int, setSavedAddressCount, m_savedAddressCount, savedAddressCountChanged)
WALLET_MOCK_SETTER(int, setFollowingAddressCount, m_followingAddressCount,
                   followingAddressCountChanged)
WALLET_MOCK_SETTER(bool, setWatchOnlyOnly, m_watchOnlyOnly, watchOnlyOnlyChanged)

#undef WALLET_MOCK_SETTER

void WalletMockProfile::setCollectiblesPageSize(int value)
{
    if (m_collectiblesPageSize == value)
        return;
    m_collectiblesPageSize = value;
    m_collectiblesModel->setPageSize(value);
    emit collectiblesPageSizeChanged();
}

void WalletMockProfile::setChainIds(const QVariantList& chainIds)
{
    if (m_chainIds == chainIds)
        return;
    m_chainIds = chainIds;
    emit chainIdsChanged();
}

QList<int> WalletMockProfile::effectiveChainIds() const
{
    QList<int> chains;
    for (const auto& value : m_chainIds) {
        const int chainId = value.toInt();
        if (chainId > 0)
            chains.append(chainId);
    }
    if (chains.isEmpty())
        chains = {1, 10, 42161, 8453};
    return chains;
}

void WalletMockProfile::clear()
{
    m_assetsModel->clearRows();
    m_tokenGroupsModel->clearRows();
    m_groupedAccountAssetsModel->clearRows();
    m_collectiblesModel->clearRows();
    m_accounts.clear();
    m_communities.clear();
    m_savedAddresses.clear();
    m_following.clear();
    emit generated();
}

void WalletMockProfile::generate()
{
    generateAccounts();
    generateCommunities();
    generateTokens();
    generateCollectibles();
    generateAddressBooks();
    emit generated();
}

void WalletMockProfile::generateAccounts()
{
    m_accounts.clear();
    // Wallet types cycle so the profile always covers the generated / seed /
    // key / watch mix the left panel groups by keypair.
    static const QStringList walletTypes{QStringLiteral("generated"), QStringLiteral("seed"),
                                         QStringLiteral("key"), QStringLiteral("watch")};
    static const QStringList accountEmojis{QStringLiteral("sunglasses"), QStringLiteral("rocket"),
                                           QStringLiteral("bank"), QStringLiteral("dollar"),
                                           QStringLiteral("gem"), QStringLiteral("chart")};

    for (int i = 0; i < m_accountCount; ++i) {
        const quint64 h = hash2(m_seed, i, 0xACC0ULL);
        const QString walletType = m_watchOnlyOnly ? QStringLiteral("watch")
                                                   : walletTypes.at(i % walletTypes.size());
        const bool isWatch = walletType == QStringLiteral("watch");
        const QString address = addressFor(h);
        // Three keypairs plus the watch bucket, matching the profile table.
        const QString keyUid = isWatch ? QString()
                                       : (i == 0 ? QStringLiteral("0xprofilekeyuid")
                                                 : QStringLiteral("0xkeypair-%1").arg(i % 3));

        m_accounts.append(QVariantMap{
            {QStringLiteral("name"), QStringLiteral("Account %1").arg(i)},
            {QStringLiteral("address"), address},
            {QStringLiteral("mixedcaseAddress"), address},
            {QStringLiteral("path"), QStringLiteral("m/44'/60'/0'/0/%1").arg(i)},
            {QStringLiteral("colorId"), QString::number(i % 10)},
            {QStringLiteral("walletType"), walletType},
            {QStringLiteral("currencyBalance"),
             QVariant::fromValue(currencyAmount(1000.0 + unitOf(h) * 900000.0, 2))},
            {QStringLiteral("emoji"), accountEmojis.at(i % accountEmojis.size())},
            {QStringLiteral("keyUid"), keyUid},
            {QStringLiteral("createdAt"), 1700000000 + i},
            {QStringLiteral("position"), i},
            {QStringLiteral("migratedToColdWallet"), false},
            {QStringLiteral("assetsLoading"), false},
            {QStringLiteral("isWallet"), i == 0},
            {QStringLiteral("hideFromTotalBalance"), false},
            {QStringLiteral("canSend"), !isWatch},
        });
    }
}

void WalletMockProfile::generateCommunities()
{
    m_communities.clear();
    for (int i = 0; i < m_communityCount; ++i) {
        const QString id = QStringLiteral("community-%1").arg(i);
        m_communities.append(QVariantMap{
            {QStringLiteral("id"), id},
            {QStringLiteral("name"), QStringLiteral("Mock Community %1").arg(i)},
            {QStringLiteral("image"), QStringLiteral("image://walletmock/community-%1").arg(i)},
            {QStringLiteral("description"), QStringLiteral("Generated community %1").arg(i)},
            {QStringLiteral("color"), QStringLiteral("#4360DF")},
        });
    }
}

void WalletMockProfile::generateTokens()
{
    const QList<int> chains = effectiveChainIds();
    const int accountCount = qMax(1, m_accounts.size());

    std::vector<QVariantList> assetRows;
    std::vector<QVariantList> groupRows;
    std::vector<QVariantList> groupedRows;
    assetRows.reserve(size_t(m_assetGroupCount));
    groupRows.reserve(size_t(m_assetGroupCount));
    groupedRows.reserve(size_t(m_assetGroupCount));

    for (int i = 0; i < m_assetGroupCount; ++i) {
        const quint64 h = hash2(m_seed, i, 0x70CEULL);
        const bool curated = i < int(curatedTokens.size());

        const QString symbol = curated ? QString::fromLatin1(curatedTokens[size_t(i)].symbol)
                                       : QStringLiteral("MT%1").arg(i, 5, 36, QLatin1Char('0')).toUpper();
        const QString name = curated ? QString::fromLatin1(curatedTokens[size_t(i)].name)
                                     : QStringLiteral("Mock Token %1").arg(i);
        const int decimals = curated ? curatedTokens[size_t(i)].decimals : 18;
        // The tail is dust and airdrops: sub-cent prices and tiny balances.
        const double price = curated ? curatedTokens[size_t(i)].price
                                     : unitOf(mix(h)) * 0.05;
        const QString groupKey = QStringLiteral("group-%1-%2").arg(symbol).arg(i);
        const QString logoUri = QStringLiteral("image://walletmock/token-%1").arg(groupKey);

        // Every 37th group is a community asset; the first of each community is
        // its owner token, the second its token-master token.
        const bool isCommunityAsset = m_communityCount > 0 && (i % 37 == 5);
        const int communityIndex = isCommunityAsset ? (i / 37) % m_communityCount : -1;
        const QString communityId = isCommunityAsset
                ? m_communities.at(communityIndex).toMap().value(QStringLiteral("id")).toString()
                : QString();
        const QString communityName = isCommunityAsset
                ? m_communities.at(communityIndex).toMap().value(QStringLiteral("name")).toString()
                : QString();
        const QString communityImage = isCommunityAsset
                ? m_communities.at(communityIndex).toMap().value(QStringLiteral("image")).toString()
                : QString();
        const bool ownerToken = isCommunityAsset && (i / 37) % 3 == 0;
        const bool soulbound = isCommunityAsset && (i / 37) % 3 == 1;

        const int chainSpan = 1 + int(h % quint64(qMin(3, chains.size())));
        const int chainOffset = int((h >> 8) % quint64(chains.size()));

        auto* tokens = new GeneratedListModel(m_tokenGroupsModel);
        tokens->setRoles(tokenRoles);
        std::vector<QVariantList> tokenRows;
        tokenRows.reserve(size_t(chainSpan));

        auto* balances = new GeneratedListModel(m_groupedAccountAssetsModel);
        balances->setRoles(balanceRoles);
        std::vector<QVariantList> balanceRows;

        QStringList chainIdStrings;
        double totalBalance = 0.0;
        const int holders = 1 + int((h >> 16) % quint64(qMin(3, accountCount)));

        for (int c = 0; c < chainSpan; ++c) {
            const int chainId = chains.at((chainOffset + c) % chains.size());
            const QString tokenAddress = addressFor(hash2(m_seed, i * 31 + c, 0x7ADDULL));
            const QString tokenKey = QStringLiteral("%1-%2").arg(chainId).arg(tokenAddress);
            chainIdStrings.append(QString::number(chainId));

            tokenRows.push_back({tokenKey, groupKey, groupKey, tokenAddress, name, symbol, decimals,
                                 chainId, logoUri, false, communityId});

            for (int a = 0; a < holders; ++a) {
                const int accountIndex = int((h >> (20 + a)) % quint64(accountCount));
                const QString account = m_accounts.isEmpty()
                        ? QString()
                        : m_accounts.at(accountIndex).toMap()
                                  .value(QStringLiteral("address")).toString();
                const double units = curated ? 0.5 + unitOf(hash2(m_seed, i * 97 + c * 7 + a, 0xBA1EULL)) * 400.0
                                             : unitOf(hash2(m_seed, i * 97 + c * 7 + a, 0xBA1EULL)) * 3.0;
                totalBalance += units;
                // Balances travel as raw big-integer strings, like the backend.
                const auto raw = QString::number(qint64(units * 1e6)) + QStringLiteral("000000000000");
                balanceRows.push_back({account, groupKey, tokenKey, chainId, tokenAddress, raw, false});
            }
        }

        tokens->resetRows(std::move(tokenRows));
        balances->resetRows(std::move(balanceRows));

        const double changePct = (unitOf(mix(h + 3)) - 0.5) * 24.0;
        const double marketBalance = totalBalance * price;
        const double denom = changePct / 100.0 + 1.0;
        const double change1DayFiat = denom == 0.0 ? 0.0 : marketBalance * (1.0 - 1.0 / denom);

        QVariantMap marketDetails{
            {QStringLiteral("changePctHour"), changePct / 24.0},
            {QStringLiteral("changePctDay"), changePct},
            {QStringLiteral("changePct24hour"), changePct},
            {QStringLiteral("change24hour"), price * changePct / 100.0},
            {QStringLiteral("marketCap"), currencyAmount(price * 1e8, 0)},
            {QStringLiteral("highDay"), currencyAmount(price * 1.05, 4)},
            {QStringLiteral("lowDay"), currencyAmount(price * 0.95, 4)},
            {QStringLiteral("currencyPrice"), currencyAmount(price, price < 1.0 ? 6 : 2)},
        };

        groupRows.push_back({groupKey, name, symbol, decimals, logoUri,
                             QVariant::fromValue(static_cast<QObject*>(tokens)), communityId,
                             soulbound, ownerToken, isCommunityAsset ? QStringLiteral("community")
                                                                     : QStringLiteral("erc20"),
                             QStringLiteral("https://status.app"),
                             QStringLiteral("Generated token used by the storybook wallet harness."),
                             marketDetails, false, false, true, i});

        groupedRows.push_back({groupKey, QVariant::fromValue(static_cast<QObject*>(balances))});

        assetRows.push_back({groupKey, name, symbol, logoUri, totalBalance, QString(), false,
                             QString(), price, changePct, true, false, communityId, communityName,
                             communityImage, !curated, i, true,
                             isCommunityAsset ? QStringLiteral("community") : QString(),
                             marketBalance, change1DayFiat, chainIdStrings.join(QLatin1Char(',')),
                             soulbound, ownerToken});
    }

    m_tokenGroupsModel->resetRows(std::move(groupRows));
    m_groupedAccountAssetsModel->resetRows(std::move(groupedRows));
    m_assetsModel->resetRows(std::move(assetRows));
}

void WalletMockProfile::generateCollectibles()
{
    const QList<int> chains = effectiveChainIds();
    const int accountCount = qMax(1, m_accounts.size());
    // Collections are shared by ~12 collectibles so the collection grouping in
    // the view has something to group.
    const int collectionCount = qMax(1, m_collectibleCount / 12);

    std::vector<QVariantList> rows;
    rows.reserve(size_t(m_collectibleCount));

    for (int i = 0; i < m_collectibleCount; ++i) {
        const quint64 h = hash2(m_seed, i, 0xC011ULL);
        const int chainId = chains.at(int(h % quint64(chains.size())));
        const int collectionIndex = i % collectionCount;
        const QString contractAddress = addressFor(hash2(m_seed, collectionIndex, 0xC0DEULL));
        const QString tokenId = QString::number(1000 + i);
        const QString uid = QStringLiteral("%1+%2+%3").arg(chainId).arg(contractAddress, tokenId);
        const QString art = QStringLiteral("image://walletmock/nft-%1").arg(uid);

        const bool isCommunityCollectible = m_communityCount > 0 && (i % 9 == 3);
        const int communityIndex = isCommunityCollectible ? (i / 9) % m_communityCount : -1;
        const QString communityId = isCommunityCollectible
                ? m_communities.at(communityIndex).toMap().value(QStringLiteral("id")).toString()
                : QString();
        // 0 none, 1 owner, 2 token master, 3 member — cycled so the badges and
        // the soulbound flag all appear in the generated set.
        const int privilegesLevel = isCommunityCollectible ? 1 + (i / 9) % 3 : 0;

        auto* ownership = new GeneratedListModel(m_collectiblesModel);
        ownership->setRoles(ownershipRoles);
        std::vector<QVariantList> ownershipRows;
        const int owners = 1 + int((h >> 12) % 2ULL);
        for (int o = 0; o < owners; ++o) {
            const int accountIndex = int((h >> (24 + o)) % quint64(accountCount));
            const QString account = m_accounts.isEmpty()
                    ? QString()
                    : m_accounts.at(accountIndex).toMap()
                              .value(QStringLiteral("address")).toString();
            ownershipRows.push_back({account, QStringLiteral("1"), 1700000000 + i});
        }
        ownership->resetRows(std::move(ownershipRows));

        rows.push_back({uid, chainId, contractAddress, tokenId,
                        QStringLiteral("Mock Collectible #%1").arg(i), art,
                        QStringLiteral("image/png"), art, art,
                        QStringLiteral("#%1").arg(h % 0xffffffULL, 6, 16, QLatin1Char('0')),
                        QStringLiteral("%1+%2").arg(chainId).arg(contractAddress),
                        QStringLiteral("Mock Collection %1").arg(collectionIndex),
                        QStringLiteral("mock-collection-%1").arg(collectionIndex),
                        QStringLiteral("image://walletmock/collection-%1").arg(collectionIndex),
                        false, QVariant::fromValue(static_cast<QObject*>(ownership)), communityId,
                        privilegesLevel, isCommunityCollectible ? 2 : 1,
                        isCommunityCollectible && privilegesLevel == 3});
    }

    m_collectiblesModel->resetRows(std::move(rows));
}

void WalletMockProfile::generateAddressBooks()
{
    m_savedAddresses.clear();
    for (int i = 0; i < m_savedAddressCount; ++i) {
        const quint64 h = hash2(m_seed, i, 0x5A7EULL);
        const QString address = addressFor(h);
        m_savedAddresses.append(QVariantMap{
            {QStringLiteral("name"), QStringLiteral("Saved address %1").arg(i)},
            {QStringLiteral("address"), address},
            {QStringLiteral("mixedcaseAddress"), address},
            {QStringLiteral("ens"), i % 4 == 0 ? QStringLiteral("saved%1.eth").arg(i) : QString()},
            {QStringLiteral("colorId"), QString::number(i % 10)},
            // Split across both modes so RootStore.savedAddresses' isTest filter
            // actually filters something in either testnet state.
            {QStringLiteral("isTest"), i % 3 == 0},
        });
    }

    m_following.clear();
    for (int i = 0; i < m_followingAddressCount; ++i) {
        const quint64 h = hash2(m_seed, i, 0xF0110ULL);
        m_following.append(QVariantMap{
            {QStringLiteral("address"), addressFor(h)},
            {QStringLiteral("ensName"), i % 3 == 0 ? QStringLiteral("follow%1.eth").arg(i) : QString()},
            {QStringLiteral("tags"), QStringLiteral("whale,defi")},
            {QStringLiteral("name"), QStringLiteral("Followed %1").arg(i)},
            {QStringLiteral("avatar"), QStringLiteral("image://walletmock/following-%1").arg(i)},
        });
    }
}

QVariantList WalletMockProfile::followingAddresses(const QString& search, int limit,
                                                   int offset) const
{
    QVariantList result;
    const QString needle = search.toLower();
    int matched = 0;
    for (const auto& entry : m_following) {
        const auto map = entry.toMap();
        if (!needle.isEmpty()
            && !map.value(QStringLiteral("name")).toString().toLower().contains(needle)
            && !map.value(QStringLiteral("address")).toString().toLower().contains(needle))
            continue;
        if (matched++ < offset)
            continue;
        result.append(entry);
        if (limit > 0 && result.size() >= limit)
            break;
    }
    return result;
}

int WalletMockProfile::followingAddressesTotal(const QString& search) const
{
    if (search.isEmpty())
        return int(m_following.size());
    int total = 0;
    const QString needle = search.toLower();
    for (const auto& entry : m_following) {
        const auto map = entry.toMap();
        if (map.value(QStringLiteral("name")).toString().toLower().contains(needle)
            || map.value(QStringLiteral("address")).toString().toLower().contains(needle))
            ++total;
    }
    return total;
}

QString WalletMockProfile::accountAddress(int index) const
{
    if (index < 0 || index >= m_accounts.size())
        return {};
    return m_accounts.at(index).toMap().value(QStringLiteral("address")).toString();
}

QVariantMap WalletMockProfile::accountByAddress(const QString& address) const
{
    for (const auto& entry : m_accounts) {
        const auto map = entry.toMap();
        if (map.value(QStringLiteral("address")).toString().compare(address, Qt::CaseInsensitive) == 0)
            return map;
    }
    return {};
}

void WalletMockProfile::sortAssets(const QString& roleName, int order)
{
    m_assetsModel->sortBy(roleName, order);
}

void WalletMockProfile::setAssetsLoading(bool loading)
{
    m_assetsModel->setValueForAll(QStringLiteral("balanceLoading"), loading);
}

void WalletMockProfile::refreshBalances()
{
    // Perturb every balance by a seed-derived delta and re-emit, reproducing the
    // per-row dataChanged storm a token reload produces.
    const int rows = m_assetsModel->totalCount();
    for (int i = 0; i < rows; ++i) {
        const double balance = m_assetsModel->valueAt(i, QStringLiteral("balance")).toDouble();
        const double price = m_assetsModel->valueAt(i, QStringLiteral("marketPrice")).toDouble();
        const double factor = 0.95 + unitOf(hash2(m_seed, i, 0xEFE5ULL)) * 0.1;
        m_assetsModel->setValue(i, QStringLiteral("balance"), balance * factor);
        m_assetsModel->setValue(i, QStringLiteral("marketBalance"), balance * factor * price);
    }
}

void WalletMockProfile::loadMoreCollectibles()
{
    m_collectiblesModel->loadMore();
}

QString WalletMockProfile::uidForCollectible(const QString& tokenId, const QString& contractAddress,
                                             int chainId) const
{
    return QStringLiteral("%1+%2+%3").arg(chainId).arg(contractAddress, tokenId);
}
