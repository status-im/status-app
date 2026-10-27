import logging
import time

import allure
import object as squish_object

import configs.timeouts
import driver
from helpers.chat_helper import skip_message_backup_popup_if_visible
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.objects_map import names, activity_center_names

LOG = logging.getLogger(__name__)


class ContactRequest:

    def __init__(self, obj):
        self.object = obj
        try:
            title = getattr(obj, 'title', None)
            self.contact_request = str(title).strip() if title not in (None, '') else None
        except Exception:
            self.contact_request = None
        self.accept_button = Button(activity_center_names.notificationCardAcceptButton)
        self.decline_button = Button(activity_center_names.notificationCardDeclineButton)

    def __repr__(self):
        return self.contact_request

    @allure.step('Accept request')
    def accept(self):
        self.accept_button.click()
        self.accept_button.wait_until_hidden()
        skip_message_backup_popup_if_visible()

    @allure.step('Decline request')
    def decline(self):
        self.decline_button.click()
        self.decline_button.wait_until_hidden()


class ActivityCenter(QObject):

    def __init__(self):
        super().__init__(activity_center_names.activityCenterPanel)
        self.activity_center_button = Scroll(names.activityCenterStatusFlatButton)
        self.activity_center_notification_card = QObject(activity_center_names.activityCenterNotificationCard)
        self.scroll = Scroll(activity_center_names.activityCenterScrollView)
        self.navigation_button = Button(activity_center_names.activityCenterNavigationButton)
        self.replies_button = Button(activity_center_names.activityCenterRepliesButton)
        self._close_button = Button(activity_center_names.activityCenterCloseButton)

    @allure.step('Click activity center button')
    def click_activity_center_button(self, text: str):
        started_at = time.monotonic()
        self.activity_center_button.real_name['text'] = text

        while not self.activity_center_button.is_visible:
            if time.monotonic() - started_at > 5:
                raise TimeoutError(f'Activity center button with text "{text}" not found after {5} seconds')
            self.navigation_button.click()
        self.activity_center_button.click()
        return self

    @staticmethod
    def _card_text(card, attr: str) -> str:
        try:
            value = getattr(card, attr, None)
            return str(value).strip() if value not in (None, '') else ''
        except Exception:
            return ''

    @staticmethod
    def _label_matches(actual: str, expected: str) -> bool:
        if not actual:
            return False
        if actual == expected or expected in actual:
            return True
        visible = actual.replace('…', '').replace('...', '').strip()
        return len(visible) >= 4 and (expected.startswith(visible) or visible.startswith(expected))

    @allure.step('Find notification with {attr} {text}')
    def find_notification(
            self, text: str, attr: str = 'title',
            timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        deadline = time.monotonic() + timeout_sec
        while time.monotonic() < deadline:
            for card in driver.findAllObjects(self.activity_center_notification_card.real_name):
                if self._label_matches(self._card_text(card, attr), text):
                    return card
            time.sleep(0.25)
        raise TimeoutError(f'Notification with {attr} {text!r} not found')

    @allure.step('Find contact request')
    def find_contact_request_in_list(
            self, contact: str, timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        return ContactRequest(self.find_notification(contact, 'title', timeout_sec))

    @allure.step('Open notification card from activity center')
    def open_notification_card(self, card):
        self._scroll_notification_into_view(card)
        driver.mouseClick(card)
        return self

    @allure.step('Close activity center')
    def close(self):
        LOG.info('Closing activity center')
        self._close_button.click()
        return self

    @allure.step('Wait until activity center is fully open')
    def _scroll_notification_into_view(self, card_ref) -> None:
        """ListView may clip the row; clicks outside the viewport often do nothing."""
        try:
            slide = driver.waitForObject(
                activity_center_names.activityCenterSlideContainer,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            )
            driver.waitFor(lambda: slide._fullyOpen, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            list_obj = driver.waitForObject(
                activity_center_names.activityCenterListView,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            )
            lrect = squish_object.globalBounds(list_obj)
        except Exception as e:
            LOG.info('_scroll_notification_into_view: skip (%s)', e)
            return
        lx = int(lrect.x + max(1, lrect.width / 2))
        ly = int(lrect.y + max(1, lrect.height / 2))
        margin = 24
        top, bot = lrect.y + margin, lrect.y + lrect.height - margin
        for _ in range(28):
            try:
                crect = squish_object.globalBounds(card_ref)
            except Exception:
                return
            cy = crect.y + crect.height / 2
            if top <= cy <= bot:
                return
            dy = -35 if cy > bot else 35
            try:
                driver.mouse.scroll(list_obj, lx, ly, 0, dy, 1, 0.08)
            except Exception as ex:
                LOG.info('_scroll_notification_into_view: scroll failed %s', ex)
                return
            time.sleep(0.05)
        LOG.info('_scroll_notification_into_view: gave up after scroll attempts')

    @allure.step('Accept contact request')
    def accept_contact_request(self, request):
        self._scroll_notification_into_view(request.object)
        request.accept()
        self.close()
        LOG.info('ActivityCenter: accept_contact_request finished')
        return self
