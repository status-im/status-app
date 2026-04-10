import time
import typing

import allure
from allure_commons._allure import step

import configs
import driver
from constants import CommunityChannel
from driver.objects_access import walk_children
from gui.components.community.community_category_popup import NewCategoryPopup
from gui.components.community.community_channel_popups import EditChannelPopup, NewChannelPopup
from gui.components.community.invite_contacts import InviteContactsPopup
from gui.components.community.welcome_community import WelcomeCommunityPopup
from gui.components.context_menu import ContextMenu
from gui.components.delete_popup import ConfirmationPopup
from gui.components.messaging.chat_context_menu import ChatContextMenu
from gui.components.profile_popup import ProfilePopupFromMembers
from gui.elements.button import Button
from gui.elements.list import List
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_label import TextLabel
from gui.objects_map import names, communities_names, messaging_names
from gui.screens.community_settings import CommunitySettingsScreen
from scripts.tools.image import Image
from scripts.utils.parsers import remove_tags


class CommunityScreen(QObject):

    def __init__(self):
        super().__init__(communities_names.mainWindow_communityLoader_Loader)
        self.left_panel = CommunityLeftPanel()
        self.tool_bar = CommunityToolBar()
        self.chat = ChatView()
        self.right_panel = MembersListPanel()

    @allure.step('Create channel')
    def create_channel(self, name: str, description: str, emoji: str = None):
        self.left_panel.open_create_channel_popup().create(name, description, emoji).save_create_button.click()

    @allure.step('Edit channel')
    def edit_channel(self, channel, name: str, description: str, emoji: str = None):
        self.left_panel.select_channel(channel)
        self.tool_bar.open_edit_channel_popup().edit(name, description, emoji)

    @allure.step('Delete channel')
    def delete_channel(self, name: str):
        self.left_panel.select_channel(name)
        confirmation_dialog = self.tool_bar.open_delete_channel_popup()
        confirmation_dialog.delete_button.click()
        confirmation_dialog.wait_until_hidden()

    @allure.step('Verify channel')
    def verify_channel(
            self, name: str, description: str, emoji):
        with step('Channel is correct in channels list'):
            channel = self.left_panel.get_channel_parameters(name)
            assert channel.name == name

        with step('Channel is correct in community toolbar'):
            assert self.tool_bar.channel_name == name
            assert self.tool_bar.channel_description == description
            if emoji is not None:
                assert self.tool_bar.channel_emoji == emoji

        with step('Verify channel in chat'):
            assert self.chat.channel_name == name
            if emoji is not None:
                assert self.chat.channel_emoji == emoji

    @allure.step('Create category')
    def create_category(self, name: str, general_checkbox: bool):
        self.left_panel.open_create_category_popup().create(name, general_checkbox)

    @allure.step('Delete category from the list')
    def delete_category(self):
        context_menu = self.left_panel.open_more_options()
        delete_pop_up = context_menu.open_delete_category_popup()
        delete_pop_up.confirm_button.click()
        return self

    @allure.step('Edit category')
    def edit_category(self):
        context_menu = self.left_panel.open_more_options()
        edit_popup = context_menu.open_edit_category_popup()
        return edit_popup

    @allure.step('Verify category in the list')
    def verify_category(self, category_name: str):
        category = self.left_panel.find_category_in_list(category_name)
        assert category.category_name == category_name


class BannedCommunityScreen(QObject):
    def __init__(self):
        super().__init__(communities_names.mainWindow_communityLoader_Loader)
        self.community_header_button = Button(communities_names.mainWindow_communityHeaderButton_StatusChatInfoButton)
        self.community_start_chat_button = Button(messaging_names.mainWindow_startChatButton_StatusIconTabButton)
        self.community_banned_member_panel = QObject(communities_names.mainWindow_CommunityBannedMemberPanel)
        self.community_banned_member_panel_user_info = QObject(
            communities_names.mainWindow_CommunityBannedMemberPanel_UserInfo)

    def banned_title(self):
        for child in walk_children(self.community_banned_member_panel_user_info.object):
            if str(getattr(child, 'objectName', '')) == 'userInfoPanelBaseText':
                return remove_tags(str(child.text))


