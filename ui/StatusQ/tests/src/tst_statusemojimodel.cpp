#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTest>

#include <algorithm>
#include <cstring>

#include <StatusQ/statusemojimodel.h>

#include "emojitable.h"

using namespace Qt::Literals::StringLiterals;

class tst_StatusEmojiModel : public QObject
{
    Q_OBJECT

    StatusEmojiModel *m_model = nullptr;
    QJsonArray m_catalogue;

    static QStringList unicodes(const QJsonArray &emojis)
    {
        QStringList result;
        for (const auto &emoji : emojis)
            result.append(emoji.toObject().value("unicode").toString());
        return result;
    }

    // Another spelling of the same id: no U+FE0F, no leading zeros.
    static QString canonicalForm(const QString &unicode)
    {
        QStringList parts;
        for (const auto &part : unicode.split(u'-')) {
            if (part == "fe0f"_L1)
                continue;
            auto digits = part;
            while (digits.size() > 1 && digits.startsWith(u'0'))
                digits.remove(0, 1);
            parts.append(digits);
        }
        return parts.join(u'-');
    }

    static const char *text(EmojiTable::StringRef ref)
    {
        return reinterpret_cast<const char *>(EmojiTable::strings + ref);
    }

    static bool isSortedPermutation(const std::uint16_t *index,
                                    EmojiTable::StringRef EmojiTable::Entry::*field)
    {
        QSet<std::uint16_t> seen;
        for (int i = 0; i < EmojiTable::entryCount; ++i) {
            if (index[i] >= EmojiTable::entryCount)
                return false;
            seen.insert(index[i]);
            if (i > 0 && std::strcmp(text(EmojiTable::entries[index[i - 1]].*field),
                                     text(EmojiTable::entries[index[i]].*field)) >= 0)
                return false;
        }
        return seen.size() == EmojiTable::entryCount;
    }

private slots:
    void initTestCase()
    {
        QFile file(QStringLiteral(EMOJI_LIST_JSON));
        QVERIFY(file.open(QFile::ReadOnly));
        m_catalogue = QJsonDocument::fromJson(file.readAll()).array();
        QVERIFY(!m_catalogue.isEmpty());

        m_model = new StatusEmojiModel(this);
    }

    // No queued load: the rows exist, and every query answers, straight away.
    void catalogueIsAvailableAsSoonAsTheModelExists()
    {
        StatusEmojiModel model;
        QCOMPARE(model.rowCount(), m_catalogue.size());
        QCOMPARE(model.getEmojiFromHexcode("1f602"), QString::fromUtf8("\U0001F602"));
    }

    // emojiList.json is the generated catalogue the table is built from; this fails
    // when tools/emoji/build-table.py was not re-run after it changed.
    void rowsMatchTheCatalogue()
    {
        StatusEmojiModel model;
        QCOMPARE(model.rowCount(), m_catalogue.size());
        const auto roles = model.roleNames();
        for (int row = 0; row < m_catalogue.size(); ++row) {
            const auto entry = m_catalogue.at(row).toObject();
            const auto index = model.index(row, 0);
            for (auto it = roles.cbegin(); it != roles.cend(); ++it) {
                if (it.key() == StatusEmojiModel::SkinColorRole)
                    continue;
                const auto name = QString::fromLatin1(it.value());
                QVERIFY2(QJsonValue::fromVariant(model.data(index, it.key())) == entry.value(name),
                         qPrintable(u"row %1 (%2), role %3"_s.arg(row).arg(
                             entry.value("unicode").toString(), name)));
            }
        }
    }

    // The lookups binary-search sorted indices of the table; an index that is out of
    // order or stale loses entries without any row being wrong.
    void everyEntryIsFoundThroughEveryIndex()
    {
        StatusEmojiModel model;
        QHash<QString, QString> asciiOwners; // the first entry listing an emoticon owns it
        for (const auto &value : std::as_const(m_catalogue)) {
            const auto entry = value.toObject();
            const auto unicode = entry.value("unicode").toString();
            const auto emoji = entry.value("emoji").toString();
            const auto shortname = entry.value("shortname").toString();

            QVERIFY2(model.getEmojiFromHexcode(unicode) == emoji, qPrintable(unicode));
            QVERIFY2(model.getEmojiFromHexcode(canonicalForm(unicode)) == emoji,
                     qPrintable(canonicalForm(unicode)));
            QVERIFY2(model.getEmojiUnicodeFromShortname(shortname) == unicode,
                     qPrintable(shortname));

            for (const auto &alias : entry.value("aliases_ascii").toArray())
                asciiOwners.insert(alias.toString(), asciiOwners.value(alias.toString(), emoji));
        }
        QVERIFY(!asciiOwners.isEmpty());
        for (auto it = asciiOwners.cbegin(); it != asciiOwners.cend(); ++it)
            QVERIFY2(model.getEmojiFromAsciiAlias(it.key()) == it.value(), qPrintable(it.key()));
    }

