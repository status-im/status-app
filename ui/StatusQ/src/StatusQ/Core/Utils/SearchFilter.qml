pragma ComponentBehavior: Bound

import SortFilterProxyModel

RegExpFilter {
    required property string searchPhrase

    pattern: `*${searchPhrase}*`
    caseSensitivity: Qt.CaseInsensitive
    syntax: RegExpFilter.Wildcard
}
