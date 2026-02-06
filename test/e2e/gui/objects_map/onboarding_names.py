from objectmaphelper import RegularExpression

from gui.objects_map.names import statusDesktop_mainWindow, statusDesktop_mainWindow_overlay

# Welcome to status view
startupOnboardingLayout = {"container": statusDesktop_mainWindow, "objectName": "startupOnboardingLayout", "type": "OnboardingLayout", "visible": True}
startupWelcomePage = {"container": startupOnboardingLayout, "type": "WelcomePage", "unnamed": 1, "visible": True}
startupNewsPage = {"container": startupOnboardingLayout, "id": "newsPage", "type": "ColumnLayout", "unnamed": 1, "visible": True}
startupCreateProfileButton = {"container": startupOnboardingLayout, "objectName": "btnCreateProfile", "type": "StatusButton", "visible": True}
startupLoginButton = {"container": startupOnboardingLayout, "objectName": "btnLogin", "type": "StatusButton", "visible": True}
startupApprovalLinks = {"container": startupOnboardingLayout, "objectName": "approvalLinks", "type": "StatusBaseText", "visible": True}
startupLanguageSelector = {"container": statusDesktop_mainWindow, "type": "StatusLanguageSelector", "unnamed": 1, "visible": True}

# Sign in view
enterRecoveryPhraseButton = {"container": startupOnboardingLayout, "objectName": "btnWithSeedphrase", "type": "StatusButton", "visible": True}
logInBySyncingButton = {"container": startupOnboardingLayout, "objectName": "btnBySyncing", "type": "ListItemButton", "visible": True}
logInWithKeycardButton = {"container": startupOnboardingLayout, "objectName": "btnWithKeycard", "type": "ListItemButton", "visible": True}

# Help us improve status popup
onboardingLayout = {"container": statusDesktop_mainWindow, "objectName": "OnboardingLayout", "type": "ContentItem", "visible": True}
helpUsImproveStatusPage = {"container": onboardingLayout, "type": "HelpUsImproveStatusPage", "unnamed": 1, "visible": True}
shareUsageDataButton = {"container": helpUsImproveStatusPage, "objectName": "btnShare", "type": "StatusButton", "visible": True}
notNowButton = {"container": statusDesktop_mainWindow, "objectName": "btnDontShare", "type": "StatusButton", "visible": True}
infoButton = {"container": statusDesktop_mainWindow, "objectName": "infoButton", "type": "OnboardingInfoButton", "visible": True}
gotItButton = {"container": statusDesktop_mainWindow_overlay, "type": "StatusButton", "unnamed": 1, "visible": True}

# CreateYourProfileView
onboardingFrame = {"container": onboardingLayout, "type": "OnboardingFrame", "unnamed": 1, "visible": True}
buttonFrame = {"container": onboardingLayout, "id": "buttonFrame", "type": "OnboardingButtonFrame", "unnamed": 1, "visible": True}
startFreshLetsGoButton = {"container": onboardingFrame, "objectName": "btnCreateWithPassword", "type": "StatusButton", "visible": True}
useRecoveryPhraseButton = {"container": buttonFrame, "objectName": "btnCreateWithSeedPhrase", "type": "ListItemButton", "visible": True}
useEmptyKeycardButton = {"container": statusDesktop_mainWindow, "objectName": "btnCreateWithEmptyKeycard", "type": "ListItemButton", "visible": True}

# Log in by syncing dialog
statusDialog = {"container": statusDesktop_mainWindow_overlay, "objectName": "StatusDialog", "type": "PopupItem", "visible": True}
cancelButton = {"container": statusDesktop_mainWindow_overlay, "type": "StatusFlatButton", "unnamed": 1, "visible": True}
continueButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "btnContinue", "type": "StatusButton", "visible": True}

# ProfileSyncingView
profileSyncedView = {"container": onboardingLayout, "type": "SyncProgressPage", "unnamed": 1, "visible": True}
profileSyncedViewHeader = {"container": profileSyncedView, "type": "StatusBaseText", "unnamed": 1, "visible": True}

