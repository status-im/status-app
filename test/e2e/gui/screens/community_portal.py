import logging
import time

import allure

import driver
from gui.components.community.create_community_popups import CreateNewCommunityPopup
from gui.components.community.import_community_popup import ImportCommunityPopup
from gui.components.community.welcome_community import WelcomeCommunityPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import communities_names
from helpers.chat_helper import skip_message_backup_popup_if_visible
from objectmaphelper import RegularExpression

LOG = logging.getLogger(__name__)


class CommunitiesPortal(QObject):

    DISCOVER_CARD_TIMEOUT_MSEC = 120000

    def __init__(self):
        super().__init__(communities_names.communityPortal)
        self.create_new_community_button = Button(communities_names.communityPortal_CreateCommunityButton)
        self.join_community_button = Button(communities_names.communityPortal_JoinCommunityButton)
        self.searcher = TextEdit(communities_names.communityPortal_searcher)
        self.discover_community_card = Button(communities_names.communityPortal_communityCard)

    @allure.step('Open discover community card {name}')
    def open_discover_community(
        self,
        name: str,
        timeout_msec: int = DISCOVER_CARD_TIMEOUT_MSEC,
    ) -> 'CommunitiesPortal':
        self.searcher.wait_until_appears(timeout_msec)
        self._clear_search()
        self._wait_for_loaded_community_card(name, timeout_msec)
        self.searcher.set_text_property(name)
        self.discover_community_card.real_name = dict(communities_names.communityPortal_communityCard)
        self.discover_community_card.real_name['objectName'] = RegularExpression(f'communityCard-{name}*')
        try:
            self.discover_community_card.wait_until_appears(timeout_msec)
        except TimeoutError as error:
            visible = self._community_card_debug()
            raise TimeoutError(
                f'Community card {name!r} is not visible within {timeout_msec} ms; '
                f'visible cards: {visible}'
            ) from error
        self.discover_community_card.click()
        return self

    def _clear_search(self) -> None:
        """Typing a previous community name leaves Discover filtered to that card."""
        try:
            current = self.searcher.text
        except Exception:
            current = ''
        if not current:
            return
        LOG.info('Clearing Discover search %r so catalog cards can appear', current)
        self.searcher.clear()

    def _wait_for_loaded_community_card(self, name: str, timeout_msec: int) -> None:
        """Catalog cards arrive as nameless skeletons; wait until this name is loaded."""
        deadline = time.time() + timeout_msec / 1000
        last_log = 0.0
        while time.time() < deadline:
            debug = self._community_card_debug()
            now = time.time()
            if now - last_log >= 10:
                LOG.info('Discover cards while waiting for %s: %s', name, debug)
                last_log = now
            if any(self._is_loaded_named_card(row, name) for row in debug):
                return
            time.sleep(0.5)
        raise TimeoutError(
            f'Community card {name!r} did not finish loading within {timeout_msec} ms; '
            f'visible cards: {self._community_card_debug()}'
        )

    @staticmethod
    def _is_loaded_named_card(row: str, name: str) -> bool:
        lowered = row.lower()
        return (
            lowered.startswith(f'communitycard-{name.lower()}')
            and 'loaded=true' in lowered
        )

    def _community_card_debug(self) -> list[str]:
        locator = dict(communities_names.communityPortal_communityCard)
        locator['objectName'] = RegularExpression('communityCard-*')
        try:
            rows = []
            for obj in driver.findAllObjects(locator):
                object_name = str(getattr(obj, 'objectName', ''))
                loaded = getattr(obj, 'loaded', '?')
                rows.append(f'{object_name} loaded={loaded}')
            return sorted(rows)
        except Exception:
            return []

    def _visible_community_card_names(self) -> list[str]:
        return [row.split(' loaded=', 1)[0] for row in self._community_card_debug()]

    @allure.step('Dismiss community join dialog if it is visible')
    def dismiss_join_dialog_if_visible(self, timeout_msec: int = 5000) -> None:
        dialog = WelcomeCommunityPopup()
        driver.waitFor(lambda: dialog.exists, timeout_msec)
        if not dialog.exists:
            return
        try:
            dialog.close()
        except Exception:
            pass

    @allure.step('Open create community popup')
    def open_create_community_popup(self) -> CreateNewCommunityPopup:
        for i in range(2):
            self.create_new_community_button.click()
            time.sleep(0.1)
            try:
                return CreateNewCommunityPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Create Communities banner is not displayed')

    @allure.step('Open import community popup')
    def open_import_community_popup(self) -> ImportCommunityPopup:
        for i in range(2):
            self.join_community_button.click()
            time.sleep(0.1)
            try:
                return ImportCommunityPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Create Communities banner is not displayed')
