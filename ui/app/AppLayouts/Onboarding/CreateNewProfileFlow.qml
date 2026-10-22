import QtQuick

import AppLayouts.Onboarding.pages

OnboardingStackView {
    id: root

    required property var passwordStrengthScoreFunction
    property bool stayLoggedInAvailable: false
    property bool biometricsAvailable: false

    signal finished(string password)
    signal stayLoggedInRequested(bool enabled)
    signal enableBiometricsRequested(bool enable)

    initialItem: CreatePasswordPage {
        passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
        stayLoggedInAvailable: root.stayLoggedInAvailable
        biometricsAvailable: root.biometricsAvailable

        onStayLoggedInRequested: (enabled) => root.stayLoggedInRequested(enabled)
        onEnableBiometricsRequested: (enable) => root.enableBiometricsRequested(enable)
        onSetPasswordRequested: (password) => root.finished(password)
    }
}