# Onboarding import seed phrase view
onboardingImportSeedPhraseView = {"container": onboardingLayout, "type": "SeedphrasePage", "unnamed": 1, "visible": True}
tab12WordsButton = {"container": onboardingImportSeedPhraseView, "objectName": "12SeedButton", "type": "StatusSwitchTabButton"}
tab18WordsButton = {"container": onboardingImportSeedPhraseView, "objectName": "18SeedButton", "type": "StatusSwitchTabButton"}
tab24WordsButton = {"container": onboardingImportSeedPhraseView, "objectName": "24SeedButton", "type": "StatusSwitchTabButton"}
seedPhraseInputField = {"container": onboardingImportSeedPhraseView, "objectName": "enterSeedPhraseInputField", "type": "TextField"}
onboardingImportSeedPhraseContinueButton = {"container": onboardingImportSeedPhraseView, "objectName": "btnContinue", "type": "StatusButton", "visible": True}
invalidSeedText = {"container": onboardingImportSeedPhraseView, "objectName": "enterSeedPhraseInvalidSeedText", "type": "StatusBaseText", "visible": True}

# Map for onboarding locators

onboardingBasePage = {"container": statusDesktop_mainWindow, "objectName": "OnboardingBasePage", "type": "ContentItem", "visible": True}
mainWindow_SyncCodeView = {"container": statusDesktop_mainWindow, "type": "SyncCodeView", "unnamed": 1, "visible": True}
mainWindow_onboardingBackButton_StatusRoundButton = {"container": statusDesktop_mainWindow, "objectName": "onboardingBackButton", "type": "StatusRoundButton", "visible": True}

# Allow Notification View
mainWindow_AllowNotificationsView = {"container": statusDesktop_mainWindow, "type": "AllowNotificationsView", "unnamed": 1, "visible": True}
mainWindow_Start_using_Status_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "allowNotificationsOnboardingOkButton", "type": "StatusButton", "visible": True}

# Welcome View
mainWindow_WelcomeView = {"container": statusDesktop_mainWindow, "type": "WelcomeView", "unnamed": 1, "visible": True}
mainWindow_I_am_new_to_Status_StatusBaseText = {"container": mainWindow_WelcomeView, "objectName": "welcomeViewIAmNewToStatusButton", "type": "StatusButton"}
mainWindow_I_already_use_Status_StatusFlatButton = {"checkable": False, "container": statusDesktop_mainWindow, "id": "btnExistingUser", "type": "StatusFlatButton", "visible": True}

# Get Keys View
mainWindow_KeysMainView = {"container": statusDesktop_mainWindow, "type": "KeysMainView", "unnamed": 1, "visible": True}
mainWindow_Generate_new_keys_StatusButton = {"checkable": False, "container": mainWindow_KeysMainView, "objectName": "keysMainViewPrimaryActionButton", "type": "StatusButton", "visible": True}
mainWindow_Generate_keys_for_new_Keycard_StatusBaseText = {"container": mainWindow_KeysMainView, "id": "button2",
                                                           "type": "StatusBaseText", "unnamed": 1, "visible": True}
mainWindow_Import_seed_phrase = {"container": mainWindow_KeysMainView, "id": "button3", "type": "Row", "unnamed": 1,
                                 "visible": True}

# Import Seed Phrase View
keysMainView_PrimaryAction_Button = {"container": statusDesktop_mainWindow,
                                     "objectName": "keysMainViewPrimaryActionButton", "type": "StatusButton"}
mainWindow_iDontHaveOtherDeviceButton_StatusBaseText = {"container": statusDesktop_mainWindow, "objectName": "iDontHaveOtherDeviceButton", "type": "StatusBaseText", "visible": True}

# Seed Phrase Input View
mainWindow_SeedPhraseInputView = {"container": statusDesktop_mainWindow, "type": "SeedPhraseInputView", "unnamed": 1,
                                  "visible": True}
switchTabBar_12_words_Button = {"container": mainWindow_SeedPhraseInputView, "objectName": "12SeedButton",
                                "type": "StatusSwitchTabButton"}
switchTabBar_18_words_Button = {"container": mainWindow_SeedPhraseInputView, "objectName": "18SeedButton",
                                "type": "StatusSwitchTabButton"}
switchTabBar_24_words_Button = {"container": mainWindow_SeedPhraseInputView, "objectName": "24SeedButton",
                                "type": "StatusSwitchTabButton"}
mainWindow_statusSeedPhraseInputField_TextEdit = {"container": statusDesktop_mainWindow, "objectName": "enterSeedPhraseInputField", "type": "TextField", "visible": True}

mainWindow_Import_StatusButton = {"checkable": False, "container": mainWindow_SeedPhraseInputView,
                                  "objectName": "seedPhraseViewSubmitButton", "type": "StatusButton",
                                  "visible": True}