    // The canonical fallback hides a broken hexcode index from the lookups above, so
    // check the indices themselves: each a permutation of the entries, strictly sorted.
    void indicesAreSortedPermutations()
    {
        QVERIFY(isSortedPermutation(EmojiTable::byUnicode, &EmojiTable::Entry::unicode));
        QVERIFY(isSortedPermutation(EmojiTable::byCanonical, &EmojiTable::Entry::canonical));
        QVERIFY(isSortedPermutation(EmojiTable::byShortname, &EmojiTable::Entry::shortname));
    }

    void categoryOffsetIsTheFirstRowOfTheCategory()
    {
        StatusEmojiModel model;
        const auto categories = model.property("categories").toStringList();
        for (int category = 1; category < categories.size(); ++category) {
            const auto first = std::find_if(m_catalogue.cbegin(), m_catalogue.cend(),
                                            [&](const auto &value) {
                                                return value.toObject().value("category").toString()
                                                       == categories.at(category);
                                            });
            QVERIFY2(first != m_catalogue.cend(), qPrintable(categories.at(category)));
            QCOMPARE(model.getCategoryOffset(category), int(first - m_catalogue.cbegin()));
        }
    }

    void skinColorRole_data()
    {
        QTest::addColumn<QString>("hexcode");
        QTest::addColumn<QString>("skinColor");

        QTest::newRow("no skins") << "1f600" << "";
        QTest::newRow("base of a toned emoji") << "1f44d" << "base";
        QTest::newRow("toned") << "1f44d-1f3fb" << "1f3fb";
        QTest::newRow("darkest tone") << "1f44d-1f3ff" << "1f3ff";
        QTest::newRow("toned zwj") << "1f6b6-1f3fb-200d-27a1-fe0f" << "1f3fb";
        QTest::newRow("flag") << "1f1fa-1f1f8" << "";
    }

    void skinColorRole()
    {
        QFETCH(QString, hexcode);
        QFETCH(QString, skinColor);

        StatusEmojiModel model;
        const auto unicode = model.canonicalUnicode(hexcode);
        QVERIFY2(!unicode.isEmpty(), qPrintable(hexcode));
        for (int row = 0; row < model.rowCount(); ++row) {
            const auto index = model.index(row, 0);
            if (model.data(index, StatusEmojiModel::UnicodeRole).toString() == unicode) {
                QCOMPARE(model.data(index, StatusEmojiModel::SkinColorRole).toString(), skinColor);
                return;
            }
        }
        QFAIL("no row for the hexcode");
    }

    // A suggestion carries the whole entry, like the catalogue row it comes from.
    void suggestionsCarryTheWholeEntry_data()
    {
        QTest::addColumn<QString>("unicode");

        QTest::newRow("plain") << "1f600";
        QTest::newRow("selector") << "2764";
        QTest::newRow("keycap") << "0031-fe0f-20e3";
        QTest::newRow("toned zwj") << "1f6b6-1f3fb-200d-27a1-fe0f";
        QTest::newRow("flag") << "1f1fa-1f1f8";
        QTest::newRow("ascii aliases") << "1f642";
    }

    void suggestionsCarryTheWholeEntry()
    {
        QFETCH(QString, unicode);

        const auto it = std::find_if(m_catalogue.cbegin(), m_catalogue.cend(),
                                     [&unicode](const auto &value) {
                                         return value.toObject().value("unicode").toString()
                                                == unicode;
                                     });
        QVERIFY2(it != m_catalogue.cend(), qPrintable(unicode));
        const auto entry = it->toObject();
        const auto result = m_model->getSuggestions(entry.value("shortname").toString());
        QVERIFY(std::any_of(result.cbegin(), result.cend(),
                            [&entry](const auto &value) { return value.toObject() == entry; }));
    }

    // Flags make poor account emoji; the rest of the catalogue is fair game.
    void randomEmojiIsNeverAFlag()
    {
        QSet<QString> flags, others;
        for (const auto &value : std::as_const(m_catalogue)) {
            const auto entry = value.toObject();
            (entry.value("category").toString() == "flags"_L1 ? flags : others)
                .insert(entry.value("emoji").toString());
        }
        QSet<QString> seen;
        for (int i = 0; i < 2000; ++i) {
            QString emoji;
            QVERIFY(QMetaObject::invokeMethod(m_model, "getRandomEmoji", Q_RETURN_ARG(QString, emoji)));
            QVERIFY2(!flags.contains(emoji), qPrintable(emoji));
            QVERIFY2(others.contains(emoji), qPrintable(emoji));
            seen.insert(emoji);
        }
        QVERIFY(seen.size() > 1000);
    }

