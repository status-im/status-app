#include "StatusQ/statusemojimodel.h"

#include "emojitable.h"

#include <QJsonObject>
#include <QRandomGenerator>
#include <QSettings>

#include <algorithm>
#include <array>
#include <cstring>
#include <string_view>

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr auto kAliases = "aliases";
constexpr auto kAliasesAscii = "aliases_ascii";
constexpr auto kCategory = "category";
constexpr auto kEmoji = "emoji";
constexpr auto kEmojiOrder = "emoji_order";
constexpr auto kKeywords = "keywords";
constexpr auto kName = "name";
constexpr auto kShortname = "shortname";
constexpr auto kUnicode = "unicode";
constexpr auto kHasSkins = "hasSkins";
constexpr auto kSkinColor = "skinColor";
constexpr auto kBaseColor = "base";

constexpr auto skinColors = std::array<const char*, 5>{"1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff"};

constexpr auto MAX_EMOJI_NUMBER = 36;

constexpr auto kRecentCategoryName = "recent"_L1;

constexpr auto kRecentEmojisSettingsEntry = "recentEmojis"_L1;

constexpr std::uint8_t kNoSkins = 0;
constexpr std::uint8_t kBaseSkin = 1;

// The spelling-insensitive form of a hexcode: no variation selectors, no leading zeros.
// The catalogue follows emojibase, which writes "0031-fe0f-20e3"; ids persisted by older
// versions and ids seen on the wire use Twemoji's filename spelling, "31-20e3". Both must
// find the same entry. The generator guarantees these are unique across the catalogue.
QString canonicalForm(const QString &hexcode)
{
    QStringList parts;
    for (const auto &part : hexcode.toLower().split(u'-', Qt::SkipEmptyParts)) {
        if (part == "fe0f"_L1)
            continue;
        qsizetype digit = 0; // drop leading zeros, keeping at least one digit
        while (digit + 1 < part.size() && part.at(digit) == u'0')
            ++digit;
        parts.append(part.mid(digit));
    }
    return parts.join(u'-');
}

// StatusEmojiModel::categories(); EmojiTable::Entry::category indexes it past "recent".
const QStringList &categoryNames()
{
    static const QStringList categories{kRecentCategoryName,
        "smileys, people & body"_L1,
        "animals & nature"_L1,
        "food & drink"_L1,
        "travel & places"_L1,
        "activities"_L1,
        "objects"_L1,
        "symbols"_L1,
        "flags"_L1
    };
    return categories;
}

const char *text(EmojiTable::StringRef ref)
{
    return reinterpret_cast<const char *>(EmojiTable::strings + ref);
}

QString string(EmojiTable::StringRef ref)
{
    return QString::fromUtf8(text(ref));
}

template <typename F>
void forEachItem(EmojiTable::ListRef ref, F &&f)
{
    const auto count = EmojiTable::lists[ref];
    for (std::uint32_t i = 1; i <= count; ++i)
        f(EmojiTable::lists[ref + i]);
}

QStringList stringList(EmojiTable::ListRef ref)
{
    QStringList result;
    forEachItem(ref, [&result](auto item) { result.append(string(item)); });
    return result;
}

QJsonArray jsonArray(EmojiTable::ListRef ref)
{
    QJsonArray result;
    forEachItem(ref, [&result](auto item) { result.append(string(item)); });
    return result;
}

const EmojiTable::Entry &entry(int index)
{
    return EmojiTable::entries[index];
}

// Binary search of a table index sorted bytewise by `field`.
template <typename Index, typename Field>
const Index *findSorted(const Index *begin, const Index *end, const QByteArray &key, Field field)
{
    const auto it = std::lower_bound(begin, end, key, [&field](const Index &index, const QByteArray &wanted) {
        return std::strcmp(text(field(index)), wanted.constData()) < 0;
    });
    if (it != end && key == text(field(*it)))
        return it;
    return end;
}

int findEntry(const std::uint16_t *index, const QString &value, EmojiTable::StringRef EmojiTable::Entry::*field)
{
    const auto end = index + EmojiTable::entryCount;
    const auto it = findSorted(index, end, value.toUtf8(),
                               [field](std::uint16_t i) { return entry(i).*field; });
    return it != end ? *it : -1;
}

QJsonObject jsonObject(const EmojiTable::Entry &emoji)
{
    return {
        {kAliases, jsonArray(emoji.aliases)},
        {kAliasesAscii, jsonArray(emoji.aliasesAscii)},
        {kCategory, categoryNames().at(emoji.category + 1)},
        {kEmoji, string(emoji.emoji)},
        {kEmojiOrder, emoji.order},
        {kHasSkins, emoji.skin == kBaseSkin},
        {kKeywords, jsonArray(emoji.keywords)},
        {kName, string(emoji.name)},
        {kShortname, string(emoji.shortname)},
        {kUnicode, string(emoji.unicode)},
    };
}
}

