from ..base_locators import BaseLocators, object_name_pred


class ReturningLoginLocators(BaseLocators):

    # Returning Login ("Welcome back") user selector button
    LOGIN_USER_SELECTOR_FULL_ID = BaseLocators.xpath(
        "//*[(@resource-id='QGuiApplication.mainWindow.startupOnboardingLayout.OnboardingFlow_QMLTYPE_165.LoginScreen_QMLTYPE_364.loginUserSelector.LoginUserSelectorDelegate_QMLTYPE_370' or @name='QGuiApplication.mainWindow.startupOnboardingLayout.OnboardingFlow_QMLTYPE_165.LoginScreen_QMLTYPE_364.loginUserSelector.LoginUserSelectorDelegate_QMLTYPE_370')]"
    )
    LOGIN_USER_SELECTOR = BaseLocators.xpath(
        f"//*[{object_name_pred('loginUserSelector')} or {object_name_pred('LoginUserSelector')}]"
    )

    # Dropdown item to proceed with login
    LOGIN_DROPDOWN_ITEM = BaseLocators.xpath(
        f"//*[{object_name_pred('StatusDropdown.logInDelegate')} or {object_name_pred('logInDelegate')}]"
    )

    CREATE_PROFILE_DROPDOWN_ITEM = BaseLocators.xpath(
        f"//*[{object_name_pred('StatusDropdown.createProfileDelegate')} or {object_name_pred('createProfileDelegate')}]"
    )

    # Text fallback for the Create profile item
    CREATE_PROFILE_TEXT = BaseLocators.text_contains("Create profile")