# SyncCode View
logInBySyncingView = {"container": statusDesktop_mainWindow, "type": "LoginBySyncingPage", "unnamed": 1, "visible": True}
mainWindow_switchTabBar_StatusSwitchTabBar_2 = {"container": statusDesktop_mainWindow, "id": "switchTabBar", "type": "StatusSwitchTabBar", "unnamed": 1, "visible": True}
switchTabBar_Enter_sync_code_StatusSwitchTabButton = {"checkable": True, "container": mainWindow_switchTabBar_StatusSwitchTabBar_2, "objectName": "secondTab_StatusSwitchTabButton", "type": "StatusSwitchTabButton", "visible": True}
mainWindow_statusBaseInput_StatusBaseInput = {"container": statusDesktop_mainWindow, "id": "statusBaseInput", "type": "StatusBaseInput", "unnamed": 1, "visible": True}
mainWindow_Paste_StatusButton = {"container": statusDesktop_mainWindow, "objectName": "syncCodePasteButton", "type": "StatusButton", "visible": True}
mainWindow_syncingEnterCode_SyncingEnterCode = {"container": statusDesktop_mainWindow, "objectName": "syncingEnterCode", "type": "SyncingEnterCode", "visible": True}
mainWindow_nameInput_syncingEnterCode_Continue = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "continue_StatusButton", "type": "StatusButton", "visible": True}
syncCodeInput = {"container": statusDesktop_mainWindow, "objectName": "syncCodeInput", "type": "StatusSyncCodeInput", "visible": True}
syncCodeErrorMessage = {"container": statusDesktop_mainWindow, "id": "errorMessage", "type": "StatusBaseText", "unnamed": 1, "visible": True}

# SyncDevice View
mainWindow_SyncingDeviceView_found = {"container": statusDesktop_mainWindow, "type": "SyncingDeviceView", "unnamed": 1, "visible": True}
mainWindow_SyncingDeviceView_synced = {"container": statusDesktop_mainWindow, "type": "SyncingDeviceView", "unnamed": 1, "visible": True}
mainWindow_SyncDeviceResult = {"container": statusDesktop_mainWindow, "type": "SyncDeviceResult", "unnamed": 1, "visible": True}
synced_StatusBaseText = {"container": statusDesktop_mainWindow, "type": "StatusBaseText", "unnamed": 1, "visible": True}
doneButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "syncAnewDeviceNextButton", "type": "StatusButton", "visible": True}
mainWindow_Sign_in_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "text": "Sign in", "type": "StatusButton", "unnamed": 1, "visible": True}
sync_text_item = {"container": statusDesktop_mainWindow, "type": "StatusBaseText", "unnamed": 1, "visible": True}

# Keycard Init View
mainWindow_KeycardInitView = {"container": statusDesktop_mainWindow, "type": "KeycardInitView", "unnamed": 1,
                              "visible": True}
mainWindow_Plug_in_Keycard_reader_StatusBaseText = {"container": mainWindow_KeycardInitView, "type": "StatusBaseText",
                                                    "unnamed": 1, "visible": True}

# Your Profile View
mainWindow_InsertDetailsView = {"container": statusDesktop_mainWindow, "objectName": "onboardingInsertDetailsView", "type": "InsertDetailsView", "visible": True}
updatePicButton_StatusRoundButton = {"container": mainWindow_InsertDetailsView, "id": "updatePicButton", "type": "StatusRoundButton", "unnamed": 1, "visible": True}
mainWindow_statusRoundImage_StatusRoundedImage = {"container": statusDesktop_mainWindow, "objectName": "statusRoundImage", "type": "StatusRoundedImage", "visible": True}
mainWindow_IdenticonRing = {"container": statusDesktop_mainWindow, "type": "StatusIdenticonRing", "unnamed": 1, "visible": True}
mainWindow_Next_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "onboardingDetailsViewNextButton", "type": "StatusButton", "visible": True}
mainWindow_inputLayout_ColumnLayout = {"container": statusDesktop_mainWindow, "id": "inputLayout", "type": "ColumnLayout", "unnamed": 1, "visible": True}
mainWindow_statusBaseInput_StatusBaseInput = {"container": statusDesktop_mainWindow, "objectName": "onboardingDisplayNameInput", "type": "TextEdit"}
mainWindow_errorMessage_StatusBaseText = {"container": mainWindow_inputLayout_ColumnLayout, "type": "StatusBaseText", "unnamed": 1, "visible": True}
mainWindow_nameInput_StatusInput = {"container": statusDesktop_mainWindow, "id": "nameInput", "type": "StatusInput", "unnamed": 1, "visible": True}
mainWindow_clear_icon_StatusIcon = {"container": statusDesktop_mainWindow, "objectName": "clear-icon", "type": "StatusIcon"}

