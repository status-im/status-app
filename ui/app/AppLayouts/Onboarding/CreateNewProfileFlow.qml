import QtQuick

import AppLayouts.Onboarding.pages

OnboardingStackView {
    id: root

    required property var passwordStrengthScoreFunction
    property bool stayLoggedInAvailable: false

    signal finished(string password)
    signal stayLoggedInRequested(bool enabled)

    initialItem: CreatePasswordPage {
        passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
        stayLoggedInAvailable: root.stayLoggedInAvailable

        onStayLoggedInRequested: (enabled) => root.stayLoggedInRequested(enabled)
        onSetPasswordRequested: (password) => root.finished(password)
    }
}
