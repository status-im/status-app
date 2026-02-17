#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <QMetaEnum>
#include <QObject>

class OnboardingEnums: public QObject
{
    Q_OBJECT
    Q_CLASSINFO("RegisterEnumClassesUnscoped", "false")

public:
    Q_INVOKABLE QJsonArray getModelFromEnum(const QString &name) const {
        if (name.isEmpty())
            return {};

        QMetaEnum e = staticMetaObject.enumerator(staticMetaObject.indexOfEnumerator(name.toLatin1().constData()));
        if (!e.isValid())
            return {};

        QJsonArray result;
        for (int i = 0; i < e.keyCount(); ++i) {
            result.append(
                {{{QStringLiteral("name"), e.key(i)}, {QStringLiteral("value"), e.value(i)}}});
        }

        return result;
    }

    // NOTE: Keep in sync with OnboardingFlow in src/app/modules/onboarding/module.nim
    enum class OnboardingFlow {
        Unknown,

        CreateProfileWithPassword,
        CreateProfileWithSeedphrase,
        CreateProfileWithKeycardNewSeedphrase,
        CreateProfileWithKeycardExistingSeedphrase,

        LoginWithSeedphrase,
        LoginWithSyncing,
        LoginWithKeycard,

        LoginWithLostKeycardSeedphrase,
        LoginWithRestoredKeycard
    };

    enum class LoginMethod {
        Unknown,
        Password,
        Keycard,
        Mnemonic,
    };

    // NOTE: Keep in sync with KeycardState in src/app_service/service/keycardV2/dto.nim
    enum class KeycardState {
        UnknownReaderState,
        NoPCSCService,
        PluginReader,
        InsertKeycard,
        ReadingKeycard,
        // error states
        NotKeycard,
        MaxPairingSlotsReached,
        BlockedPIN, // PIN remaining attempts == 0
        BlockedPUK, // PUK remaining attempts == 0
        FactoryResetting,
        // exit states
        NotEmpty,
        Empty,
        Authorized,
        Cancelled
    };

    enum class ProgressState {
        Idle,
        InProgress,
        Success,
        Failed
    };

    enum class AuthorizationState {
        Idle,
        InProgress,
        Authorized,
        WrongPin,
        Error,
    };

    // Keep in sync with LocalPairingState in src/app_service/service/devices/dto/local_pairing_status.nim
    enum class LocalPairingState {
        Idle,
        Transferring,
        Error,
        Finished,
    };

private:
    Q_ENUM(OnboardingFlow)
    Q_ENUM(LoginMethod)
    Q_ENUM(KeycardState)
    Q_ENUM(ProgressState)
    Q_ENUM(AuthorizationState)
    Q_ENUM(LocalPairingState)
};
