#include "StatusQ/spellchecker.h"
#include "StatusQ/markdownparser.h"

#include <hunspell.hxx>

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QRegularExpression>
#include <QTemporaryDir>
#include <QThread>
#include <algorithm>
#include <memory>

using namespace Qt::Literals::StringLiterals;

namespace {

const QRegularExpression& wordTokens()
{
    static const QRegularExpression tokens(
        "[\\p{L}\\p{M}\\p{N}_]+(?:['\\x{2019}-][\\p{L}\\p{M}\\p{N}_]+)*"_L1,
        QRegularExpression::UseUnicodePropertiesOption);
    return tokens;
}

void excludeNodes(const Markdown::Node& node, QVector<bool>& excluded)
{
    using Markdown::NodeKind;
    const bool url = node.kind == NodeKind::Link
        && (node.children.isEmpty() || node.children.first().kind != NodeKind::Delimiter);
    if (node.kind == NodeKind::CodeBlock || node.kind == NodeKind::CodeSpan
        || url || node.kind == NodeKind::WalletLink
        || node.kind == NodeKind::Mention || node.kind == NodeKind::Delimiter) {
        for (qsizetype i = node.start; i < node.end && i < excluded.size(); ++i)
            excluded[i] = true;
        return;
    }
    for (const auto& child : node.children)
        excludeNodes(child, excluded);
}

QByteArray hunspellPath(const QString& path)
{
#ifdef Q_OS_WIN
    return ("\\\\?\\"_L1 + QDir::toNativeSeparators(path)).toUtf8();
#else
    return QFile::encodeName(path);
#endif
}

} // namespace

class SpellCheckWorker : public QObject
{
    Q_OBJECT
public:
    void check(quint64 id, quint64 generation, const QString& text, int incompletePosition,
               bool skipCapitalized)
    {
        if (!load()) {
            emit checked(id, generation, {}, m_error);
            return;
        }

        QVector<bool> excluded(text.size(), false);
        Markdown::Options options;
        options.formatUnclosedCodeFence = true;
        excludeNodes(Markdown::parse(text, options), excluded);
        auto matches = wordTokens().globalMatchView(text);
        QVariantList issues;
        QString previous;
        int previousEnd = -1;
        QHash<QString, bool> checkedWords;
        while (matches.hasNext()) {
            if (QThread::currentThread()->isInterruptionRequested())
                return;
            const auto match = matches.next();
            const int start = match.capturedStart();
            const int end = match.capturedEnd();
            const QString word = match.captured();
            bool omit = false;
            bool capitalized = false;
            for (int i = start; i < end;) {
                int units = 1;
                const auto codePoint = Markdown::codePointAt(text, i, units);
                omit |= excluded[i] || QChar::isNumber(codePoint) || codePoint == U'_';
                capitalized |= QChar::isUpper(codePoint);
                i += units;
            }
            if (omit) {
                previous.clear();
                previousEnd = -1;
                continue;
            }
            const bool duplicate = previousEnd >= 0 && previous.compare(word, Qt::CaseInsensitive) == 0
                && !text.mid(previousEnd, start - previousEnd).isEmpty()
                && text.mid(previousEnd, start - previousEnd).trimmed().isEmpty();
            previous = word;
            previousEnd = end;
            // Only the token being edited is incomplete, not a completed word
            // subsequently visited by the caret.
            if (incompletePosition >= start && incompletePosition <= end)
                continue;
            if (!duplicate && skipCapitalized && capitalized)
                continue;
            // Hunspell has a byte-length limit; avoid asking it about pathological tokens.
            const auto utf8 = word.toUtf8();
            if (utf8.size() >= MAXWORDLEN)
                continue;
            auto found = checkedWords.constFind(word);
            const bool correct = found != checkedWords.cend() ? *found
                : m_dictionary->spell(std::string(utf8.constData(), utf8.size()));
            checkedWords.insert(word, correct);
            if (duplicate || !correct) {
                issues.append(QVariantMap{
                    {"start"_L1, start}, {"length"_L1, end - start},
                    {"word"_L1, word}, {"duplicate"_L1, duplicate}});
            }
        }
        emit checked(id, generation, issues, {});
    }

