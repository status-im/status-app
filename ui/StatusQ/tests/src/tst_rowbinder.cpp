#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QStandardItemModel>
#include <QTest>

#include <StatusQ/rowbinder.h>
#include <StatusQ/typesregistration.h>

namespace {

constexpr auto NameRole = Qt::UserRole + 1;
constexpr auto AgeRole = Qt::UserRole + 2;
constexpr auto ExtraRole = Qt::UserRole + 3;

class BindTarget : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName)
    Q_PROPERTY(int age READ age WRITE setAge)

public:
    QString name() const { return m_name; }
    void setName(const QString& name)
    {
        m_name = name;
        m_writes[QStringLiteral("name")]++;
    }

    int age() const { return m_age; }
    void setAge(int age)
    {
        m_age = age;
        m_writes[QStringLiteral("age")]++;
    }

    int writes(const QString& property) const { return m_writes.value(property); }
    int totalWrites() const
    {
        auto total = 0;
        for (auto count : m_writes)
            total += count;
        return total;
    }
    void resetWrites() { m_writes.clear(); }

private:
    QString m_name;
    int m_age = 0;
    QHash<QString, int> m_writes;
};

QStandardItem* makeRow(const QString& name, int age, const QString& extra)
{
    auto* item = new QStandardItem;
    item->setData(name, NameRole);
    item->setData(age, AgeRole);
    item->setData(extra, ExtraRole);
    return item;
}

std::unique_ptr<QStandardItemModel> makeModel()
{
    auto model = std::make_unique<QStandardItemModel>();
    model->setItemRoleNames({{NameRole, "name"}, {AgeRole, "age"}, {ExtraRole, "extra"}});
    model->appendRow(makeRow(QStringLiteral("Alice"), 30, QStringLiteral("a")));
    model->appendRow(makeRow(QStringLiteral("Bob"), 40, QStringLiteral("b")));
    model->appendRow(makeRow(QStringLiteral("Carol"), 50, QStringLiteral("c")));
    return model;
}

} // namespace

