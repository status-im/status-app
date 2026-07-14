#include <QAbstractItemModelTester>
#include <QAbstractListModel>
#include <QSignalSpy>
#include <QTest>

#include "managetokenscontroller.h"
#include "managetokensmodel.h"
#include "tokendata.h"

// Minimal source model mirroring the roles ManageTokensController::addItem reads.
// Rows are role-name -> value maps; role integers are assigned once from a fixed
// ordered role list so roleNames() is stable and non-empty from construction
// (the controller has a separate code path for models whose roles appear late).
class SourceModel : public QAbstractListModel
{
    Q_OBJECT

public:
    explicit SourceModel(QObject* parent = nullptr) : QAbstractListModel(parent)
    {
        const QList<QByteArray> names{"key",
                                      "tokenKey",
                                      "crossChainId",
                                      "symbol",
                                      "name",
                                      "communityId",
                                      "communityName",
                                      "communityImage",
                                      "collectionUid",
                                      "collectionName",
                                      "enabledNetworkBalance",
                                      "enabledNetworkCurrencyBalance",
                                      "imageUrl",
                                      "image",
                                      "mediaUrl",
                                      "backgroundColor",
                                      "balances",
                                      "decimals",
                                      "marketDetails"};
        int role = Qt::UserRole + 1;
        for (const auto& n : names) {
            m_roleForName.insert(n, role);
            m_nameForRole.insert(role, n);
            role++;
        }
    }

    int rowCount(const QModelIndex& parent = {}) const override
    {
        return parent.isValid() ? 0 : m_rows.size();
    }

    QHash<int, QByteArray> roleNames() const override { return m_nameForRole; }

    QVariant data(const QModelIndex& index, int role) const override
    {
        if (!checkIndex(index, CheckIndexOption::IndexIsValid | CheckIndexOption::ParentIsInvalid))
            return {};
        return m_rows.at(index.row()).value(m_nameForRole.value(role));
    }

    // --- test-side mutation API ---

    void appendRow(const QHash<QByteArray, QVariant>& row)
    {
        const int r = m_rows.size();
        beginInsertRows({}, r, r);
        m_rows.append(row);
        endInsertRows();
    }

    void removeRow(int row)
    {
        beginRemoveRows({}, row, row);
        m_rows.removeAt(row);
        endRemoveRows();
    }

    void resetWith(const QList<QHash<QByteArray, QVariant>>& rows)
    {
        beginResetModel();
        m_rows = rows;
        endResetModel();
    }

    // Change a single cell and notify with exactly the given role (data-only churn).
    void updateCell(int row, const QByteArray& roleName, const QVariant& value)
    {
        m_rows[row].insert(roleName, value);
        const auto idx = index(row, 0);
        emit dataChanged(idx, idx, {m_roleForName.value(roleName)});
    }

    // Change several cells on one row, notify with the union of their roles.
    void updateCells(int row, const QHash<QByteArray, QVariant>& changes)
    {
        QList<int> roles;
        for (auto it = changes.cbegin(); it != changes.cend(); ++it) {
            m_rows[row].insert(it.key(), it.value());
            roles.append(m_roleForName.value(it.key()));
        }
        const auto idx = index(row, 0);
        emit dataChanged(idx, idx, roles);
    }

    int roleFor(const QByteArray& name) const { return m_roleForName.value(name, -1); }

private:
    QList<QHash<QByteArray, QVariant>> m_rows;
    QHash<QByteArray, int> m_roleForName;
    QHash<int, QByteArray> m_nameForRole;
};

namespace
{
using Row = QHash<QByteArray, QVariant>;

Row regularToken(const QString& key, const QString& balance = "0")
{
    return {{"key", key}, {"symbol", key.toUpper()}, {"name", key}, {"enabledNetworkBalance", balance}};
}

Row communityToken(const QString& key, const QString& communityId, const QString& balance = "0")
{
    return {{"key", key},
            {"symbol", key.toUpper()},
            {"name", key},
            {"communityId", communityId},
            {"communityName", communityId},
            {"enabledNetworkBalance", balance}};
}

Row collectionToken(const QString& key, const QString& collectionUid, const QString& balance = "0")
{
    return {{"key", key},
            {"symbol", key.toUpper()},
            {"name", key},
            {"collectionUid", collectionUid},
            {"collectionName", collectionUid},
            {"enabledNetworkBalance", balance}};
}

QStringList keysOf(QAbstractItemModel* model)
{
    QStringList result;
    const auto keyRole = model->roleNames().key("key", -1);
    for (int i = 0; i < model->rowCount(); i++)
        result << model->data(model->index(i, 0), keyRole).toString();
    return result;
}

QVariant dataForKey(QAbstractItemModel* model, const QString& key, const QByteArray& roleName)
{
    const auto keyRole = model->roleNames().key("key", -1);
    const auto role = model->roleNames().key(roleName, -1);
    for (int i = 0; i < model->rowCount(); i++) {
        if (model->data(model->index(i, 0), keyRole).toString() == key)
            return model->data(model->index(i, 0), role);
    }
    return {};
}
} // namespace

