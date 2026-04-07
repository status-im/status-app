pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick

import StatusQ.Core.Utils as SQUtils

SQUtils.QObject {
    readonly property alias baseFont: baseFont.font
    readonly property alias monoFont: monoFont.font
    readonly property alias codeFont: codeFont.font

    FontLoader {
        id: baseFont

        source: Assets.assetPath + "fonts/Inter/Inter-Regular.otf"
    }

    FontLoader {
        id: monoFont

        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Regular.otf"
    }

    FontLoader {
        id: codeFont

        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-Regular.ttf"
    }

    // Inter font variants
    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-Thin.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-ExtraLight.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-Light.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-Medium.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-Bold.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-ExtraBold.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/Inter/Inter-Black.otf"
    }

    // Inter Status font variants
    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Thin.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-ExtraLight.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Light.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Medium.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Bold.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-ExtraBold.otf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/InterStatus/InterStatus-Black.otf"
    }

    // Roboto font variants
    FontLoader {
        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-Thin.ttf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-ExtraLight.ttf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-Light.ttf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-Medium.ttf"
    }

    FontLoader {
        source: Assets.assetPath + "fonts/RobotoMono/RobotoMono-Bold.ttf"
    }
}