class tst_RowBinder : public QObject
{
    Q_OBJECT

private slots:
    void bindAssignsAllMatchingRoles()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);

        QCOMPARE(target.name(), QStringLiteral("Bob"));
        QCOMPARE(target.age(), 40);
        QVERIFY(binder.bound());

        // "extra" has no matching property: exactly one write per matching role
        QCOMPARE(target.writes(QStringLiteral("name")), 1);
        QCOMPARE(target.writes(QStringLiteral("age")), 1);
        QCOMPARE(target.totalWrites(), 2);
    }

    void dataChangedReappliesOnlyChangedRoles()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        model->item(1)->setData(41, AgeRole);

        QCOMPARE(target.age(), 41);
        QCOMPARE(target.writes(QStringLiteral("age")), 1);
        QCOMPARE(target.writes(QStringLiteral("name")), 0);
    }

    void dataChangedWithEmptyRolesReappliesAll()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        model->item(1)->setData(QStringLiteral("Bobby"), NameRole);
        model->item(1)->setData(41, AgeRole);
        emit model->dataChanged(model->index(1, 0), model->index(1, 0));

        QCOMPARE(target.name(), QStringLiteral("Bobby"));
        QCOMPARE(target.age(), 41);
    }

    void dataChangedOnOtherRowIsIgnored()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        model->item(0)->setData(31, AgeRole);
        model->item(2)->setData(51, AgeRole);

        QCOMPARE(target.totalWrites(), 0);
        QCOMPARE(target.age(), 40);
    }

    void retargetToAnotherRow()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 0);
        target.resetWrites();

        binder.setRowIndex(2);

        QCOMPARE(target.name(), QStringLiteral("Carol"));
        QCOMPARE(target.age(), 50);
        QCOMPARE(target.totalWrites(), 2);

        // follow now applies to the new row only
        target.resetWrites();
        model->item(0)->setData(31, AgeRole);
        QCOMPARE(target.totalWrites(), 0);
        model->item(2)->setData(51, AgeRole);
        QCOMPARE(target.age(), 51);
    }

    void retargetToAnotherModel()
    {
        auto modelA = makeModel();
        auto modelB = std::make_unique<QStandardItemModel>();
        modelB->setItemRoleNames({{NameRole, "name"}, {AgeRole, "age"}});
        modelB->appendRow(makeRow(QStringLiteral("Zoe"), 25, {}));

        BindTarget target;
        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(modelA.get(), 1);

        binder.bind(modelB.get(), 0);

        QCOMPARE(target.name(), QStringLiteral("Zoe"));
        QCOMPARE(target.age(), 25);

        // old model no longer followed
        target.resetWrites();
        modelA->item(1)->setData(99, AgeRole);
        QCOMPARE(target.totalWrites(), 0);

        modelB->item(0)->setData(26, AgeRole);
        QCOMPARE(target.age(), 26);
    }

    void detachStopsWrites()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);

        binder.detach();
        QVERIFY(!binder.bound());
        QCOMPARE(binder.rowIndex(), -1);

        target.resetWrites();
        model->item(1)->setData(99, AgeRole);
        model->removeRow(0);
        QCOMPARE(target.totalWrites(), 0);
        QCOMPARE(target.age(), 40);
    }

    void boundRowRemovalDetachesGracefully()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        QSignalSpy boundSpy(&binder, &RowBinder::boundChanged);
        model->removeRow(1);

        QVERIFY(!binder.bound());
        QCOMPARE(boundSpy.count(), 1);
        QCOMPARE(binder.rowIndex(), -1);
        QCOMPARE(target.totalWrites(), 0);

        // no stale writes from the rows that shifted into place
        model->item(1)->setData(51, AgeRole);
        QCOMPARE(target.totalWrites(), 0);
    }

    void rowIdentitySurvivesInsertsAndRemovesAtOtherIndices()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        QSignalSpy rowSpy(&binder, &RowBinder::rowIndexChanged);

        model->insertRow(0, makeRow(QStringLiteral("Pre"), 1, {}));
        QCOMPARE(binder.rowIndex(), 2);
        QCOMPARE(rowSpy.count(), 1);
        QVERIFY(binder.bound());

        // structural shifts alone re-apply nothing
        QCOMPARE(target.totalWrites(), 0);

        // still follows the same logical row
        model->item(2)->setData(41, AgeRole);
        QCOMPARE(target.age(), 41);

        model->removeRow(0);
        QCOMPARE(binder.rowIndex(), 1);
        model->item(1)->setData(42, AgeRole);
        QCOMPARE(target.age(), 42);
    }

    void modelResetDetaches()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);
        target.resetWrites();

        model->clear();

        QVERIFY(!binder.bound());
        QCOMPARE(target.totalWrites(), 0);
    }

    void modelDestructionDetaches()
    {
        auto model = makeModel();
        BindTarget target;

        RowBinder binder;
        binder.setTarget(&target);
        binder.bind(model.get(), 1);

        model.reset();

        QVERIFY(!binder.bound());
        QCOMPARE(binder.model(), nullptr);
    }

    void targetDestructionIsSafe()
    {
        auto model = makeModel();
        auto target = std::make_unique<BindTarget>();

        RowBinder binder;
        binder.setTarget(target.get());
        binder.bind(model.get(), 1);

        target.reset();

        QVERIFY(!binder.bound());
        model->item(1)->setData(41, AgeRole); // must not crash
    }

    void usableFromQml()
    {
        registerStatusQTypes();

        auto model = makeModel();

        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            import StatusQ

            Item {
                id: root
                property string name
                property int age

                property RowBinder binder: RowBinder {
                    target: root
                    rowIndex: 2
                }
            }
        )", QUrl(QStringLiteral("qrc:/tst_RowBinder.qml")));

        QScopedPointer<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));

        auto* binder = root->property("binder").value<RowBinder*>();
        QVERIFY(binder);

        binder->setModel(model.get());
        QCOMPARE(root->property("name").toString(), QStringLiteral("Carol"));
        QCOMPARE(root->property("age").toInt(), 50);

        model->item(2)->setData(51, AgeRole);
        QCOMPARE(root->property("age").toInt(), 51);
    }
};

QTEST_MAIN(tst_RowBinder)
#include "tst_rowbinder.moc"