class TestManageTokensController : public QObject
{
    Q_OBJECT

    // Boilerplate: build a controller wired to `source` and run the initial parse.
    // Returns the controller; caller owns nothing extra (source outlives it).
    static void populate(ManageTokensController& controller, SourceModel& source)
    {
        controller.setProperty("sourceModel", QVariant::fromValue<QAbstractItemModel*>(&source));
        QMetaObject::invokeMethod(&controller, "loadingFinished", Q_ARG(QString, QString()));
    }

    static QAbstractItemModel* model(ManageTokensController& c, const char* name)
    {
        return c.property(name).value<QAbstractItemModel*>();
    }

private slots:

    // --- Characterization: observable end-state that must survive the refactor ---

    void initialParsePartitionsByCommunity()
    {
        SourceModel source;
        source.resetWith({regularToken("eth"), communityToken("cat", "community_1"), regularToken("dai")});

        ManageTokensController controller;
        populate(controller, source);

        QCOMPARE(keysOf(model(controller, "regularTokensModel")), (QStringList{"eth", "dai"}));
        QCOMPARE(keysOf(model(controller, "communityTokensModel")), (QStringList{"cat"}));
        QCOMPARE(model(controller, "hiddenTokensModel")->rowCount(), 0);
    }

    void communityGroupsModelReflectsChildCount()
    {
        SourceModel source;
        source.resetWith({communityToken("cat", "community_1"),
                          communityToken("dog", "community_1"),
                          communityToken("fox", "community_2")});

        ManageTokensController controller;
        populate(controller, source);

        auto groups = model(controller, "communityTokenGroupsModel");
        QCOMPARE(groups->rowCount(), 2);
        // group's childCount is exposed through the "enabledNetworkBalance" role
        QCOMPARE(dataForKey(groups, "cat", "enabledNetworkBalance").toInt(), 2);
        QCOMPARE(dataForKey(groups, "fox", "enabledNetworkBalance").toInt(), 1);
    }

    void collectionGroupsModelReflectsChildCount()
    {
        SourceModel source;
        source.resetWith({collectionToken("punk1", "punks"),
                          collectionToken("punk2", "punks"),
                          collectionToken("ape1", "apes")});

        ManageTokensController controller;
        populate(controller, source);

        auto groups = model(controller, "collectionGroupsModel");
        QCOMPARE(groups->rowCount(), 2);
        QCOMPARE(dataForKey(groups, "punk1", "enabledNetworkBalance").toInt(), 2);
    }

    void sourceResetReparses()
    {
        SourceModel source;
        source.resetWith({regularToken("eth"), regularToken("dai")});
        ManageTokensController controller;
        populate(controller, source);
        QCOMPARE(model(controller, "regularTokensModel")->rowCount(), 2);

        source.resetWith({regularToken("btc")});
        QCOMPARE(keysOf(model(controller, "regularTokensModel")), (QStringList{"btc"}));
    }

    void rowInsertedAppendsToRegularModel()
    {
        SourceModel source;
        source.resetWith({regularToken("eth")});
        ManageTokensController controller;
        populate(controller, source);

        source.appendRow(regularToken("dai"));
        QCOMPARE(keysOf(model(controller, "regularTokensModel")), (QStringList{"eth", "dai"}));
    }

    // QAbstractItemModelTester validates the model contract (index ranges, signal
    // ordering, role validity) on every output model across a data-change storm.
    void outputModelsSatisfyModelContractThroughStorm()
    {
        SourceModel source;
        source.resetWith({regularToken("eth", "1"),
                          communityToken("cat", "community_1", "2"),
                          collectionToken("punk1", "punks", "3")});

        ManageTokensController controller;

        const QList<const char*> names{"regularTokensModel",
                                       "communityTokensModel",
                                       "communityTokenGroupsModel",
                                       "hiddenTokensModel",
                                       "hiddenCommunityTokenGroupsModel",
                                       "collectionGroupsModel",
                                       "hiddenCollectionGroupsModel"};
        std::vector<std::unique_ptr<QAbstractItemModelTester>> testers;
        for (auto n : names)
            testers.push_back(std::make_unique<QAbstractItemModelTester>(model(controller, n)));

        populate(controller, source);

        for (int i = 0; i < 5; i++)
            source.updateCell(0, "enabledNetworkBalance", QString::number(100 + i));
        QTest::qWait(1); // flush any batched updates

        QCOMPARE(dataForKey(model(controller, "regularTokensModel"), "eth", "enabledNetworkBalance").toString(),
                 QStringLiteral("104"));
    }