# Your emojihash and identicon ring
mainWindow_welcomeScreenUserProfileImage_StatusSmartIdenticon = {"container": mainWindow_InsertDetailsView, "objectName": "welcomeScreenUserProfileImage", "type": "StatusSmartIdenticon", "visible": True}
mainWindow_insertDetailsViewChatKeyTxt_StyledText = {"container": statusDesktop_mainWindow, "objectName": "profileChatKeyViewChatKeyTxt", "type": "StyledText", "visible": True}
mainWindow_EmojiHash = {"container": statusDesktop_mainWindow, "objectName": "publicKeyEmojiHash", "type": "EmojiHash", "visible": True}
mainWindow_Header_Title = {"container": statusDesktop_mainWindow, "objectName": "onboardingHeaderText", "type": "StyledText", "visible": True}
mainWindow_userImageCopy_StatusSmartIdenticon = {"container": statusDesktop_mainWindow, "id": "userImageCopy", "type": "StatusSmartIdenticon", "unnamed": 1, "visible": True}
profileImageCropper = {"container": statusDesktop_mainWindow, "objectName": "imageCropWorkflow", "type": "ImageCropWorkflow", "visible": True}

# Create Password View
mainWindow_CreatePasswordPage = {"container": onboardingLayout, "type": "CreatePasswordPage", "unnamed": 1, "visible": True}
createPasswordView = {"container": mainWindow_CreatePasswordPage, "id": "passView", "type": "PasswordView", "unnamed": 1, "visible": True}
choosePasswordField = {"container": createPasswordView, "objectName": "passwordViewNewPassword", "type": "StatusPasswordInput", "visible": True}
repeatPasswordField = {"container": createPasswordView, "objectName": "passwordViewNewPasswordConfirm", "type": "StatusPasswordInput", "visible": True}
confirmPasswordButton = {"container": mainWindow_CreatePasswordPage, "objectName": "btnConfirmPassword", "type": "StatusButton", "visible": True}
passwordStrengthIndicator = {"container": createPasswordView, "type": "StatusPasswordStrengthIndicator", "unnamed": 1, "visible": True}
passwordComponentIndicator = {"container": createPasswordView, "type": "PasswordComponentIndicator", "unnamed": 1, "visible": True}

mainWindow_CreatePasswordView = {"container": statusDesktop_mainWindow, "type": "CreatePasswordView", "unnamed": 1, "visible": True}
mainWindow_passwordViewNewPassword = {"container": mainWindow_CreatePasswordView, "objectName": "passwordViewNewPassword", "type": "StatusPasswordInput", "visible": True}
mainWindow_passwordViewNewPasswordConfirm = {"container": mainWindow_CreatePasswordView, "objectName": "passwordViewNewPasswordConfirm", "type": "StatusPasswordInput", "visible": True}


mainWindow_Create_password_StatusButton = {"checkable": False, "container": mainWindow_CreatePasswordView, "objectName": "onboardingCreatePasswordButton", "type": "StatusButton", "visible": True}
mainWindow_view_PasswordView = {"container": statusDesktop_mainWindow, "id": "passView", "type": "PasswordView", "unnamed": 1, "visible": True}
mainWindow_RowLayout = {"container": statusDesktop_mainWindow, "type": "PassIncludesIndicator", "unnamed": 1, "visible": True}
mainWindow_ComponentIndicator = {"container": statusDesktop_mainWindow, "type": "PasswordComponentIndicator", "unnamed": 1, "visible": True}
mainWindow_strengthInditactor_StatusPasswordStrengthIndicator = {"container": mainWindow_CreatePasswordView, "type": "StatusPasswordStrengthIndicator", "unnamed": 1, "visible": True}
mainWindow_show_icon_StatusIcon = {"container": statusDesktop_mainWindow, "objectName": "show-icon", "type": "StatusIcon", "visible": True}
mainWindow_hide_icon_StatusIcon = {"container": statusDesktop_mainWindow, "objectName": "hide-icon", "type": "StatusIcon", "visible": True}