    void suggest(quint64 id, quint64 request, const QString& word)
    {
        QStringList suggestions;
        if (load()) {
            for (const auto& suggestion : m_dictionary->suggest(word.toStdString())) {
                suggestions.append(QString::fromUtf8(suggestion));
                if (suggestions.size() >= 5)
                    break;
            }
        }
        emit suggested(id, request, suggestions, m_error);
    }

signals:
    void checked(quint64 id, quint64 generation, const QVariantList& issues, const QString& error);
    void suggested(quint64 id, quint64 request, const QStringList& suggestions, const QString& error);

private:
    bool load()
    {
        if (m_dictionary)
            return true;
        if (!m_error.isEmpty())
            return false;
        m_directory = std::make_unique<QTemporaryDir>();
        if (!m_directory->isValid()) {
            m_error = QStringLiteral("Cannot create spell-check dictionary directory");
        } else {
            for (const auto& name : {"en_US.aff"_L1, "en_US.dic"_L1}) {
                if (!QFile::copy(":/StatusQ/dictionaries/"_L1 + name,
                                 m_directory->filePath(name))) {
                    m_error = QStringLiteral("Cannot extract spell-check dictionary: ") + name;
                    break;
                }
            }
        }
        if (m_error.isEmpty()) {
            const auto aff = hunspellPath(m_directory->filePath("en_US.aff"_L1));
            const auto dic = hunspellPath(m_directory->filePath("en_US.dic"_L1));
            m_dictionary = std::make_unique<Hunspell>(aff.constData(), dic.constData());
            if (qstricmp(m_dictionary->get_dic_encoding(), "UTF-8") != 0
                || !m_dictionary->spell(std::string("hello"))) {
                m_dictionary.reset();
                m_error = QStringLiteral("Cannot load bundled UTF-8 English spell-check dictionary");
            }
        }
        if (!m_error.isEmpty())
            qWarning().noquote() << m_error;
        return bool(m_dictionary);
    }

    std::unique_ptr<QTemporaryDir> m_directory;
    std::unique_ptr<Hunspell> m_dictionary;
    QString m_error;
};

namespace {

class SpellCheckEngine : public QObject
{
public:
    SpellCheckEngine() : QObject(QCoreApplication::instance()), worker(new SpellCheckWorker)
    {
        worker->moveToThread(&thread);
        connect(&thread, &QThread::finished, worker, &QObject::deleteLater);
        thread.setObjectName("SpellCheck"_L1);
        thread.start();
    }
    ~SpellCheckEngine() override
    {
        thread.requestInterruption();
        thread.quit();
        thread.wait();
    }
    QThread thread;
    SpellCheckWorker* worker;
};

SpellCheckWorker* worker()
{
    static SpellCheckEngine* engine = new SpellCheckEngine;
    return engine->worker;
}

} // namespace

SpellChecker::SpellChecker(QObject* parent) : QObject(parent)
{
    static quint64 nextId = 0;
    m_id = ++nextId;
    m_timer.setSingleShot(true);
    m_timer.setInterval(30);
    connect(&m_timer, &QTimer::timeout, this, &SpellChecker::dispatch);
    connect(worker(), &SpellCheckWorker::checked, this,
            [this](quint64 id, quint64 generation, const QVariantList& issues, const QString& error) {
        if (id != m_id)
            return;
        m_inFlight = false;
        if (generation == m_generation && supported()) {
            setCheckPending(false);
            if (m_issues != issues) {
                m_issues = issues;
                emit issuesChanged();
            }
            emit checkFinished();
            if (!error.isEmpty())
                emit errorOccurred(error);
        } else if (supported() && m_checkPending && !m_composing) {
            m_timer.start();
        }
    });
    connect(worker(), &SpellCheckWorker::suggested, this,
            [this](quint64 id, quint64 request, const QStringList& suggestions, const QString& error) {
        if (id != m_id)
            return;
        m_suggestionsInFlight = false;
        if (request != m_suggestionRequest) {
            if (m_suggestionsPending)
                dispatchSuggestions();
            return;
        }
        m_suggestionsPending = false;
        m_suggestions = suggestions;
        emit suggestionsChanged();
        if (!error.isEmpty())
            emit errorOccurred(error);
    });
}

void SpellChecker::setCheckPending(bool value)
{
    if (m_checkPending == value)
        return;
    m_checkPending = value;
    emit checkPendingChanged();
}

bool SpellChecker::supported() const
{
    return m_enabled && (m_language == "en_US"_L1 || m_language == "en"_L1);
}

