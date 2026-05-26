import QtQuick

// Value object: all fields must be set at construction; do not mutate after create.
// To switch incognito mode, swap the tab's profileParams reference (default vs otr).
QtObject {
    required property string userId
    required property string userAgent
    required property var scripts
    required property bool offTheRecord
}
