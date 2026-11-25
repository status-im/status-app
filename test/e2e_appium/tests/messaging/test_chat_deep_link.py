import pytest

from locators.base_locators import BaseLocators
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.messaging.group_chat_page import GroupChatPage
from support.platform import is_android
from support.screen_identity import dismiss_introduce_yourself

PORTRAIT_LAYOUT = BaseLocators.xpath(
    "//android.widget.TabWidget[contains(@resource-id, '.StatusSectionLayoutPortrait_')]"
)


@pytest.mark.messaging
@pytest.mark.backend_peer
@pytest.mark.portrait
@pytest.mark.device_count(1)
@pytest.mark.timeout(1200)
def test_one_to_one_chat_link_opens_conversation(peer_chat):
    device, peer = peer_chat.device, peer_chat.peer
    driver = device.driver
    if not is_android(driver):
        pytest.skip("Uses the Android Appium deep-link command")

    chat_page = ChatPage(driver)
    assert App(driver).click_messages_button(), "Messages did not open"
    assert chat_page.is_loaded(), "The Messages list is not visible"
    if not chat_page.is_element_visible(PORTRAIT_LAYOUT, timeout=5):
        pytest.skip("Requires the portrait Messages layout")

    assert not chat_page.wait_for_message_input(timeout=2), "A conversation is already open"

    driver.execute_script(
        "mobile: deepLink",
        {
            "url": f"status-app://p/{peer.public_key}",
            "package": driver.capabilities.get("appPackage") or "app.status.mobile",
        },
    )

    chat_page.dismiss_backup_prompt(timeout=4)
    dismiss_introduce_yourself(chat_page, timeout=1)
    assert chat_page.wait_for_message_input(timeout=10), (
        "The chat link did not open a conversation with a message input"
    )
    assert chat_page.is_element_visible(chat_page.locators.TOOLBAR_BACK_BUTTON, timeout=5), (
        "The conversation did not open in the portrait Messages layout"
    )
    header = GroupChatPage(driver).get_group_name_from_header(timeout=15) or ""
    assert any(name and name in header for name in (peer.display_name, peer.alias)), (
        f"The chat link opened {header!r} instead of the peer's conversation"
    )