class CommunityToolBar(QObject):

    def __init__(self):
        super().__init__(communities_names.mainWindow_statusToolBar_StatusToolBar)
        self._more_options_button = Button(communities_names.statusToolBar_chatToolbarMoreOptionsButton)
        self._options_list = List(names.o_StatusListView)
        self._edit_channel_context_item = QObject(communities_names.edit_Channel_StatusMenuItem)
        self._channel_icon = QObject(communities_names.statusToolBar_statusSmartIdenticonLetter_StatusLetterIdenticon)
        self._channel_name = TextLabel(
            communities_names.statusToolBar_statusChatInfoButtonNameText_TruncatedTextWithTooltip)
        self._channel_description = TextLabel(communities_names.statusToolBar_TruncatedTextWithTooltip)
        self._delete_channel_context_item = QObject(communities_names.delete_or_leave_Channel_StatusMenuItem)
        self._channel_header = QObject(communities_names.statusToolBar_chatInfoBtnInHeader_StatusChatInfoButton)

    @property
    @allure.step('Get channel emoji')
    def channel_emoji(self):
        return self._channel_header.object.asset.emoji

    @property
    @allure.step('Get channel color')
    def channel_color(self) -> str:
        return str(self._channel_header.object.asset.color.name).lower()

    @property
    @allure.step('Get channel name')
    def channel_name(self) -> str:
        return self._channel_name.text

    @property
    @allure.step('Get channel description')
    def channel_description(self) -> str:
        return self._channel_description.text

    @allure.step('Open edit channel popup')
    def open_edit_channel_popup(self):
        self.open_more_options_dropdown()
        self._edit_channel_context_item.click()
        return EditChannelPopup().wait_until_appears()

    @allure.step('Open delete channel popup')
    def open_delete_channel_popup(self):
        self.open_more_options_dropdown().delete_channel_context_item.click()
        return ConfirmationPopup().wait_until_appears()

    @allure.step('Open more options dropdown')
    def open_more_options_dropdown(self, attempts: int = 2):
        for _ in range(attempts):
            try:
                self._more_options_button.click()
                return ChatContextMenu().wait_until_appears()
            except Exception:
                pass  # Retry one more time
        raise LookupError(f'Could not open context menu for a channel')


class CategoryItem():

    def __init__(self, obj):
        self.object = obj
        self._category_name: typing.Optional[Image] = None
        self._add_category_button: typing.Optional[Button] = None
        self._more_button: typing.Optional[Button] = None
        self._arrow_button: typing.Optional[Button] = None
        self._arrow_icon: typing.Optional[QObject] = None
        self.init_ui()

    def __repr__(self):
        return self.category_name

    def init_ui(self):
        for child in walk_children(self.object):
            if str(getattr(child, 'id', '')) == 'statusChatListCategoryItem':
                self.category_name = str(child.text)
            elif str(getattr(child, 'id', '')) == 'addButton':
                self._add_channel_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'id', '')) == 'menuButton':
                self._more_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'id', '')) == 'toggleButton':
                self._arrow_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'objectName', '')) == 'chevron-down-icon':
                self._arrow_icon = QObject(real_name=driver.objectMap.realName(child))

    @allure.step('Click arrow button')
    def click_arrow_button(self):
        self._arrow_button.click()

    @allure.step('Get arrow button rotation value')
    def get_arrow_icon_rotation_value(self) -> int:
        return self._arrow_icon.object.rotation