# Confirm Password View
mainWindow_ConfirmPasswordView = {"container": statusDesktop_mainWindow, "type": "ConfirmPasswordView", "unnamed": 1,"visible": True}
mainWindow_confirmAgainPasswordInput = {"container": mainWindow_ConfirmPasswordView, "objectName": "confirmAgainPasswordInput", "type": "StatusPasswordInput", "visible": True}
mainWindow_Finalise_Status_Password_Creation_StatusButton = {"checkable": False, "container": mainWindow_ConfirmPasswordView, "objectName": "confirmPswSubmitBtn", "type": "StatusButton", "visible": True}
mainWindow_passwordView_PasswordConfirmationView = {"container": statusDesktop_mainWindow, "id": "passwordView", "type": "PasswordConfirmationView", "unnamed": 1, "visible": True}

# Login View
mainWindow_LoginView = {"container": statusDesktop_mainWindow, "id": "loginScreen", "type": "LoginScreen", "unnamed": 1, "visible": True}
loginView_submitBtn = {"container": mainWindow_LoginView, "type": "StatusRoundButton", "visible": True}
loginView_passwordInput = {"container": mainWindow_LoginView, "objectName": "loginPasswordInput", "type": "StatusTextField"}
loginView_currentUserNameLabel = {"container": mainWindow_LoginView, "objectName": "currentUserNameLabel", "type": "StatusBaseText"}
loginView_changeAccountBtn = {"container": mainWindow_LoginView, "objectName": "loginChangeAccountButton", "type": "StatusFlatRoundButton"}
accountsView_accountListPanel = {"container": statusDesktop_mainWindow, "objectName": "LoginView_AccountsRepeater", "type": "Repeater", "visible": True}
mainWindow_txtPassword_Input = {"container": statusDesktop_mainWindow, "type": "StatusBaseText", "unnamed": 1, "visible": True}
loginView_addNewUserItem_AccountMenuItemPanel = {"container": statusDesktop_mainWindow_overlay, "index": 0, "objectName": "LoginView_addNewUserItem", "type": "AccountMenuItemPanel", "visible": True}
loginView_addExistingUserItem_AccountMenuItemPanel = {"container": statusDesktop_mainWindow_overlay, "objectName": "LoginView_addExistingUserItem", "type": "AccountMenuItemPanel", "visible": True}
mainWindowUsePasswordInsteadStatusBaseText = {"container": statusDesktop_mainWindow, "text": "Use password instead", "type": "StatusBaseText", "unnamed": 1, "visible": True}
loginView_passwordBox = {"container": statusDesktop_mainWindow, "objectName": "passwordBox", "type": "LoginPasswordBox", "visible": True}

# new Login view
userSelectorButton = {"container": mainWindow_LoginView, "id": "userSelectorButton", "type": "LoginUserSelectorDelegate", "unnamed": 1, "visible": True}
userSelectorPanel = {"container": statusDesktop_mainWindow_overlay, "type": "StatusListView", "unnamed": 1, "visible": True}
loginButton = {"container": mainWindow_LoginView, "objectName": "loginButton", "type": "StatusButton", "visible": True}
userLoginItem = {"container": statusDesktop_mainWindow_overlay, "type": "LoginUserSelectorDelegate", "unnamed": 1, "visible": True}
createProfileButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "createProfileDelegate", "type": "LoginUserSelectorDelegate", "visible": True}
returningLoginButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "logInDelegate", "type": "LoginUserSelectorDelegate", "visible": True}
statusDropdown = {"container": statusDesktop_mainWindow_overlay, "objectName": "StatusDropdown", "type": "PopupItem", "visible": True}
startupLanguageSelector_item = {"container": statusDesktop_mainWindow_overlay, "objectName": RegularExpression("itemDelegate_*"), "type": "ItemDelegate", "visible": True}


# Touch ID Auth View
mainWindow_TouchIDAuthView = {"container": statusDesktop_mainWindow, "type": "TouchIDAuthView", "unnamed": 1, "visible": True}
mainWindow_touchIdYesUseTouchIDButton = {"container": statusDesktop_mainWindow, "objectName": "touchIdYesUseTouchIDButton", "type": "StatusButton", "visible": True}
mainWindow_touchIdIPreferToUseMyPasswordText = {"container": statusDesktop_mainWindow, "objectName": "touchIdIPreferToUseMyPasswordText", "type": "StatusBaseText"}

# Enable biometrics view
enableBiometricsView = {"container": onboardingLayout, "type": "EnableBiometricsPage", "unnamed": 1, "visible": True}
enableBiometricsButton = {"container": enableBiometricsView, "objectName": "btnEnableBiometrics", "type": "StatusButton", "visible": True}
dontEnableBiometricsButton = {"container": enableBiometricsView, "objectName": "btnDontEnableBiometrics", "type": "StatusFlatButton", "visible": True}
