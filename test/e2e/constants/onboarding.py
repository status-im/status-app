from enum import Enum


class OnboardingMessages(Enum):
    WRONG_LOGIN_LESS_LETTERS = 'Display Names must be at least 5 character(s) long'
    WRONG_LOGIN_SYMBOLS_NOT_ALLOWED = 'Invalid characters (use A-Z and 0-9, hyphens and underscores only)'
    WRONG_PASSWORD = 'Minimum 10 characters'
    PASSWORDS_DONT_MATCH = "Passwords don't match"
    PASSWORD_INCORRECT = 'Password incorrect'


class OnboardingScreensHeaders(Enum):
    YOUR_EMOJIHASH_AND_IDENTICON_RING_SCREEN_TITLE = 'Your emojihash and identicon ring'
    YOUR_PROFILE_SCREEN_TITLE = 'Your profile'


class KeysExistText(Enum):
    KEYS_EXIST_TITLE = 'Keys for this account already exist'
    KEYS_EXIST_TEXT = (
        "Keys for this account already exist and can't be added again. If you've lost your password, passcode or Keycard, uninstall the app, reinstall and access your keys by entering your recovery phrase. In case of Keycard try recovering using PUK or reinstall the app and try login with the Keycard option.")

class LanguageCodes(Enum):
    CZECH = 'CS'
    ENGLISH = 'EN'
    KOREAN = 'KO'