class CommunityLeftPanel(QObject):

    def __init__(self):
        super().__init__(communities_names.mainWindow_communityColumnView_CommunityColumnView)
        self._community_info_button = Button(communities_names.mainWindow_communityHeaderButton_StatusChatInfoButton)
        self._community_logo = QObject(communities_names.mainWindow_identicon_StatusSmartIdenticon)
        self._name_text_label = TextLabel(
            communities_names.mainWindow_statusChatInfoButtonNameText_TruncatedTextWithTooltip)
        self._members_text_label = TextLabel(communities_names.mainWindow_Members_TruncatedTextWithTooltip)
        self._general_channel_item = QObject(communities_names.scrollView_general_StatusChatListItem)
        self._add_channels_button = Button(communities_names.add_channels_StatusButton)
        self._channel_icon_template = QObject(communities_names.channel_identicon_StatusSmartIdenticon)
        self._channel_or_category_button = Button(
            communities_names.mainWindow_createChannelOrCategoryBtn_StatusBaseText)
        self._create_channel_menu_item = Button(communities_names.create_channel_StatusMenuItem)
        self._create_category_menu_item = Button(communities_names.create_category_StatusMenuItem)
        self._join_community_button = Button(communities_names.mainWindow_Join_Community_StatusButton)

        self.communityChatListAndCategories = QObject(communities_names.communityChatListAndCategories)
        self.channelAndCategoriesListItems = QObject(communities_names.channelAndCategoriesListItems)
        self.chatListItems = QObject(communities_names.chatListItems)
        self.chatListItemDropAreaItem = QObject(communities_names.chatListItemDropAreaItem)
        self.categoryItemDropAreaItem = QObject(communities_names.categoryListItemDropAreaItem)

        self._category_list_item = QObject(communities_names.categoryItem_StatusChatListCategoryItem)
        self._create_category_button = Button(communities_names.add_categories_StatusFlatButton)
        self._delete_category_item = QObject(communities_names.delete_Category_StatusMenuItem)
        self.edit_category_item = QObject(communities_names.edit_Category_StatusMenuItem)
        self._add_channel_inside_category_item = QObject(
            communities_names.scrollView_addButton_StatusChatListCategoryItemButton)
        self._more_button = Button(communities_names.scrollView_menuButton_StatusChatListCategoryItemButton)
        self._arrow_button = Button(communities_names.scrollView_toggleButton_StatusChatListCategoryItemButton)

        # communities welcome banner panel
        self.add_members_button = Button(communities_names.welcomeBannerAddMembersButton)
        self.manage_community_button = Button(communities_names.welcomeBannerManageCommunityButton)

        self._channels_scroll = Scroll(communities_names.mainWindow_scrollView_StatusScrollView)

    @property
    @allure.step('Get community logo')
    def logo(self) -> Image:
        return self._community_logo.image

    @property
    @allure.step('Get community name')
    def name(self) -> str:
        return self._name_text_label.text

    @property
    @allure.step('Get community members label')
    def members(self) -> str:
        return self._members_text_label.text

    @property
    @allure.step('Get Join button visible attribute')
    def is_join_community_visible(self) -> bool:
        return self._join_community_button.exists

    @property
    @allure.step('Get channels')
    def channels(self) -> typing.List[CommunityChannel]:
        time.sleep(0.5)
        channels_list = []
        for obj in driver.findAllObjects(self.chatListItemDropAreaItem.real_name):
            container = driver.objectMap.realName(obj)
            self._channel_icon_template.real_name['container'] = container
            channels_list.append(CommunityChannel(
                str(obj.objectName),
                obj.item.selected,
                obj.item.visible
            ))
        return channels_list

    @property
    @allure.step('Get categories')
    def categories_items(self) -> typing.List[CategoryItem]:
        return [CategoryItem(item) for item in driver.findAllObjects(self.categoryItemDropAreaItem.real_name)]

    @allure.step('Get arrow button rotation value')
    def get_arrow_icon_rotation_value(self, category_name) -> int:
        category = self.find_category_in_list(category_name)
        return int(category.get_arrow_icon_rotation_value())

    @allure.step('Get channel params')
    def get_channel_parameters(self, name) -> CommunityChannel:
        for channel in self.channels:
            if channel.name == name:
                return channel
        raise LookupError(f'Channel not found in {self.channels}')

    @allure.step('Open community settings')
    def open_community_settings(self):
        self._community_info_button.click()
        return CommunitySettingsScreen().wait_until_appears()

    @allure.step('Open create channel popup')
    def open_create_channel_popup(self) -> NewChannelPopup:
        self._channel_or_category_button.click()
        self._create_channel_menu_item.click()
        return NewChannelPopup()

    @allure.step('Get presence state of create channel or category button')
    def does_create_channel_or_category_button_exist(self) -> bool:
        return self._channel_or_category_button.exists

    @allure.step('Get visibility state of add channels button')
    def is_add_channels_button_visible(self) -> bool:
        return self._add_channels_button.is_visible

    @allure.step('Select channel')
    def select_channel(self, name: str):
        deadline = time.monotonic() + max(15.0, configs.timeouts.UI_LOAD_TIMEOUT_SEC * 3)
        scroll_obj = self._channels_scroll.object
        sx = max(1, int(scroll_obj.width / 2))
        sy = max(1, int(scroll_obj.height / 2))
        last_error: typing.Optional[BaseException] = None

        def _object_name(o) -> str:
            try:
                return str(o.objectName)
            except (AttributeError, RuntimeError):
                return ''

        while time.monotonic() < deadline:
            obj = next(
                (o for o in driver.findAllObjects(self.chatListItemDropAreaItem.real_name)
                 if _object_name(o) == name),
                None,
            )

            if obj is None:
                driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
                continue

            try:
                srect = driver.object.globalBounds(scroll_obj)
                crect = driver.object.globalBounds(obj)
            except (RuntimeError, AttributeError):
                time.sleep(0.1)
                continue

            cy = crect.y + crect.height / 2
            margin = 24
            if not (srect.y + margin <= cy <= srect.y + srect.height - margin):
                driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
                continue

            try:
                driver.mouseClick(obj)
                return obj
            except RuntimeError as e:
                last_error = e
                err = str(e).lower()
                if 'not ready' not in err and 'clipped' not in err:
                    raise
                time.sleep(0.25)

        if last_error is not None:
            raise RuntimeError(
                f'Could not click channel {name!r} after retries') from last_error
        raise LookupError(f'Channel {name!r} not found or did not become clickable')

    @allure.step('Open general channel context menu')
    def open_general_channel_context_menu(self):
        self._general_channel_item.right_click()
        return ContextMenu()

    @allure.step('Open category context menu')
    def open_category_context_menu(self):
        self.categoryItemDropAreaItem.right_click()

    @allure.step('Open create category popup')
    def open_create_category_popup(self, attempts: int = 2) -> NewCategoryPopup:
        self._channel_or_category_button.click()
        try:
            self._create_category_menu_item.click()
            return NewCategoryPopup()
        except Exception as ex:
            if attempts:
                self.open_create_category_popup(attempts - 1)
            else:
                raise ex

    @allure.step('Open join community popup')
    def open_welcome_community_popup(self):
        self._join_community_button.wait_until_appears(timeout_msec=60000)
        self._join_community_button.click()
        return WelcomeCommunityPopup().wait_until_appears()

    @allure.step('Find category')
    def find_category_in_list(
            self, category_name: str):
        time.sleep(1)
        categories = self.categories_items
        for _category in categories:
            if _category.category_name == category_name:
                category = _category
                return category
            raise LookupError(f'Category: {category_name} not found in {categories}')

    def click_category(self, category_name: str):
        driver.mouseClick(self.find_category_in_list(category_name).object)

    @allure.step('Open more options')
    def open_more_options(self):
        self._arrow_button.click()
        self._more_button.click()
        return ContextMenu()

    @allure.step('Open new channel popup inside category')
    def open_new_channel_popup_in_category(self) -> NewChannelPopup:
        self._arrow_button.click()
        self._add_channel_inside_category_item.click()
        return NewChannelPopup().wait_until_appears()

    @allure.step('Get channel or category index in the list')
    def get_channel_or_category_index(self, name: str) -> int:
        for child in walk_children(self.chatListItems.object):
            if child.objectName == name:
                return child.visualIndex

    @allure.step('Right click on left panel')
    def right_click_on_panel(self):
        super(CommunityLeftPanel, self).right_click()

    @allure.step('Open add members popup')
    def open_add_members_popup(self, attempts: int = 2):
        for _ in range(attempts):
            self.add_members_button.click()
            try:
                return InviteContactsPopup().wait_until_appears()
            except Exception:
                pass  # Retry if attempts remain
        raise Exception(f"Failed to open Communities Portal after {attempts} attempts")


