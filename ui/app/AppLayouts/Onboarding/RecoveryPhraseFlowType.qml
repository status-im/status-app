import QtQml

// UseRecoveryPhraseFlow.type values, in their own type so that naming one does not load the flow
QtObject {
    enum Type {
        NewProfile,
        KeycardRecovery,
        Login
    }
}
