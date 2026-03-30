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

_QUICK_ACTIONS_DISMISS_MS = 25_000

# NotificationCard.qml — waitForObject({container: cardRef, objectName: ...}) is unreliable in Squish; use tree walk.
_ACCEPT_OBJECT_NAME = 'notificationAcceptBtn'
_DECLINE_OBJECT_NAME = 'notificationDeclineBtn'


def _click_qml_item_center(item) -> None:
    """Prefer screen-space click: item-relative coords often miss on nested/transformed QML."""
    try:
        b = squish_object.globalBounds(item)
    except (RuntimeError, LookupError, AttributeError):
        b = None
    if b is not None and b.width > 0 and b.height > 0:
        cx = int(b.x + b.width / 2)
        cy = int(b.y + b.height / 2)
        time.sleep(0.03)
        driver.nativeMouseClick(cx, cy, driver.MouseButton.LeftButton)
        return
    try:
        w = int(getattr(item, 'width', 0) or 0)
        h = int(getattr(item, 'height', 0) or 0)
    except (RuntimeError, TypeError, ValueError, AttributeError):
        w, h = 0, 0
    if w > 0 and h > 0:
        x = max(1, int(w * 0.5))
        y = max(1, int(h * 0.5))
        try:
            squish.mouseMove(item, x, y)
        except (RuntimeError, LookupError, AttributeError):
            pass
        driver.mouseClick(item, x, y, driver.Qt.LeftButton)
        return
    driver.mouseClick(item)


class ContactRequest:

    def __init__(self, obj):
        self.object = obj
        self.contact_request: typing.Optional[str] = None
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

    def _contact_quick_actions_still_showing(self) -> bool:
        try:
            if hasattr(self.object, 'actionId'):
                return bool(getattr(self.object, 'actionId'))
        except (RuntimeError, AttributeError, LookupError):
            pass
        for oname in (_ACCEPT_OBJECT_NAME, _DECLINE_OBJECT_NAME):
            btn = find_notification_button_on_card(self.object, oname)
            if btn is not None and item_is_visible(btn):
                return True
        return False

    def _wait_until_quick_actions_hidden(self, action_label: str) -> None:
        def _gone() -> bool:
            # NotificationCard: actionId → empty when request is no longer pending (see NotificationAdaptorContactRequest)
            try:
                if hasattr(self.object, 'actionId') and not bool(getattr(self.object, 'actionId')):
                    return True
            except (RuntimeError, AttributeError, LookupError):
                pass
            for oname in (_ACCEPT_OBJECT_NAME, _DECLINE_OBJECT_NAME):
                btn = find_notification_button_on_card(self.object, oname)
                if btn is not None and item_is_visible(btn):
                    return False
            return True

        LOG.info('Waiting until quick actions hidden after %s', action_label)
        ok = driver.waitFor(_gone, _QUICK_ACTIONS_DISMISS_MS)
        assert ok, (
            f'{action_label} had no effect: Accept/Decline are still visible after {_QUICK_ACTIONS_DISMISS_MS} ms'
        )
        LOG.info('Quick actions hidden after %s', action_label)

    def _click_notification_button(self, object_name: str, label: str) -> None:
        deadline = time.monotonic() + configs.timeouts.MESSAGING_TIMEOUT_SEC
        last_progress_log = 0.0
        while time.monotonic() < deadline:
            btn = find_notification_button_on_card(self.object, object_name)
            if btn is not None and item_is_visible(btn) and bool(getattr(btn, 'enabled', True)):
                for attempt in range(1, 7):
                    LOG.info(
                        'ActivityCenter: %s — attempt %s on %s',
                        label,
                        attempt,
                        describe_button_for_log(btn),
                    )
                    if attempt <= 4:
                        _click_qml_item_center(btn)
                    else:
                        try:
                            Button({'container': self.object, 'objectName': object_name}).click()
                        except Exception as ex:
                            LOG.info('Button(container=card).click fallback failed: %s', ex)
                            _click_qml_item_center(btn)
                    time.sleep(0.4)
                    if not self._contact_quick_actions_still_showing():
                        return
                    btn = find_notification_button_on_card(self.object, object_name)
                    if btn is None or not item_is_visible(btn) or not bool(getattr(btn, 'enabled', True)):
                        return
                return
            now = time.monotonic()
            if now - last_progress_log >= 2.0:
                last_progress_log = now
                vis = item_is_visible(btn) if btn is not None else None
                LOG.info(
                    'Waiting for %s objectName=%r (btn=%s item_is_visible=%s)',
                    label,
                    object_name,
                    'present' if btn is not None else 'absent',
                    vis,
                )
            time.sleep(0.25)
        raise AssertionError(
            f'{label}: no visible enabled descendant objectName={object_name!r} under notification card within '
            f'{configs.timeouts.MESSAGING_TIMEOUT_SEC}s'
        )

    @allure.step('Accept request')
    def accept(self):
        self._click_notification_button(_ACCEPT_OBJECT_NAME, 'Accept button')
        skip_message_backup_popup_if_visible()
        self._wait_until_quick_actions_hidden('Accept contact request')

    @allure.step('Decline request')
    def decline(self):
        self._click_notification_button(_DECLINE_OBJECT_NAME, 'Decline button')
        self._wait_until_quick_actions_hidden('Decline contact request')


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

    # TODO: navigation buttons are the same so its hard to click a certain button

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