    // The catalogue lives in the binary's read-only data; the json must not be shipped
    // and parsed at runtime again.
    void catalogueIsNotShippedAsJson()
    {
        QVERIFY(!QFile::exists(u":/StatusQ/Core/Utils/emojiList.json"_s));
    }

    void getSuggestions_matchesKeyword()
    {
        const auto result = m_model->getSuggestions("grin");
        QCOMPARE(result.size(), 9);
        QCOMPARE(unicodes(result).mid(0, 4),
                 QStringList({"1f600", "1f603", "1f604", "1f601"}));
    }

    void getSuggestions_matchesShortnameIncludingSkins()
    {
        const auto result = m_model->getSuggestions("thumbsup");
        QCOMPARE(result.size(), 6);
        const auto uc = unicodes(result);
        QCOMPARE(uc.constFirst(), "1f44d");
        QVERIFY(uc.contains("1f44d-1f3fb"));
    }

    void getSuggestions_matchesAlias()
    {
        const auto result = m_model->getSuggestions(":grinning_face:");
        QCOMPARE(result.size(), 1);
        const auto emoji = result.first().toObject();
        QCOMPARE(emoji.value("unicode").toString(), "1f600");
        QCOMPARE(emoji.value("name").toString(), "grinning face");
        QCOMPARE(emoji.value("shortname").toString(), ":grinning:");
    }

    void getSuggestions_isCaseSensitive()
    {
        QVERIFY(m_model->getSuggestions("GRIN").isEmpty());
    }

    void getSuggestions_noMatch()
    {
        QVERIFY(m_model->getSuggestions("zzzxq").isEmpty());
    }

    void getSuggestions_emptyInputMatchesAll()
    {
        QCOMPARE(m_model->getSuggestions({}).size(), m_catalogue.size());
    }

    void getSuggestions_excludesRecentDuplicates()
    {
        m_model->addRecentEmoji("1f600");
        QCOMPARE(m_model->getSuggestions(":grinning_face:").size(), 1);
    }

    void asciiAliases()
    {
        QCOMPARE(m_model->maxAsciiEmojiAliasLength(), 3);
        QCOMPARE(m_model->getEmojiFromAsciiAlias(":)"), QString::fromUtf8("\U0001F642"));
        QCOMPARE(m_model->getEmojiFromAsciiAlias(">:)"), QString::fromUtf8("\U0001F608"));
        QVERIFY(m_model->getEmojiFromAsciiAlias("not-an-emoticon").isEmpty());
        QVERIFY(m_model->getEmojiFromAsciiAlias({}).isEmpty());
    }

    // The hexcode follows Twemoji's filename convention, which drops U+FE0F, so it must
    // not be turned back into a character by hand: the catalogue holds the fully-qualified
    // form, and without the selector these render in a text font rather than as emoji.
    void hexcodeLookupReturnsTheFullyQualifiedCharacter()
    {
        QCOMPARE(m_model->getEmojiFromHexcode("2764"), QString::fromUtf8("\u2764\uFE0F"));
        QCOMPARE(m_model->getEmojiFromHexcode("263a"), QString::fromUtf8("\u263A\uFE0F"));
        QCOMPARE(m_model->getEmojiFromHexcode("1f590"), QString::fromUtf8("\U0001F590\uFE0F"));
        // one that needs no selector, to show the lookup is not just appending one
        QCOMPARE(m_model->getEmojiFromHexcode("1f602"), QString::fromUtf8("\U0001F602"));
        // skin tone variants are keyed by their own hexcode
        QCOMPARE(m_model->getEmojiFromHexcode("1f590-1f3fb"),
                 QString::fromUtf8("\U0001F590\U0001F3FB"));
        QVERIFY(m_model->getEmojiFromHexcode("not-a-hexcode").isEmpty());
        QVERIFY(m_model->getEmojiFromHexcode({}).isEmpty());
    }

    // The catalogue follows emojibase, which spells a keycap "0031-fe0f-20e3"; the ids
    // this app persisted before (recents) and the ones peers send for reactions use
    // Twemoji's filename spelling, "31-20e3". Both have to find the same entry, or an old
    // reaction renders through the unqualified-codepoint fallback.
    void hexcodeLookupAcceptsEverySpelling_data()
    {
        QTest::addColumn<QString>("one");
        QTest::addColumn<QString>("other");

        QTest::newRow("keycap") << "31-20e3" << "0031-fe0f-20e3";
        QTest::newRow("keycap hash") << "23-20e3" << "0023-fe0f-20e3";
        QTest::newRow("copyright") << "a9" << "00a9";
        QTest::newRow("registered") << "ae" << "00ae";
        QTest::newRow("eye in speech bubble")
            << "1f441-200d-1f5e8" << "1f441-fe0f-200d-1f5e8-fe0f";
        QTest::newRow("upper case") << "1f602" << "1F602";
        QTest::newRow("selector on a plain id") << "1f602" << "1f602-fe0f";
    }