StatusEmojiModel::StatusEmojiModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int StatusEmojiModel::rowCount(const QModelIndex &parent) const
{
    return m_recentEntries.size() + EmojiTable::entryCount;
}

int StatusEmojiModel::entryForRow(int row) const
{
    return row < m_recentEntries.size() ? m_recentEntries.at(row) : row - m_recentEntries.size();
}

QVariant StatusEmojiModel::data(const QModelIndex &index, int role) const
{
    const auto row = index.row();
    if (row < 0 || row >= rowCount())
        return {};

    const auto isRecent = row < m_recentEntries.size();
    const auto &emoji = entry(entryForRow(row));

    switch (static_cast<EmojiRoles>(role)) {
    case AliasesRole:
        return stringList(emoji.aliases);
    case AliasesAsciiRole:
        return stringList(emoji.aliasesAscii);
    case CategoryRole:
        return isRecent ? QString(kRecentCategoryName) : categoryNames().at(emoji.category + 1);
    case EmojiRole:
        return string(emoji.emoji);
    case EmojiOrderRole:
        return isRecent ? 0 : emoji.order; // recents sort by insertion order, before the rest
    case KeywordsRole:
        return stringList(emoji.keywords);
    case NameRole:
        return string(emoji.name);
    case ShortnameRole:
        return string(emoji.shortname);
    case UnicodeRole:
        return string(emoji.unicode);
    case SkinColorRole:
        if (emoji.skin == kNoSkins)
            return QString();
        if (emoji.skin == kBaseSkin)
            return QString::fromLatin1(kBaseColor);
        return QString::fromLatin1(skinColors.at(emoji.skin - 2));
    }

    return {};
}

QHash<int, QByteArray> StatusEmojiModel::roleNames() const
{
    static const QHash<int, QByteArray> roles{
        {AliasesRole, kAliases},
        {AliasesAsciiRole, kAliasesAscii},
        {CategoryRole, kCategory},
        {EmojiRole, kEmoji},
        {EmojiOrderRole, kEmojiOrder},
        {KeywordsRole, kKeywords},
        {NameRole, kName},
        {ShortnameRole, kShortname},
        {UnicodeRole, kUnicode},
        {SkinColorRole, kSkinColor},
    };

    return roles;
}

QString StatusEmojiModel::getEmojiUnicodeFromShortname(const QString &shortname) const
{
    const auto index = findEntry(EmojiTable::byShortname, shortname, &EmojiTable::Entry::shortname);
    return index >= 0 ? string(entry(index).unicode) : QString();
}

QString StatusEmojiModel::getEmojiFromAsciiAlias(const QString &alias) const
{
    const auto end = EmojiTable::asciiAliases + EmojiTable::asciiAliasCount;
    const auto it = findSorted(EmojiTable::asciiAliases, end, alias.toUtf8(),
                               [](const EmojiTable::AsciiAlias &a) { return a.alias; });
    return it != end ? string(entry(it->entry).emoji) : QString();
}

QString StatusEmojiModel::getEmojiFromHexcode(const QString &hexcode) const
{
    const auto index = entryForHexcode(hexcode);
    return index >= 0 ? string(entry(index).emoji) : QString();
}

QString StatusEmojiModel::canonicalUnicode(const QString &hexcode) const
{
    const auto index = entryForHexcode(hexcode);
    return index >= 0 ? string(entry(index).unicode) : QString();
}

int StatusEmojiModel::entryForHexcode(const QString &hexcode) const
{
    if (hexcode.isEmpty())
        return -1;
    const auto index = findEntry(EmojiTable::byUnicode, hexcode, &EmojiTable::Entry::unicode);
    if (index >= 0)
        return index;
    return findEntry(EmojiTable::byCanonical, canonicalForm(hexcode), &EmojiTable::Entry::canonical);
}

QJsonArray StatusEmojiModel::getSuggestions(const QString &name) const
{
    // UTF-8 is self-synchronising, so a byte match is a character match.
    const auto needle = name.toUtf8();
    const std::string_view key(needle.constData(), needle.size());
    const auto contains = [&key](EmojiTable::StringRef ref) {
        return std::string_view(text(ref)).find(key) != std::string_view::npos;
    };
    const auto anyContains = [&contains](EmojiTable::ListRef ref) {
        bool found = false;
        forEachItem(ref, [&](auto item) { found = found || contains(item); });
        return found;
    };

    QJsonArray result;
    for (int i = 0; i < EmojiTable::entryCount; ++i) {
        const auto &emoji = entry(i);
        if (contains(emoji.name) || contains(emoji.shortname) || anyContains(emoji.aliases)
            || anyContains(emoji.keywords))
            result.append(jsonObject(emoji));
    }
    return result;
}