class ChatView(QObject):

    def __init__(self):
        super().__init__(communities_names.mainWindow_ChatColumnView)
        self._channel_icon = QObject(
            communities_names.chatMessageViewDelegate_channelIdentifierSmartIdenticon_StatusSmartIdenticon)
        self._channel_name_label = TextLabel(
            communities_names.chatMessageViewDelegate_channelIdentifierNameText_StyledText)
        self._channel_welcome_label = TextLabel(communities_names.chatMessageViewDelegate_Welcome)
        self._channel_identifier_view = QObject(messaging_names.chatMessageViewDelegate_ChannelIdentifierView)

    @property
    @allure.step('Get channel emoji')
    def channel_emoji(self):
        return self._channel_identifier_view.object.chatEmoji

    @property
    @allure.step('Get channel color')
    def channel_color(self) -> str:
        return str(self._channel_identifier_view.object.chatColor).lower()

    @property
    @allure.step('Get channel name')
    def channel_name(self) -> str:
        return self._channel_name_label.text

    @property
    @allure.step('Get channel welcome note')
    def channel_welcome_note(self) -> str:
        return self._channel_welcome_label.text


class MembersListPanel(QObject):

    def __init__(self):
        super().__init__(communities_names.mainWindow_userListPanel_StatusListView)
        self._member_item = QObject(communities_names.userListPanel_StatusMemberListItem)
        self._user_badge_color = QObject(communities_names.statusBadge_StatusBadge)
        self._banned_tab_button = Button(communities_names.membersTabBar_Banned_StatusTabButton)
        self._all_members_tab_button = Button(communities_names.membersTabBar_All_Members_StatusTabButton)

    @property
    @allure.step('Get all members')
    def members(self) -> typing.List[str]:
        return [str(member.userName) for member in driver.findAllObjects(self._member_item.real_name)]

    @allure.step('Open banned tab')
    def click_banned_button(self):
        self._banned_tab_button.click()

    @allure.step('Open all members tab')
    def click_all_members_button(self):
        self._all_members_tab_button.click()

    @allure.step('Click member by name')
    def click_member(self, member_name: str):
        for member in driver.findAllObjects(self._member_item.real_name):
            if getattr(member, 'userName', '') == member_name:
                driver.mouseClick(member)
                break
        return ProfilePopupFromMembers().wait_until_appears()

    @allure.step('Verify member is offline by index')
    def member_state(self, member_name: str) -> bool:
        for member in driver.findAllObjects(self._member_item.real_name):
            if getattr(member, 'userName', '') == member_name:
                for child in walk_children(member):
                    if getattr(child, 'id', '') == 'statusBadge':
                        return child.color.name
