#include <QAccessible>
#include <QTest>

#include <QtQuick/private/qquickaccessibleattached_p.h>

#include <StatusQ/chatsinglelinetextitem.h>
#include <StatusQ/chattextappearance.h>
#include <StatusQ/chattextitem.h>
#include <StatusQ/markdownutils.h>

// Chat text items expose their plain text as accessible name and StaticText
// role, creating nothing while no assistive technology is active.
class TestChatTextAccessibility : public QObject
{
    Q_OBJECT

    MarkdownUtils utils;

    static QQuickAccessibleAttached* attached(QQuickItem* item)
    {
        return QQuickAccessibleAttached::attachedProperties(item);
    }

    QList<ChatTextSegment> segments(const QString& text) const
    {
        return utils.toChatTextSegments(text, {});
    }

private slots:
    void init() { QAccessible::setActive(false); }
    void cleanup() { QAccessible::setActive(false); }

    void inactiveCreatesNothing()
    {
        ChatTextItem multi;
        ChatSingleLineTextItem single;
        multi.setSegments(segments(QStringLiteral("a **b**")));
        single.setSegments(segments(QStringLiteral("a **b**")));
        QCOMPARE(multi.text(), QStringLiteral("a b"));
        QCOMPARE(single.text(), QStringLiteral("a b"));
        QVERIFY(!attached(&multi));
        QVERIFY(!attached(&single));
    }

    void activationUpdatesExistingItems()
    {
        ChatTextItem multi;
        ChatSingleLineTextItem single;
        multi.setSegments(segments(QStringLiteral("> quoted\nafter")));
        single.setSegments(segments(QStringLiteral("> quoted\nafter")));
        single.setEdited(true);

        QAccessible::setActive(true);
        QVERIFY(attached(&multi));
        QCOMPARE(attached(&multi)->role(), QAccessible::StaticText);
        QCOMPARE(attached(&multi)->name(), QStringLiteral("quoted\nafter"));
        QVERIFY(attached(&single));
        QCOMPARE(attached(&single)->role(), QAccessible::StaticText);
        QCOMPARE(attached(&single)->name(), single.text());
        QVERIFY(single.text().endsWith(QStringLiteral("(edited)")));
    }

    void nameFollowsContentWhileActive()
    {
        QAccessible::setActive(true);
        ChatTextItem item;
        item.setSegments(segments(QStringLiteral("first")));
        QVERIFY(attached(&item));
        QCOMPARE(attached(&item)->name(), QStringLiteral("first"));
        item.setSegments(segments(QStringLiteral("second")));
        QCOMPARE(attached(&item)->name(), QStringLiteral("second"));
        item.setEdited(true);
        QCOMPARE(attached(&item)->name(), item.text());
    }

    void nameFollowsEditedMarkerText()
    {
        QAccessible::setActive(true);
        ChatTextAppearance appearance;
        ChatTextItem multi;
        ChatSingleLineTextItem single;
        for (QQuickItem* item : {static_cast<QQuickItem*>(&multi), static_cast<QQuickItem*>(&single)}) {
            item->setProperty("appearance", QVariant::fromValue(&appearance));
            item->setProperty("segments", QVariant::fromValue(segments(QStringLiteral("body"))));
            item->setProperty("edited", true);
        }
        appearance.setEditedMarkerText(QStringLiteral("(upraveno)"));
        QCOMPARE(attached(&multi)->name(), QStringLiteral("body (upraveno)"));
        QCOMPARE(attached(&single)->name(), QStringLiteral("body (upraveno)"));
    }

    void explicitNameWins()
    {
        ChatTextItem item;
        auto* accessible = qobject_cast<QQuickAccessibleAttached*>(
                qmlAttachedPropertiesObject<QQuickAccessibleAttached>(&item, true));
        accessible->setName(QStringLiteral("custom"));
        item.setSegments(segments(QStringLiteral("body")));
        QAccessible::setActive(true);
        item.setEdited(true);
        QCOMPARE(accessible->name(), QStringLiteral("custom"));
        QCOMPARE(accessible->role(), QAccessible::StaticText);
    }

    void destroyedItemsAreUntracked()
    {
        {
            ChatTextItem gone;
            gone.setSegments(segments(QStringLiteral("gone")));
        }
        ChatSingleLineTextItem kept;
        kept.setSegments(segments(QStringLiteral("kept")));
        QAccessible::setActive(true); // must not touch the destroyed item
        QCOMPARE(attached(&kept)->name(), QStringLiteral("kept"));
    }
};

QTEST_MAIN(TestChatTextAccessibility)
#include "tst_chattextaccessibility.moc"