    // --- New incremental behavior (fails before the fix, passes after) ---

    // A data-only dataChanged updates the affected token in place: the holding
    // model emits a narrow dataChanged and is NOT reset.
    void dataOnlyChangeUpdatesInPlaceWithoutReset()
    {
        SourceModel source;
        source.resetWith({regularToken("eth", "1"), regularToken("dai", "2")});
        ManageTokensController controller;
        populate(controller, source);

        auto regular = model(controller, "regularTokensModel");
        QSignalSpy resetSpy(regular, &QAbstractItemModel::modelReset);
        QSignalSpy changedSpy(regular, &QAbstractItemModel::dataChanged);

        source.updateCell(0, "enabledNetworkBalance", QStringLiteral("42"));
        QTest::qWait(1);

        QCOMPARE(resetSpy.count(), 0);
        QVERIFY(changedSpy.count() >= 1);
        QCOMPARE(dataForKey(regular, "eth", "enabledNetworkBalance").toString(), QStringLiteral("42"));
        // untouched row keeps its value and the row set is unchanged
        QCOMPARE(keysOf(regular), (QStringList{"eth", "dai"}));
        QCOMPARE(dataForKey(regular, "dai", "enabledNetworkBalance").toString(), QStringLiteral("2"));
    }

    // A storm of data-only dataChanged events coalesces into a single batched
    // update instead of one full re-parse per event.
    void stormOfDataChangesCoalesces()
    {
        SourceModel source;
        source.resetWith({regularToken("eth", "0")});
        ManageTokensController controller;
        populate(controller, source);

        auto regular = model(controller, "regularTokensModel");
        QSignalSpy resetSpy(regular, &QAbstractItemModel::modelReset);
        QSignalSpy changedSpy(regular, &QAbstractItemModel::dataChanged);

        constexpr int M = 20;
        for (int i = 0; i < M; i++)
            source.updateCell(0, "enabledNetworkBalance", QString::number(i));
        QTest::qWait(1); // let the batch flush

        QCOMPARE(resetSpy.count(), 0);
        QCOMPARE(changedSpy.count(), 1); // coalesced
        QCOMPARE(dataForKey(regular, "eth", "enabledNetworkBalance").toString(), QString::number(M - 1));
    }

    // A data-only change to a regular token must not churn the community/hidden
    // models at all.
    void dataOnlyChangeDoesNotTouchOtherModels()
    {
        SourceModel source;
        source.resetWith({regularToken("eth", "1"), communityToken("cat", "community_1", "2")});
        ManageTokensController controller;
        populate(controller, source);

        auto community = model(controller, "communityTokensModel");
        auto hidden = model(controller, "hiddenTokensModel");
        QSignalSpy communityReset(community, &QAbstractItemModel::modelReset);
        QSignalSpy communityChanged(community, &QAbstractItemModel::dataChanged);
        QSignalSpy hiddenReset(hidden, &QAbstractItemModel::modelReset);

        source.updateCell(0, "enabledNetworkBalance", QStringLiteral("99"));
        QTest::qWait(1);

        QCOMPARE(communityReset.count(), 0);
        QCOMPARE(communityChanged.count(), 0);
        QCOMPARE(hiddenReset.count(), 0);
        // community token unchanged
        QCOMPARE(dataForKey(community, "cat", "enabledNetworkBalance").toString(), QStringLiteral("2"));
    }

    // A structural change (token moves communities) still lands correctly via the
    // full-reparse fallback: end-state partitioning must be right.
    void structuralChangeRepartitionsToken()
    {
        SourceModel source;
        source.resetWith({regularToken("eth"), regularToken("cat")});
        ManageTokensController controller;
        populate(controller, source);
        QCOMPARE(keysOf(model(controller, "regularTokensModel")), (QStringList{"eth", "cat"}));
        QCOMPARE(model(controller, "communityTokensModel")->rowCount(), 0);

        // "cat" becomes a community token
        source.updateCells(1, {{"communityId", "community_1"}, {"communityName", "community_1"}});
        QTest::qWait(1);

        QCOMPARE(keysOf(model(controller, "regularTokensModel")), (QStringList{"eth"}));
        QCOMPARE(keysOf(model(controller, "communityTokensModel")), (QStringList{"cat"}));
    }
};

QTEST_GUILESS_MAIN(TestManageTokensController)
#include "tst_ManageTokensController.moc"