int StatusEmojiModel::maxAsciiEmojiAliasLength() const
{
    return EmojiTable::maxAsciiAliasLength;
}

QString StatusEmojiModel::getRandomEmoji() const
{
    const auto index = QRandomGenerator::global()->bounded(int(EmojiTable::firstFlagEntry));
    return string(entry(index).emoji);
}

int StatusEmojiModel::getCategoryOffset(int categoryIndex) const {
    if (categoryIndex <= 0 || categoryIndex >= categories().size())
        return 0;
    return EmojiTable::categoryStart[categoryIndex - 1] + m_recentEntries.size();
}

QStringList StatusEmojiModel::categories() const
{
    return categoryNames();
}

QStringList StatusEmojiModel::categoryIcons() const
{
    static const QStringList categoryIcons{
        "time"_L1,
        "smileys-and-people"_L1,
        "animals-and-nature"_L1,
        "food-and-drinks"_L1,
        "activity"_L1,
        "travel-and-places"_L1,
        "objects"_L1,
        "symbols"_L1,
        "flags"_L1
    };
    return categoryIcons;
}

QStringList StatusEmojiModel::recentEmojis() const
{
    return m_recentEmojis;
}

void StatusEmojiModel::setRecentEmojis(const QStringList &newRecentEmojis)
{
    if (m_recentEmojis == newRecentEmojis)
        return;
    m_recentEmojis = newRecentEmojis;
    cleanAndResizeRecentEmojis();
    addRecentEmojisToModel(m_recentEmojis);
    emit recentEmojisChanged();
}

void StatusEmojiModel::addRecentEmoji(const QString &hexcode)
{
    m_recentEmojis.prepend(hexcode);
    cleanAndResizeRecentEmojis();
    addRecentEmojisToModel(m_recentEmojis);
    emit recentEmojisChanged();
}

void StatusEmojiModel::cleanAndResizeRecentEmojis()
{
    if (m_recentEmojis.isEmpty())
        return;
    // Rewrite ids an older version stored under a different spelling, so the list
    // self-heals and the two spellings cannot both sit in it.
    for (auto &hexcode : m_recentEmojis) {
        const auto index = entryForHexcode(hexcode);
        if (index >= 0)
            hexcode = string(entry(index).unicode);
    }
    m_recentEmojis.removeDuplicates();
    if (m_recentEmojis.size() > MAX_EMOJI_NUMBER) {
        while (m_recentEmojis.size() > MAX_EMOJI_NUMBER)
            m_recentEmojis.removeLast();
    }
}

void StatusEmojiModel::addRecentEmojisToModel(const QStringList &emojiHexcodes)
{
    QList<int> recentEntries;
    for (const auto &hexcode : emojiHexcodes) {
        const auto index = entryForHexcode(hexcode);
        if (index >= 0)
            recentEntries.append(index);
    }

    beginResetModel();
    m_recentEntries = recentEntries;
    endResetModel();
}

QString StatusEmojiModel::recentCategoryName() const
{
    return kRecentCategoryName;
}

QString StatusEmojiModel::baseSkinColorName() const
{
    return kBaseColor;
}

QString StatusEmojiModel::userUID() const
{
    return m_userUID;
}

void StatusEmojiModel::setUserUID(const QString &newUserUID)
{
    if (m_userUID == newUserUID)
        return;
    m_userUID = newUserUID;
    emit userUIDChanged();

    loadRecentEmojis();
    connect(this, &StatusEmojiModel::recentEmojisChanged, this, &StatusEmojiModel::saveRecentEmojis);
}

QString StatusEmojiModel::settingsGroup() const
{
    return QStringLiteral("AppMainLocalSettings_%1").arg(m_userUID);
}

void StatusEmojiModel::saveRecentEmojis()
{
    QSettings settings;
    settings.beginGroup(settingsGroup());
    settings.setValue(kRecentEmojisSettingsEntry, m_recentEmojis);
    settings.endGroup();
}

void StatusEmojiModel::loadRecentEmojis()
{
    QSettings settings;
    settings.beginGroup(settingsGroup());
    setRecentEmojis(settings.value(kRecentEmojisSettingsEntry).toStringList());
    settings.endGroup();
}
