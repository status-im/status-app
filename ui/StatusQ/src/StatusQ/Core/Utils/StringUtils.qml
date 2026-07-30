pragma Singleton

import QtQuick

import StatusQ.Internal as Internal

QtObject {
    function escapeHtml(unsafe) {
        return Internal.StringUtils.escapeHtml(unsafe)
    }

    function readTextFile(file) {
        return Internal.StringUtils.readTextFile(file)
    }

    function writeTextFile(filePath, data) {
        return Internal.StringUtils.writeTextFile(filePath, data)
    }

    function extractDomainFromLink(link) {
        return Internal.StringUtils.extractDomainFromLink(link)
    }

    function plainText(htmlFragment) {
        return Internal.StringUtils.plainText(htmlFragment)
    }

    function shortcutToText(shortcut) {
        return Internal.StringUtils.shortcutToText(shortcut)
    }
}
