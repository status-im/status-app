import re
import typing

import allure

import configs
import driver
from driver.objects_access import (
    find_descendant_by_object_name,
    is_descendant_of,
    walk_children,
)
from gui.components.messaging.message_context_menu_popup import MessageContextMenuPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.screens.community import BannedCommunityScreen, CommunityScreen
from helpers.chat_helper import message_plain_text, plain_text_from_message_object
from scripts.tools.image import Image

SENT_OUTGOING_ENUM = 2
DELIVERED_OUTGOING_ENUM = 3
SENT_TICK_ICON = 'tiny/message/sent'
DELIVERED_TICK_ICON = 'tiny/message/delivered'
_OUTGOING_QML_DEPTH = 48


def _iter_message_qml_nodes(obj, depth: int = _OUTGOING_QML_DEPTH):
    roots = [obj]
    try:
        loaded = getattr(obj, 'item', None)
        if loaded is not None:
            roots.append(loaded)
    except (RuntimeError, AttributeError):
        pass
    for root in roots:
        yield root
        try:
            yield from walk_children(root, depth)
        except (RuntimeError, AttributeError, LookupError):
            pass


def _qml_str(node, name: str) -> str:
    try:
        value = getattr(node, name, None)
        return str(value) if value not in (None, '') else ''
    except (RuntimeError, AttributeError):
        return ''


def _qml_int(node, name: str) -> typing.Optional[int]:
    try:
        value = getattr(node, name, None)
        return int(value) if value not in (None, '') else None
    except (RuntimeError, AttributeError, TypeError, ValueError):
        return None


def _qml_tick_flags(node) -> typing.Tuple[bool, bool]:
    try:
        icon = getattr(node, 'icon', None)
        if icon is None:
            return False, False
        icon_name = str(icon)
        return SENT_TICK_ICON in icon_name, DELIVERED_TICK_ICON in icon_name
    except (RuntimeError, AttributeError):
        return False, False


def _nudge_outgoing_header(message: 'Message') -> None:
    obj = message.object
    try:
        loaded = getattr(obj, 'item', None)
        driver.mouseMove(loaded if loaded is not None else obj)
    except (RuntimeError, AttributeError, LookupError, TypeError):
        pass
    message._outgoing = None


def _find_named_descendant(parent, object_name: str):
    try:
        descendant = find_descendant_by_object_name(parent, object_name)
        if descendant is not None:
            return descendant
    except (LookupError, RuntimeError, AttributeError):
        pass
    try:
        candidates = driver.findAllObjects({'objectName': object_name})
    except (LookupError, RuntimeError, AttributeError):
        return None
    return next(
        (
            candidate for candidate in candidates
            if is_descendant_of(parent, candidate)
        ),
        None,
    )



class _OutgoingSnapshot(typing.NamedTuple):
    status: str
    enum: typing.Optional[int]
    message_id: str
    sent_tick: bool = False
    delivered_tick: bool = False

    def is_delivered(self) -> bool:
        return (
            self.delivered_tick
            or self.status == 'delivered'
            or self.enum == DELIVERED_OUTGOING_ENUM
        )

    def is_sent(self) -> bool:
        if self.is_delivered():
            return True
        return (
            self.sent_tick
            or self.status == 'sent'
            or self.enum in (SENT_OUTGOING_ENUM, DELIVERED_OUTGOING_ENUM)
        )