void SpellChecker::invalidate()
{
    ++m_generation;
    clearSuggestions();
    setCheckPending(supported() && !m_text.isEmpty());
    if (!m_issues.isEmpty()) {
        m_issues.clear();
        emit issuesChanged();
    }
    if (m_checkPending && !m_composing)
        m_timer.start();
    else
        m_timer.stop();
}

void SpellChecker::dispatch()
{
    if (m_inFlight || !m_checkPending || m_composing || !supported() || m_text.isEmpty())
        return;
    m_inFlight = true;
    auto* target = worker();
    const auto id = m_id;
    const auto generation = m_generation;
    const auto text = m_text;
    const auto incompletePosition = m_incompleteEnd;
    const auto skip = m_skipCapitalizedWords;
    QMetaObject::invokeMethod(target, [=] {
        target->check(id, generation, text, incompletePosition, skip);
    }, Qt::QueuedConnection);
}

void SpellChecker::setEnabled(bool value)
{
    if (m_enabled == value)
        return;
    m_enabled = value;
    invalidate();
    emit enabledChanged();
}

void SpellChecker::setLanguage(const QString& value)
{
    if (m_language == value)
        return;
    m_language = value;
    invalidate();
    emit languageChanged();
}

void SpellChecker::setSkipCapitalizedWords(bool value)
{
    if (m_skipCapitalizedWords == value)
        return;
    m_skipCapitalizedWords = value;
    invalidate();
    emit skipCapitalizedWordsChanged();
}

void SpellChecker::setCursorPosition(int value)
{
    if (m_cursorPosition == value)
        return;
    m_cursorPosition = value;
    // Text and caret notifications arrive in either order; evaluate after both.
    if (m_incompleteStart >= 0 && !m_caretCheckQueued) {
        m_caretCheckQueued = true;
        QMetaObject::invokeMethod(this, &SpellChecker::completeWordIfCaretLeft,
                                  Qt::QueuedConnection);
    }
    emit cursorPositionChanged();
}

void SpellChecker::setComposing(bool value)
{
    if (m_composing == value)
        return;
    m_composing = value;
    ++m_generation;
    clearSuggestions();
    m_timer.stop();
    if (!value && m_checkPending)
        m_timer.start();
    emit composingChanged();
}

void SpellChecker::setText(const QString& text)
{
    if (m_text == text)
        return;
    int oldEnd = m_text.size();
    int newEnd = text.size();
    while (oldEnd > 0 && newEnd > 0 && m_text[oldEnd - 1] == text[newEnd - 1]) {
        --oldEnd;
        --newEnd;
    }
    int start = 0;
    while (start < oldEnd && start < newEnd && m_text[start] == text[start])
        ++start;
    const int delta = text.size() - m_text.size();
    const auto inserted = QStringView(text).mid(start, newEnd - start);
    m_text = text;

    static const QRegularExpression boundary(
        "[^\\p{L}\\p{M}\\p{N}_'\\x{2019}-]"_L1,
        QRegularExpression::UseUnicodePropertiesOption);
    // Pastes, programmatic replacements and typed separators complete every
    // word. A single typed or deleted character only edits the word around it.
    const bool complete = inserted.size() > 1 || boundary.matchView(inserted).hasMatch();
    const auto [tokenStart, tokenEnd] = complete ? std::pair{-1, -1} : tokenAt(newEnd);
    // An issue touching the edit is still edited when the edit continues its word, e.g.
    // an undo restoring a vowel sign and more after a flagged consonant. Kept as is, its
    // underline would end inside the word, splitting a grapheme cluster's shaping.
    const bool joinsBefore = tokenAt(start).second > start;
    const bool joinsAfter = tokenAt(newEnd).first < newEnd;

    QVariantList retained;
    QVariantMap flagged;
    for (const auto& value : std::as_const(m_issues)) {
        auto issue = value.toMap();
        const int issueStart = issue.value("start"_L1).toInt();
        const int issueEnd = issueStart + issue.value("length"_L1).toInt();
        const bool before = issueEnd <= start;
        const bool after = issueStart >= oldEnd;
        const int mappedStart = after ? issueStart + delta : issueStart;
        const int mappedEnd = before ? issueEnd : issueEnd + delta;
        const bool joined = (issueEnd == start && joinsBefore)
                || (issueStart == oldEnd && joinsAfter);
        if (mappedStart < tokenEnd && mappedEnd > tokenStart) {
            if (flagged.isEmpty())
                flagged = issue;
        } else if ((before || after) && !joined) {
            issue.insert("start"_L1, mappedStart);
            retained.append(issue);
        }
    }

    const bool wasFlagged = !flagged.isEmpty();
    if (wasFlagged) {
        // Keep an edited misspelling underlined until its new spelling is known.
        flagged.insert("start"_L1, tokenStart);
        flagged.insert("length"_L1, tokenEnd - tokenStart);
        flagged.insert("word"_L1, text.mid(tokenStart, tokenEnd - tokenStart));
        const auto position = std::lower_bound(retained.begin(), retained.end(), tokenStart,
            [](const QVariant& issue, int value) {
                return issue.toMap().value("start"_L1).toInt() < value;
            });
        retained.insert(position, flagged);
    }
    if (complete || wasFlagged) {
        m_incompleteStart = -1;
        m_incompleteEnd = -1;
    } else {
        m_incompleteStart = tokenStart;
        m_incompleteEnd = tokenEnd;
    }

    ++m_generation;
    clearSuggestions();
    if (m_issues != retained) {
        m_issues = retained;
        emit issuesChanged();
    }
    setCheckPending(supported() && !m_text.isEmpty()
        && (m_checkPending || complete || wasFlagged));
    if (m_checkPending && !m_composing)
        m_timer.start();
    else
        m_timer.stop();
}

