pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick

import StatusQ.Internal as Internal

QtObject {
    function escapeHtml(unsafe: string): string {
        return Internal.StringUtils.escapeHtml(unsafe)
    }

    function readTextFile(file: string): string {
        return Internal.StringUtils.readTextFile(file)
    }

    function extractDomainFromLink(link: string): string {
        return Internal.StringUtils.extractDomainFromLink(link)
    }

    function plainText(htmlFragment: string): string {
        return Internal.StringUtils.plainText(htmlFragment)
    }

    function shortcutToText(shortcut: string): string {
        return Internal.StringUtils.shortcutToText(shortcut)
    }
}