    void hexcodeLookupAcceptsEverySpelling()
    {
        QFETCH(QString, one);
        QFETCH(QString, other);

        const auto id = m_model->canonicalUnicode(one);
        QVERIFY2(!id.isEmpty(), qPrintable(one));
        QCOMPARE(m_model->canonicalUnicode(other), id);
        QVERIFY(!m_model->getEmojiFromHexcode(one).isEmpty());
        QCOMPARE(m_model->getEmojiFromHexcode(other), m_model->getEmojiFromHexcode(one));
    }

    // An entry with no shortname draws a blank row in the suggestion list, and two
    // entries sharing one cannot be told apart there. joypixels names neither the
    // Emoji 15.1 additions nor the skin variants, so the generator fills both in.
    void everyEntryHasAUniqueShortname()
    {
        StatusEmojiModel model;
        QStringList unnamed, duplicates;
        QSet<QString> seen;
        for (int row = 0; row < model.rowCount(); ++row) {
            const auto index = model.index(row, 0);
            const auto shortname = model.data(index, StatusEmojiModel::ShortnameRole).toString();
            if (shortname.isEmpty())
                unnamed.append(model.data(index, StatusEmojiModel::NameRole).toString());
            else if (seen.contains(shortname))
                duplicates.append(shortname);
            else
                seen.insert(shortname);
        }
        QVERIFY2(unnamed.isEmpty(), qPrintable(unnamed.mid(0, 5).join(u", "_s)));
        QVERIFY2(duplicates.isEmpty(), qPrintable(duplicates.mid(0, 5).join(u", "_s)));
    }

    void shortnamesDerivedFromLabelsAreTypeable()
    {
        QCOMPARE(m_model->getEmojiUnicodeFromShortname(":head_shaking_horizontally:"),
                 "1f642-200d-2194-fe0f"_L1);
        // the tone has to come from the `tone` field: emojibase gives these skins the
        // bare base label, so slugging alone would collide
        QCOMPARE(m_model->getEmojiUnicodeFromShortname(":person_walking_facing_right_tone1:"),
                 "1f6b6-1f3fb-200d-27a1-fe0f"_L1);
    }

    void canonicalUnicodeReportsUnknownIds()
    {
        QVERIFY(m_model->canonicalUnicode("not-a-hexcode").isEmpty());
        QVERIFY(m_model->canonicalUnicode("ffffff").isEmpty());
        QVERIFY(m_model->canonicalUnicode({}).isEmpty());
    }

    // Recents are persisted as ids, so a list written by an older version must still
    // show up - once, under the id the catalogue uses now.
    void recentEmojisStoredUnderAnOldIdAreHealed()
    {
        StatusEmojiModel model;
        const auto keycap = model.canonicalUnicode("31-20e3");
        QVERIFY(!keycap.isEmpty());

        model.setProperty("recentEmojis", QStringList{"31-20e3", "0031-fe0f-20e3", "2764"});

        QCOMPARE(model.property("recentEmojis").toStringList(),
                 (QStringList{keycap, "2764"}));
        QCOMPARE(model.data(model.index(0, 0), StatusEmojiModel::UnicodeRole).toString(),
                 keycap);
        QCOMPARE(model.data(model.index(0, 0), StatusEmojiModel::CategoryRole).toString(),
                 "recent"_L1);
    }

    void benchmarkAsciiAliasLookup()
    {
        // mimics ChatTextArea's per-keystroke lookup of the text before the caret
        const QStringList chunks{">:)", ":)", ")", "abc", "bc", "c"};
        int found = 0;
        QBENCHMARK {
            found = m_model->maxAsciiEmojiAliasLength() > 0 ? 0 : -1;
            for (const auto &chunk : chunks)
                found += m_model->getEmojiFromAsciiAlias(chunk).isEmpty() ? 0 : 1;
        }
        QCOMPARE(found, 2);
    }

    void benchmarkGetSuggestions_data()
    {
        QTest::addColumn<QString>("input");

        for (const auto &input : {"gr", "grin", "thumbsup", "zzzxq", "fa"})
            QTest::newRow(input) << QString::fromLatin1(input);
    }

    void benchmarkGetSuggestions()
    {
        QFETCH(QString, input);

        QBENCHMARK {
            m_model->getSuggestions(input);
        }
    }
};

QTEST_GUILESS_MAIN(tst_StatusEmojiModel)
#include "tst_statusemojimodel.moc"
