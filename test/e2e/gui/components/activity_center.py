import logging
import time
import typing

import allure
import object as squish_object
import squish

import configs.timeouts
import driver
from driver.objects_access import (
    describe_button_for_log,
    find_notification_button_on_card,
    item_is_visible,
)
from helpers.chat_helper import skip_message_backup_popup_if_visible
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.objects_map import names, activity_center_names

LOG = logging.getLogger(__name__)

class ContactRequest:

    def __init__(self, obj):
        self.object = obj
        self.contact_request: typing.Optional[str] = None
        self.header: typing.Optional[QObject] = None
        self.accept_button: typing.Optional[Button] = None
        self.decline_button: typing.Optional[Button] = None
        self.init_ui()

    def __repr__(self):
        return self.contact_request

    def init_ui(self):
        title = None
        try:
            title = getattr(self.object, 'title', None)
            self.contact_request = str(title).strip() if title not in (None, '') else None
        except Exception:
            self.contact_request = None
        LOG.info('ContactRequest init: title=%r -> contact_request=%r', title, self.contact_request)

        self.header = QObject(activity_center_names.notificationCardHeader)
        self.accept_button = Button(activity_center_names.notificationCardAcceptButton)
        self.decline_button = Button(activity_center_names.notificationCardDeclineButton)


    @allure.step('Accept request')
    def accept(self):
        time.sleep(1)
        self.accept_button.click()
        assert not self.accept_button.is_visible
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
        self._close_button = Button(activity_center_names.activityCenterCloseButton)

    @property
    @allure.step('Get contact items')
    def contact_items(self) -> typing.List[ContactRequest]:
        return [ContactRequest(item) for item in driver.findAllObjects(self.activity_center_notification_card.real_name)]

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

    @allure.step('Find contact request')
    def find_contact_request_in_list(
            self, contact: str, timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        started_at = time.monotonic()
        last_log_at = started_at
        while time.monotonic() - started_at < timeout_sec:
            requests = self.contact_items
            for _request in requests:
                if _request.contact_request == contact:
                    LOG.info('find_contact_request_in_list: matched %r', contact)
                    return _request
            now = time.monotonic()
            if now - last_log_at >= 5.0:
                last_log_at = now
                titles = [r.contact_request for r in requests]
                LOG.info(
                    'find_contact_request_in_list: still waiting for %r (%d cards: %s)',
                    contact,
                    len(requests),
                    titles,
                )
        raise TimeoutError(f'Timed out after {timeout_sec} seconds: Contact request "{contact}" not found.')

    @allure.step('Close activity center')
    def close(self):
        LOG.info('Closing activity center')
        self._close_button.click()
        return self

    def _scroll_notification_into_view(self, card_ref) -> None:
        """ListView may clip the row; clicks outside the viewport often do nothing."""
        try:
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