void SpellChecker::recheck()
{
    m_incompleteStart = -1;
    m_incompleteEnd = -1;
    ++m_generation;
    clearSuggestions();
    setCheckPending(supported() && !m_text.isEmpty());
    if (m_checkPending && !m_composing)
        m_timer.start();
    else
        m_timer.stop();
}

void SpellChecker::acceptReplacement(int start, int length)
{
    QVariantList retained;
    for (const auto& value : std::as_const(m_issues)) {
        const auto issue = value.toMap();
        const int issueStart = issue.value("start"_L1).toInt();
        if (issueStart >= start + length || issueStart + issue.value("length"_L1).toInt() <= start)
            retained.append(issue);
    }
    if (m_issues != retained) {
        m_issues = retained;
        emit issuesChanged();
    }
}

void SpellChecker::completeWordIfCaretLeft()
{
    m_caretCheckQueued = false;
    if (m_incompleteStart < 0
        || (m_cursorPosition >= m_incompleteStart && m_cursorPosition <= m_incompleteEnd))
        return;
    m_incompleteStart = -1;
    m_incompleteEnd = -1;
    // Results excluding the word are now stale; unaffected underlines stay.
    ++m_generation;
    setCheckPending(supported() && !m_text.isEmpty());
    if (m_checkPending && !m_composing)
        m_timer.start();
}

std::pair<int, int> SpellChecker::tokenAt(int position) const
{
    auto matches = wordTokens().globalMatchView(m_text);
    while (matches.hasNext()) {
        const auto match = matches.next();
        if (match.capturedStart() > position)
            break;
        if (position <= match.capturedEnd())
            return {match.capturedStart(), match.capturedEnd()};
    }
    return {-1, -1};
}

QVariantMap SpellChecker::issueAt(int position) const
{
    for (const auto& value : std::as_const(m_issues)) {
        const auto issue = value.toMap();
        const int start = issue.value("start"_L1).toInt();
        if (position >= start && position < start + issue.value("length"_L1).toInt())
            return issue;
    }
    return {};
}

void SpellChecker::clearSuggestions()
{
    ++m_suggestionRequest;
    m_suggestions.clear();
    m_suggestionsPending = false;
    m_suggestionStart = -1;
    m_suggestionWord.clear();
    emit suggestionsChanged();
}

void SpellChecker::requestSuggestions(int position)
{
    clearSuggestions();
    const auto issue = issueAt(position);
    if (issue.isEmpty())
        return;
    m_suggestionStart = issue.value("start"_L1).toInt();
    m_suggestionWord = issue.value("word"_L1).toString();
    if (issue.value("duplicate"_L1).toBool()) {
        emit suggestionsChanged();
        return;
    }
    m_suggestionsPending = true;
    emit suggestionsChanged();
    dispatchSuggestions();
}

void SpellChecker::dispatchSuggestions()
{
    if (m_suggestionsInFlight)
        return;
    m_suggestionsInFlight = true;
    auto* target = worker();
    const auto id = m_id;
    const auto request = m_suggestionRequest;
    const auto word = m_suggestionWord;
    QMetaObject::invokeMethod(target, [=] { target->suggest(id, request, word); }, Qt::QueuedConnection);
}

#include "spellchecker.moc"
