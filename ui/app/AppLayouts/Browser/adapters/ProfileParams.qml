import QtQuick

// Value object: all fields must be set at construction; do not mutate after create.
// To switch incognito mode, swap the tab's profileParams reference (default vs otr).
QtObject {
    required property string userId
    required property string userAgent
    required property var scripts
    required property bool offTheRecord

    /// Tabs that only display a downloaded local file (ADR 0006 §8). Orthogonal
    /// to incognito: such a tab is isolated from browsing — a profile of its own
    /// that never reaches disk, no injected scripts, no web channel, and file://
    /// reachable only under the directories the browser itself wrote.
    property bool localPreview: false

    // A local preview is ephemeral whatever tab it was opened from.
    readonly property string storageName:
        (offTheRecord || localPreview) ? "" : "Profile_" + userId
}
