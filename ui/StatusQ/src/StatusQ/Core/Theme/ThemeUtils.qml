pragma Singleton

import QtQml
import QtQuick

import StatusQ.Core.Theme

QtObject {
    enum Style {
        Light,
        Dark,
        System
    }

    enum FontSize {
        FontSizeXS,
        FontSizeS,
        FontSizeM,
        FontSizeL,
        FontSizeXL,
        FontSizeXXL
    }

    enum PaddingFactor {
        PaddingXXS,
        PaddingXS,
        PaddingS,
        PaddingM,
        PaddingL
    }

    enum AnimationDuration {
        Fast = 100,
        Default = 250, // https://doc.qt.io/qt-5/qml-qtquick-propertyanimation.html#duration-prop
        Slow = 400
    }

    readonly property size portraitBreakpoint: Qt.size(1200, 680)
    readonly property real disabledOpacity: 0.3
    readonly property real pressedOpacity: 0.7

    function setTheme(target: QtObject, theme: int) {
        switch (theme) {
        case ThemeUtils.Style.Light:
            target.Theme.style = Theme.Style.Light
            break
        case ThemeUtils.Style.Dark:
            target.Theme.style = Theme.Style.Dark
            break
        case ThemeUtils.Style.System:
            target.Theme.style = Qt.binding(() => Application.styleHints.colorScheme === Qt.ColorScheme.Dark
                                            ? Theme.Style.Dark : Theme.Style.Light)
            break
        default:
            console.warn('Unknown theme. Valid themes are "light" and "dark"')
        }
    }

    readonly property int fontSizeOffsetXS: -2
    readonly property int fontSizeOffsetS: -1
    readonly property int fontSizeOffsetM: 0
    readonly property int fontSizeOffsetL: 1
    readonly property int fontSizeOffsetXL: 2
    readonly property int fontSizeOffsetXXL: 3

    readonly property real paddingFactorXXS: 0.4
    readonly property real paddingFactorXS: 0.6
    readonly property real paddingFactorS: 0.8
    readonly property real paddingFactorM: 1
    readonly property real paddingFactorL: 1.2

    function setFontSize(target: QtObject, fontSize: int) {
        switch (fontSize) {
            case ThemeUtils.FontSizeXS:
                target.Theme.fontSizeOffset = fontSizeOffsetXS
                break
            case ThemeUtils.FontSizeS:
                target.Theme.fontSizeOffset = fontSizeOffsetS
                break
            case ThemeUtils.FontSizeM:
                target.Theme.fontSizeOffset = fontSizeOffsetM
                break
            case ThemeUtils.FontSizeL:
                target.Theme.fontSizeOffset = fontSizeOffsetL
                break
            case ThemeUtils.FontSizeXL:
                target.Theme.fontSizeOffset = fontSizeOffsetXL
                break
            case ThemeUtils.FontSizeXXL:
                target.Theme.fontSizeOffset = fontSizeOffsetXXL
                break
        }
    }

    function setPaddingFactor(target: QtObject, paddingFactor: int) {
        switch (paddingFactor) {
        case ThemeUtils.PaddingXXS:
            target.Theme.padding = target.Theme.defaultPadding * paddingFactorXXS
            break
        case ThemeUtils.PaddingXS:
            target.Theme.padding = target.Theme.defaultPadding * paddingFactorXS
            break
        case ThemeUtils.PaddingS:
            target.Theme.padding = target.Theme.defaultPadding * paddingFactorS
            break
        case ThemeUtils.PaddingM:
            target.Theme.padding = target.Theme.defaultPadding * paddingFactorM
            break
        case ThemeUtils.PaddingL:
            target.Theme.padding = target.Theme.defaultPadding * paddingFactorL
            break
        }
    }
}