class Message:
    _UI_PARSE_DEPTH = 48

    def __init__(self, obj):
        self.object = obj
        self._ui_parsed = False
        self._outgoing: typing.Optional[_OutgoingSnapshot] = None
        self.date: typing.Optional[str] = None
        self.time: typing.Optional[str] = None
        self.icon: typing.Optional[Image] = None
        self.from_user: typing.Optional[str] = None
        self._text: typing.Optional[str] = None
        self._delegate_button: typing.Optional[Button] = None
        self._reply_corner: typing.Optional[QObject] = None
        self.link_preview: typing.Optional[QObject] = None
        self.link_preview_title_object: typing.Optional[QObject] = None
        self._image_message: typing.Optional[QObject] = None
        self.banner_image: typing.Optional[QObject] = None
        self._go_to_community_button: typing.Optional[Button] = None
        self._community_invitation: dict = {}

    @property
    def community_invitation(self) -> dict:
        self._ensure_ui_parsed()
        return self._community_invitation

    @property
    def text(self) -> typing.Optional[str]:
        plain = plain_text_from_message_object(self.object)
        if plain:
            return plain
        self._ensure_ui_parsed()
        return self._text

    @property
    def delegate_button(self) -> typing.Optional[Button]:
        self._ensure_ui_parsed()
        return self._delegate_button

    @property
    def reply_corner(self) -> typing.Optional[QObject]:
        self._ensure_ui_parsed()
        return self._reply_corner

    @property
    def image_message(self) -> typing.Optional[QObject]:
        self._ensure_ui_parsed()
        return self._image_message

    def _ensure_ui_parsed(self):
        if self._ui_parsed:
            return
        self._ui_parsed = True
        self.init_ui()

    def init_ui(self):
        try:
            for child in walk_children(self.object, self._UI_PARSE_DEPTH):
                try:
                    object_name = getattr(child, 'objectName', '')
                    child_id = getattr(child, 'id', '')

                    if object_name == 'StatusDateGroupLabel':
                        self.date = str(getattr(child, 'text', ''))
                    elif object_name == 'communityName':
                        self._community_invitation['name'] = str(getattr(child, 'text', ''))
                    elif object_name == 'communityDescription':
                        self._community_invitation['description'] = str(getattr(child, 'text', ''))
                    elif child_id == 'titleLayout':
                        self.link_preview_title_object = child
                    elif object_name == 'StatusTextMessage_chatText' or child_id == 'chatText':
                        self._text = str(getattr(child, 'text', ''))
                    else:
                        match child_id:
                            case 'profileImage':
                                self.icon = Image(driver.objectMap.realName(child))
                            case 'primaryDisplayName':
                                self.from_user = str(getattr(child, 'text', ''))
                            case 'timestampText':
                                self.time = str(getattr(child, 'text', ''))
                            case 'replyCorner':
                                self._reply_corner = QObject(real_name=driver.objectMap.realName(child))
                            case 'delegate':
                                self._delegate_button = Button(real_name=driver.objectMap.realName(child))
                            case 'linksMessageView':
                                self.link_preview = QObject(real_name=driver.objectMap.realName(child))
                            case 'imageMessage':
                                self._image_message = child
                            case 'bannerImage':
                                self.banner_image = QObject(real_name=driver.objectMap.realName(child))
                            case 'joinBtn':
                                self._go_to_community_button = Button(
                                    real_name=driver.objectMap.realName(child)
                                )
                except (AttributeError, RuntimeError, LookupError):
                    # Skip children that can't be accessed safely
                    continue
        except (RuntimeError, AttributeError, LookupError):
            # If walking children fails, continue with minimal initialization
            pass

        if self._text is None:
            chat_text = _find_named_descendant(self.object, 'StatusTextMessage_chatText')
            if chat_text is not None:
                self._text = str(getattr(chat_text, 'text', ''))

    def has_community_invite(self) -> bool:
        if self.community_link:
            return True
        if str(getattr(self.object, 'communityId', '') or ''):
            return True
        try:
            for child in walk_children(self.object, self._UI_PARSE_DEPTH):
                if str(getattr(child, 'communityId', '') or ''):
                    return True
                object_name = str(getattr(child, 'objectName', ''))
                if object_name in ('linkPreviewTitle', 'communityName', 'communityDescription'):
                    return True
        except (RuntimeError, AttributeError, LookupError):
            pass
        return False

    @property
    def community_link(self) -> typing.Optional[str]:
        match = re.search(r'https?://status\.app/c/[^\s<]+', message_plain_text(self))
        return match.group(0).rstrip('.,;:!?)]}') if match else None

    def activate_link(self, href: str) -> None:
        text_bubble = _find_named_descendant(self.object, 'StatusMessage_textMessage')
        if text_bubble is None:
            raise LookupError(f'Message text bubble was not found for link {href!r}')
        text_bubble.linkActivated(href)

    def _find_go_to_community_button(self) -> typing.Optional[Button]:
        self._ensure_ui_parsed()
        if self._go_to_community_button is not None:
            return self._go_to_community_button
        try:
            for child in walk_children(self.object, self._UI_PARSE_DEPTH):
                if str(getattr(child, 'text', '')) == 'Go to Community':
                    return Button(real_name=driver.objectMap.realName(child))
        except (RuntimeError, AttributeError, LookupError):
            pass
        return None

    def _go_to_community_button_ready(self, button: Button) -> bool:
        try:
            obj = button.object
            if not bool(getattr(obj, 'visible', False)):
                return False
            if bool(getattr(obj, 'loading', False)):
                return False
            return True
        except (RuntimeError, AttributeError, LookupError):
            return False

    def _click_go_to_community_button(self) -> bool:
        button = self._find_go_to_community_button()
        if button is None:
            return False
        if not driver.waitFor(
            lambda: self._go_to_community_button_ready(button),
            configs.timeouts.COMMUNITY_LOAD_TIMEOUT_MSEC,
        ):
            return False
        button.click()
        return True

    @allure.step('Open community invitation')
    def open_community_invitation(
            self,
            expected_link: str = None,
    ):
        community_link = self.community_link
        if expected_link is not None and community_link != expected_link.strip():
            raise AssertionError(
                'Received community URL does not match the copied URL: '
                f'expected={expected_link.strip()!r}, actual={community_link!r}'
            )

        if self._click_go_to_community_button():
            return CommunityScreen().wait_for_content_loaded()

        href = expected_link.strip() if expected_link else community_link
        if href is not None:
            self.activate_link(href)
        elif self.delegate_button is not None:
            self.delegate_button.click()
        else:
            raise LookupError(
                'Community invitation has neither a card button, a link, nor a clickable delegate'
            )

        return CommunityScreen().wait_for_content_loaded()

    def open_banned_community_invitation(self):
        driver.waitFor(lambda: self.delegate_button.is_visible, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        self.delegate_button.click()
        return BannedCommunityScreen().wait_until_appears()

    @allure.step('Open message context menu')
    def open_context_menu(self):
        from gui.screens.messages.chat import MessageQuickActions
        return MessageQuickActions(self, mode='right_click')

    @allure.step('Hover message')
    def hover_message(self):
        from gui.screens.messages.chat import MessageQuickActions
        return MessageQuickActions(self, mode='hover')

    @property
    @allure.step('Get user name in pinned message details')
    def user_name_in_pinned_message(self) -> str:
        return str(self.delegate_button.object.pinnedBy)

    @property
    @allure.step('Get pinned message details')
    def pinned_details(self) -> typing.Tuple[str, str, str]:
        delegate = self.delegate_button.object
        return (
            str(delegate.pinnedMsgInfoText),
            str(delegate.pinnedBy),
            str(delegate.background.color.name),
        )

    @property
    def pinned_state(self) -> typing.Optional[bool]:
        try:
            return bool(getattr(self.object, 'pinnedMessage', False))
        except (RuntimeError, AttributeError):
            return None

    @property
    @allure.step('Get message pinned state')
    def message_is_pinned(self) -> bool:
        return self.pinned_state is True

    @property
    @allure.step('Whether message content is a sticker')
    def is_sticker_message(self) -> bool:
        return bool(getattr(self.object, 'isSticker', False))

    def _outgoing_snapshot(self) -> _OutgoingSnapshot:
        if self._outgoing is None:
            self._outgoing = self._read_outgoing_snapshot()
        return self._outgoing

    def _read_outgoing_snapshot(self) -> _OutgoingSnapshot:
        status, enum, message_id = '', None, ''
        sent_tick = delivered_tick = False

        for node in _iter_message_qml_nodes(self.object):
            raw_status = _qml_str(node, 'messageOutgoingStatus')
            if raw_status == 'delivered' or not status:
                status = raw_status or status
            raw_enum = _qml_int(node, 'outgoingStatus')
            if raw_enum == DELIVERED_OUTGOING_ENUM or enum is None:
                enum = raw_enum if raw_enum is not None else enum
            if not message_id:
                message_id = _qml_str(node, 'messageId')
            node_sent, node_delivered = _qml_tick_flags(node)
            sent_tick |= node_sent
            delivered_tick |= node_delivered
            if delivered_tick or status == 'delivered' or enum == DELIVERED_OUTGOING_ENUM:
                break

        return _OutgoingSnapshot(status, enum, message_id, sent_tick, delivered_tick)

    @property
    def is_outgoing_delivered(self) -> bool:
        self._outgoing = None
        return self._outgoing_snapshot().is_delivered()

    @property
    def is_outgoing_sent(self) -> bool:
        self._outgoing = None
        return self._outgoing_snapshot().is_sent()

    def describe_outgoing(self) -> str:
        snapshot = self._outgoing_snapshot()
        return (
            f'id={snapshot.message_id!r} messageOutgoingStatus={snapshot.status!r} '
            f'outgoingStatus={snapshot.enum!r} sent_tick={snapshot.sent_tick} '
            f'delivered_tick={snapshot.delivered_tick}'
        )

    @property
    def message_id(self) -> str:
        return self._outgoing_snapshot().message_id

    @allure.step('Get title of link preview')
    def get_link_preview_title(self) -> str:
        self._ensure_ui_parsed()
        for child in walk_children(self.link_preview_title_object, 16):
            if getattr(child, 'objectName', '') == 'linkPreviewTitle':
                return str(child.text)

    @allure.step('Get link domain from message')
    def get_link_domain(self) -> str:
        link_data = getattr(self.delegate_button.object, 'linkData', None)
        if link_data is None:
            raise AttributeError('linkData is not available on message object yet')
        domain = getattr(link_data, 'domain', None)
        if domain is None:
            raise AttributeError('domain is not available in linkData')
        return str(domain)

    @allure.step('Open context menu for message')
    def open_context_menu_for_message(self):
        QObject(real_name=driver.objectMap.realName(self.object)).right_click()
        return MessageContextMenuPopup().wait_until_appears()

    @allure.step('Get emoji reactions pathes')
    def get_emoji_reactions_pathes(self):
        reactions_pathes = []
        try:
            for child in walk_children(self.object, self._UI_PARSE_DEPTH):
                try:
                    child_id = getattr(child, 'id', '')
                    if child_id == 'reactionDelegate':
                        # Search for StatusIcon inside reactionDelegate and extract emoji ID from icon path
                        try:
                            for item in walk_children(child, 16):
                                try:
                                    icon_path = None
                                    if hasattr(item, 'icon'):
                                        icon_path = str(getattr(item, 'icon', ''))
                                    elif hasattr(item, 'source'):
                                        icon_path = str(getattr(item, 'source', ''))

                                    if icon_path:
                                        # Extract emoji ID from path like "qrc:/assets/twemoji/svg/1f600.svg"
                                        match = re.search(r'/([a-fA-F0-9]+)\.svg', icon_path)
                                        if match:
                                            reactions_pathes.append(match.group(1))
                                            break
                                except (AttributeError, RuntimeError, LookupError):
                                    # Skip items that can't be accessed safely
                                    continue
                        except (RuntimeError, AttributeError, LookupError):
                            # Skip reactionDelegate children if walking fails
                            continue
                except (AttributeError, RuntimeError, LookupError):
                    # Skip children that can't be accessed safely
                    continue
        except (RuntimeError, AttributeError, LookupError):
            # If walking children fails, return empty list
            pass

        return reactions_pathes
