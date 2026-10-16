from locators.base_locators import BaseLocators


def _ends_with(name: str) -> str:
    return (
        f"substring(@resource-id, string-length(@resource-id) - {len(name)}) = '.{name}'"
        f" or @resource-id='{name}'"
    )


class ShareLocators(BaseLocators):
    """The picker that opens when another app shares to Status.

    QML: ui/app/mainui/sectionLoaders/ShareFlowLoader.qml and
    ui/app/mainui/panels/ShareDestination*.qml. objectName maps to
    resource-id on Android.
    """

    PICKER = BaseLocators.tid("shareFlowPicker")
    CANCEL_BUTTON = BaseLocators.tid("shareDestinationPickerCancelButton")
    SEARCH_TOGGLE = BaseLocators.tid("shareDestinationPickerSearchToggle")
    TAB_BAR = BaseLocators.tid("shareDestinationPickerTabBar")
    COMPOSER = BaseLocators.tid("shareDestinationPickerComposer")
    SELECTED_TOGGLE = BaseLocators.tid("shareDestinationPickerSelectedToggle")
    TAB_ALL = BaseLocators.tid("shareTabAll")
    TAB_CONTACTS = BaseLocators.tid("shareTabContacts")
    TAB_GROUPS = BaseLocators.tid("shareTabGroups")
    TAB_COMMUNITIES = BaseLocators.tid("shareTabCommunities")
    EMPTY_TEXT = BaseLocators.tid("shareDestinationListEmptyText")

    # The composer is the chat input; scoped to the picker so an open chat
    # behind it is never matched.
    COMPOSER_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'shareFlowPicker')]"
        "//*[contains(@resource-id,'messageInputField')]"
    )
    SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'shareFlowPicker')]"
        f"//*[{_ends_with('statusChatInputSendButton')}]"
    )

    BROWSER_ADDRESS_FIELD = BaseLocators.resource_id_contains("BrowserAddressField")

    @staticmethod
    def destination_row(chat_id: str) -> tuple:
        return BaseLocators.xpath(f"//*[{_ends_with('shareDestinationDelegate_' + chat_id)}]")

    @staticmethod
    def destination_checkbox(chat_id: str) -> tuple:
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'shareDestinationDelegate_{chat_id}')"
            " and contains(@resource-id,'shareDestinationCheckBox')]"
        )
