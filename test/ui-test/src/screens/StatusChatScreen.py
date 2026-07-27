# ******************************************************************************
# Status.im
# *****************************************************************************/
# /**
# * \file    StatusChatScreen.py
# *
# * \date    June 2022
# * \brief   Chat Screen.
# *****************************************************************************/

import re

import copy
from enum import Enum
import time
from drivers.SquishDriver import *
from drivers.SquishDriverVerification import *
from drivers.SDKeyboardCommands import *
from common.Common import *
from utils.ObjectAccess import *

_MENTION_SYMBOL = "@"
_LINK_HREF_REGEX = '<a href="(.+?)">'

class MessageContentType(Enum):
    FETCH_MORE_MESSAGES_BUTTON = -2
    CHAT_IDENTIFIER = -1    
    UNKNOWN = 0
    MESSAGE = 1
    STICKER = 2
    STATUS = 3
    EMOJI = 4
    TRANSACTION = 5
    SYSTEM_MESSAGE_PRIVATE_GROUP= 6
    IMAGE = 7
    AUDIO = 8
    COMMUNITY_INVITE = 9
    GAP = 10
    EDIT = 11

class ChatComponents(Enum):
    MESSAGE_INPUT = "chatView_messageInput"
    TOOLBAR_INFO_BUTTON = "chatView_StatusChatInfoButton"
    CHAT_LOG = "chatView_log"
    LAST_MESSAGE_TEXT = "chatView_lastChatText_Text"
    LAST_MESSAGE = "chatView_chatLogView_lastMsg_MessageView"
    MESSAGE_DISPLAY_NAME = "StatusMessageHeader_DisplayName"
    MEMBERS_LISTVIEW = "chatView_chatMembers_ListView"
    CONFIRM_DELETE_MESSAGE_BUTTON = "chatButtonsPanelConfirmDeleteMessageButton_StatusButton"
    SUGGESTIONS_BOX = "chatView_SuggestionBoxPanel"
    SUGGESTIONS_LIST = "chatView_suggestion_ListView"
    MENTION_PROFILE_VIEW = "chatView_userMentioned_ProfileView"
    CHAT_INPUT_EMOJI_BUTTON = "chatInput_Emoji_Button"
    EMOJI_POPUP_EMOJI_PLACEHOLDER = "emojiPopup_Emoji_Button_Placeholder"
    CHAT_LIST = "chatList_ListView"
    MORE_OPTIONS_BUTTON = "chatView_ChatToolbarMoreOptionsButton"
    CLEAR_HISTORY_MENUITEM = "clearHistoryMenuItem"
    EDIT_COMPOSER_INPUT = "chatView_editComposerInputComponent"
    EDIT_COMPOSER_TEXTAREA = "chatView_editComposerTextArea"

    EDIT_NAME_AND_IMAGE_MENUITEM = "editNameAndImageMenuItem"
    LEAVE_CHAT_MENUITEM = "leaveChatMenuItem"

    GIF_POPUP_BUTTON = "chatView_gifPopupButton"
    ENABLE_GIF_BUTTON = "gifPopup_enableGifButton"
    GIF_MOUSEAREA = "gifPopup_gifMouseArea"
    CHAT_INPUT_STICKER_BUTTON = "chat_Input_Stickers_Button"

    LINK_PREVIEW_UNFURLED_IMAGE = "chatView_unfurledImageComponent_linkImage"
    LINK_PREVIEW_UNFURLED_LINK_IMAGE = "chatView_unfurledLinkComponent_linkImage"
    LINK_PREVIEW_OPEN_SETTINGS = "chatView_LinksMessageView_enableBtn"

    DELETE_CHANNEL_CONFIRMATION_DIALOG_DELETE_BUTTON = "delete_Channel_ConfirmationDialog_DeleteButton"

class ChatStickerPopup(Enum):
    STICKERS_POPUP_GET_STICKERS_BUTTON = "chat_StickersPopup_GetStickers_Button"
    STICKERS_POPUP_RETRY_BUTTON = "chat_StickersPopup_Retry_Button"
    STICKERS_POPUP_MARKET_GRID_VIEW = "chat_StickersPopup_StickerMarket_GridView"
    STICKERS_POPUP_MARKET_GRID_VIEW_DELEGATE_ITEM_1 = "chat_StickersPopup_StickerMarket_DelegateItem_1"
    STICKERS_POPUP_MARKET_INSTALL_BUTTON = "chat_StickersPopup_StickerMarket_Install_Button"
    MODAL_CLOSE_BUTTON = "modal_Close_Button"
    STICKER_LIST_GRID = "chat_StickersPopup_StickerList_Grid"

class ChatItems(Enum):
    STATUS_MESSAGE_TEXT_MESSAGE = "StatusMessage_textMessage"
    STATUS_MESSAGE_REPLY_DETAILS = "StatusMessage_replyDetails"
    STATUS_MESSAGE_REPLY_DETAILS_TEXT_MESSAGE = "StatusMessage_replyDetails_textMessage"
    STATUS_TEXT_MESSAGE_CHAT_TEXT = "StatusTextMessage_chatText"

class ChatMessagesHistory(Enum):
    CHAT_CREATED_TEXT = 1
    HAS_ADDED_TEXT = 0

class ChatMessageHoverMenu(Enum):
    REPLY_TO_BUTTON = "replyToMessageButton"
    EDIT_BUTTON = "editMessageButton"
    DELETE_BUTTON = "chatDeleteMessageButton"

class ProfileMenu(Enum):
    VIEW_PROFILE_MENU_ITEM = "viewProfile_MenuItem"
    
class Emoji(Enum):
    EMOJI_SUGGESTIONS_FIRST_ELEMENT = "emojiSuggestions_first_inputListRectangle"

class GroupChatEditPopup(Enum):
    GROUP_CHAT_EDIT_NAME = "groupChatEdit_name"
    GROUP_CHAT_EDIT_COLOR_REPEATER = "groupChatEdit_colorRepeater"
    GROUP_CHAT_EDIT_IMAGE = "groupChatEdit_image"
    GROUP_CHAT_EDIT_SAVE = "groupChatEdit_save"
    GROUP_CHAT_EDIT_MAIN = "groupChatEdit_main"
    GROUP_CHAT_CROP_WORKFLOW_ITEM = "groupChatEdit_workflowItem"
    GROUP_CHAT_CROPPER_ACCEPT_BUTTON = "groupChatEdit_cropperAcceptButton"

class StatusChatScreen:

    def __init__(self):
        verify_screen(ChatComponents.MESSAGE_INPUT.value)
        verify_screen(ChatComponents.TOOLBAR_INFO_BUTTON.value)
    
    #####################################
    ### Screen get states:
    #####################################
    def chat_loaded(self):
        verify(is_displayed(ChatComponents.LAST_MESSAGE.value), "Checking chat is loaded by looking if last message is displayed.")

    def get_message_at_index(self, index: int):
        obj = wait_and_get_obj(ChatComponents.CHAT_LOG.value).itemAtIndex(int(index))
        return obj

    #####################################
    ### Screen actions region:
    #####################################
    def type_message(self, message: str):
        TextEdit(ChatComponents.MESSAGE_INPUT.value).type_text(message)

    def press_enter(self):
        press_enter(ChatComponents.MESSAGE_INPUT.value)

    def send_message(self, message: str):
        self.type_message(message)
        self.press_enter()
        
    def clear_history(self):
        click_obj_by_name(ChatComponents.MORE_OPTIONS_BUTTON.value)
        click_obj_by_name(ChatComponents.CLEAR_HISTORY_MENUITEM.value)

    def open_group_chat_edit_popup(self):
        time.sleep(2)
        hover_and_click_object_by_name(ChatComponents.MORE_OPTIONS_BUTTON.value)
        time.sleep(2)
        hover_and_click_object_by_name(ChatComponents.EDIT_NAME_AND_IMAGE_MENUITEM.value)

    def leave_chat(self):
        time.sleep(1)
        hover_and_click_object_by_name(ChatComponents.MORE_OPTIONS_BUTTON.value)
        time.sleep(1)
        hover_and_click_object_by_name(ChatComponents.LEAVE_CHAT_MENUITEM.value)
        visible, _ = is_loaded_visible_and_enabled(ChatComponents.DELETE_CHANNEL_CONFIRMATION_DIALOG_DELETE_BUTTON.value, 100)
        if (visible):
            click_obj_by_name(ChatComponents.DELETE_CHANNEL_CONFIRMATION_DIALOG_DELETE_BUTTON.value)

    def group_chat_edit_name(self, name):
        TextEdit(GroupChatEditPopup.GROUP_CHAT_EDIT_NAME.value).text = name

    def group_chat_edit_save(self):
        # save may be disabled, eg. if color from scenario is already set
        obj = get_obj(GroupChatEditPopup.GROUP_CHAT_EDIT_SAVE.value)
        if (is_visible_and_enabled(obj)):
            click_obj_by_name(GroupChatEditPopup.GROUP_CHAT_EDIT_SAVE.value)
        else:
            press_escape(GroupChatEditPopup.GROUP_CHAT_EDIT_MAIN.value)

    def group_chat_edit_color(self, newColor: str):
        colorList = get_obj(GroupChatEditPopup.GROUP_CHAT_EDIT_COLOR_REPEATER.value)
        for index in range(colorList.count):
            color = colorList.itemAt(index)
            if(color.radioButtonColor == newColor):
                click_obj(colorList.itemAt(index))

    def group_chat_edit_image(self, fixtures_root: str):
        self._group_chat_input_image("file:///"+ fixtures_root + "images/ui-test-image0.jpg")

    def _group_chat_input_image(self, groupChatUrl: str):
        parentObject = get_obj(GroupChatEditPopup.GROUP_CHAT_EDIT_IMAGE.value)
        workflow = parentObject.cropWorkflow
        workflow.cropImage(groupChatUrl)
        click_obj_by_name(GroupChatEditPopup.GROUP_CHAT_CROPPER_ACCEPT_BUTTON.value)
        
    def send_gif(self):
        click_obj_by_name(ChatComponents.GIF_POPUP_BUTTON.value)
        click_obj_by_name(ChatComponents.ENABLE_GIF_BUTTON.value)
        click_obj_by_name(ChatComponents.GIF_MOUSEAREA.value)       
        press_enter(ChatComponents.MESSAGE_INPUT.value)
        
    def select_the_emoji_in_suggestion_list(self):
        click_obj_by_name(Emoji.EMOJI_SUGGESTIONS_FIRST_ELEMENT.value)   
        
    def reply_to_message_at_index(self, index: int, message: str):
        message_object_to_reply_to = self.get_message_at_index(index)
        verify(not is_null(message_object_to_reply_to), "Message to reply to is loaded")
        move_mouse_over_object(message_object_to_reply_to)
        found_reply_to_button = get_children_with_object_name(message_object_to_reply_to, ChatMessageHoverMenu.REPLY_TO_BUTTON.value)[0]
        verify(not is_null(found_reply_to_button), "Reply button found")
        move_mouse_over_object(found_reply_to_button)
        click_obj(found_reply_to_button)
        self.send_message(message)
        
    def open_user_profile_from_message_at_index(self, index: int):
        message_object = self.get_message_at_index(index)
        verify(not is_null(message_object), "Message to click on is loaded")
        message_display_name = get_children_with_object_name(message_object, ChatComponents.MESSAGE_DISPLAY_NAME.value)[0]
        verify(not is_null(message_display_name), "Message display name found")
        right_click_obj(message_display_name)
        click_obj_by_name(ProfileMenu.VIEW_PROFILE_MENU_ITEM.value)
    
    def edit_message_at_index(self, index: int, message: str):
        message_object_to_edit = wait_and_get_obj(ChatComponents.CHAT_LOG.value).itemAtIndex(int(index))
        verify(not is_null(message_object_to_edit), "Message to edit is loaded")
        move_mouse_over_object(message_object_to_edit)
        found_edit_button = get_children_with_object_name(message_object_to_edit, ChatMessageHoverMenu.EDIT_BUTTON.value)[0]
        verify(not is_null(found_edit_button), "Edit button found")
        move_mouse_over_object(found_edit_button)
        click_obj(found_edit_button)
        wait_for_object_and_type(ChatComponents.EDIT_COMPOSER_TEXTAREA.value, "<Ctrl+a>")
        type_text(ChatComponents.EDIT_COMPOSER_TEXTAREA.value, message)
        press_enter(ChatComponents.EDIT_COMPOSER_TEXTAREA.value)
        
    def switch_to_chat(self, chatName: str):
        chat_lists = get_obj(ChatComponents.CHAT_LIST.value)
        verify(chat_lists.count > 0, "At least one chat exists")
        for i in range(chat_lists.count):
            chat = chat_lists.itemAtIndex(i)
            chat_list_items = get_children_with_object_name(chat, "chatItem")
            verify(len(chat_list_items) > 0, "StatusChatListItem exists")
            if str(chat_list_items[0].name) == chatName:
                click_obj(chat)
                return
        verify(False, "Chat switched")
        
    # TODO: Find ADMIN
    def find_member_in_panel(self, member: str):
        found = False
        [is_loaded, membersList] = is_loaded_visible_and_enabled(ChatComponents.MEMBERS_LISTVIEW.value)
        if is_loaded:
            for index in range(membersList.count):
                user = membersList.itemAtIndex(index)
                if(user.userName == member):
                    found = True
                    break
        return found

    def delete_message_at_index(self, index: int):
        message_object_to_delete = self.get_message_at_index(index)
        move_mouse_over_object(message_object_to_delete)
        found_delete_button = get_children_with_object_name(message_object_to_delete, ChatMessageHoverMenu.DELETE_BUTTON.value)[0]
        verify(not is_null(found_delete_button), "Delete button found")
        move_mouse_over_object(found_delete_button)
        click_obj(found_delete_button)
        click_obj_by_name(ChatComponents.CONFIRM_DELETE_MESSAGE_BUTTON.value)

    def cannot_delete_last_message(self):
        [loaded, last_message_obj] = is_loaded_visible_and_enabled(ChatComponents.LAST_MESSAGE.value)
        if not loaded:
            verify_failure("No message found")
            return 
        move_mouse_over_object(last_message_obj)
        found_delete_button = get_children_with_object_name(last_message_obj, ChatMessageHoverMenu.DELETE_BUTTON.value)[0]
        verify_false(is_visible_and_enabled(found_delete_button), "Delete button is hidden")
        
    def send_message_with_mention(self, displayName: str, message: str):
        self.do_mention(displayName)
        self.send_message(message)
    
    def cannot_do_mention(self, displayName: str):    
        self.type_message(_MENTION_SYMBOL + displayName)
        displayed = is_displayed(ChatComponents.SUGGESTIONS_BOX.value)
        self.press_enter()
        verify(displayed == False , "Checking suggestion box is not displayed when trying to mention a non existing user.")
        
    def do_mention(self, displayName: str):
        self.type_message(_MENTION_SYMBOL + displayName)
        displayed = is_displayed(ChatComponents.SUGGESTIONS_BOX.value)
        verify(displayed, "Checking suggestion box displayed when trying to do a mention")       
        [loaded, suggestions_list] = is_loaded_visible_and_enabled(ChatComponents.SUGGESTIONS_LIST.value)
        verify(suggestions_list.count > 0, "Checking if suggestion list is greater than 0")
        found = False
        if loaded:            
            for index in range(suggestions_list.count):
                user_mention = suggestions_list.itemAtIndex(index)
                if user_mention.objectName == displayName:
                    found = True
                    click_obj(user_mention)
                    break
        verify(found, "Checking if the following display name is in the mention's list: " + displayName)
                     
    def install_sticker_pack(self, pack_index: str):
        click_obj_by_name(ChatComponents.CHAT_INPUT_STICKER_BUTTON.value)
        click_obj_by_name(ChatStickerPopup.STICKERS_POPUP_GET_STICKERS_BUTTON.value)
        
        # Wait for grid view to be loaded
        grid_view_displayed, grid_view = is_loaded_visible_and_enabled(ChatStickerPopup.STICKERS_POPUP_MARKET_GRID_VIEW.value)
        verify(grid_view_displayed, "Sticker market grid view is not loaded")
        
        # Stickers may not be loaded, retry to load them
        stickers_not_loaded = is_displayed(ChatStickerPopup.STICKERS_POPUP_RETRY_BUTTON.value)
        if (stickers_not_loaded):
            click_obj_by_name(ChatStickerPopup.STICKERS_POPUP_RETRY_BUTTON.value)
        
        # Wait for stickers to load
        stickers_grid_displayed = is_displayed(ChatStickerPopup.STICKERS_POPUP_MARKET_GRID_VIEW_DELEGATE_ITEM_1.value)
        
        # In the meantime popup may be closed due to external (unknown?) reason, reopen it
        if (not stickers_grid_displayed):
            grid_view_displayed = is_displayed(ChatStickerPopup.STICKERS_POPUP_MARKET_GRID_VIEW.value)
            if (not grid_view_displayed):
                click_obj_by_name(ChatComponents.CHAT_INPUT_STICKER_BUTTON.value)
                click_obj_by_name(ChatStickerPopup.STICKERS_POPUP_GET_STICKERS_BUTTON.value)
                grid_view_displayed, grid_view = is_loaded_visible_and_enabled(ChatStickerPopup.STICKERS_POPUP_MARKET_GRID_VIEW.value)
                verify(grid_view_displayed, "Sticker market grid view is not loaded")
          
        # Wait for the items in the GridView to be loaded
        verify(is_displayed(ChatStickerPopup.STICKERS_POPUP_MARKET_GRID_VIEW_DELEGATE_ITEM_1.value), "Sticker item 0 is not displayed")

        scroll_list_view_at_index(grid_view, int(pack_index))

        sticker_pack = grid_view.itemAtIndex(int(pack_index))
        click_obj(sticker_pack)
        
        # Install and close
        click_obj_by_name(ChatStickerPopup.STICKERS_POPUP_MARKET_INSTALL_BUTTON.value)
        click_obj_by_name(ChatStickerPopup.MODAL_CLOSE_BUTTON.value)
        
        verify(sticker_pack.installed == True, "The sticker pack at position " + str(pack_index) + " was not installed")
        
        #Close sticker popup
        click_obj_by_name(ChatComponents.CHAT_INPUT_STICKER_BUTTON.value)
        
    def send_sticker(self, sticker_index: int):
        click_obj_by_name(ChatComponents.CHAT_INPUT_STICKER_BUTTON.value)
        
        loaded, sticker_list_grid = is_loaded_visible_and_enabled(ChatStickerPopup.STICKER_LIST_GRID.value)
        
        if (not loaded):
            verify_failure("Sticker list grid view is not loaded")

        sticker = sticker_list_grid.itemAtIndex(int(sticker_index))
        click_obj(sticker)
        
    def send_emoji(self, emoji_short_name: str, message: str):
        if (message != ""):
            self.type_message(message)
        
        click_obj_by_name(ChatComponents.CHAT_INPUT_EMOJI_BUTTON.value)
        emojiAttr = copy.deepcopy(getattr(names, ChatComponents.EMOJI_POPUP_EMOJI_PLACEHOLDER.value))
        emojiAttr["objectName"] = emojiAttr["objectName"].replace("%NAME%", emoji_short_name)
        click_obj_by_attr(emojiAttr)       
        self.press_enter()

    #####################################
    ### Verifications region:
    #####################################
    def verify_last_message_is_not_loaded(self):
        [loaded, _] = is_loaded_visible_and_enabled(ChatComponents.LAST_MESSAGE_TEXT.value)
        verify_false(loaded, "Success: No message was found")

    def verify_last_message_is_reply(self, message: str):
        last_message_obj = self.get_message_at_index(0)
        last_message_reply_details_obj = get_children_with_object_name(last_message_obj, ChatItems.STATUS_MESSAGE_REPLY_DETAILS.value)[0]
        verify(not is_null(last_message_reply_details_obj), "Checking last message is a reply: " + message)

    def verify_last_message_is_reply_to(self, reply: str, message: str):
        last_message_obj = self.get_message_at_index(0)
        last_message_reply_details_obj = get_children_with_object_name(last_message_obj, ChatItems.STATUS_MESSAGE_REPLY_DETAILS.value)[0]
        text_message_obj = get_children_with_object_name(last_message_reply_details_obj, ChatItems.STATUS_MESSAGE_REPLY_DETAILS_TEXT_MESSAGE.value)[0]
        verify_text_contains(str(text_message_obj.messageDetails.messageText), str(message))

    def verify_last_message_is_reply_to_loggedin_user_message(self, reply: str, message: str):
        last_message_obj = self.get_message_at_index(0)
        last_message_reply_details_obj = get_children_with_object_name(last_message_obj, ChatItems.STATUS_MESSAGE_REPLY_DETAILS.value)[0]
        text_message_obj = get_children_with_object_name(last_message_reply_details_obj, ChatItems.STATUS_MESSAGE_REPLY_DETAILS_TEXT_MESSAGE.value)[0]
        verify_text_contains(str(text_message_obj.messageDetails.messageText), str(message))
        verify_values_equal(str(last_message_reply_details_obj.replyDetails.sender.id), str(last_message_obj.senderId), "Message sender ID doesn't match reply message sender ID")


    def verify_last_message_is_edited(self, message: str):
        last_message_obj = self.get_message_at_index(0)
        verify(bool(last_message_obj.isEdited), "Message is not marked as edited")

    def get_last_message_text(self):
        last_message_obj = self.get_message_at_index(0)
        return last_message_obj.messageText

    def verify_last_message_sent(self, message: str):
        verify_text_contains(str(self.get_last_message_text()), str(message))

    def verify_last_message_sent_is_not(self, message: str):
        verify_text_does_not_contain(str(self.get_last_message_text()), str(message))
    
    # This method expects to have just one mention / link in the last chat message 
    def verify_last_message_sent_contains_mention(self, displayName: str, message: str):
        [loaded, last_message_obj] = is_loaded_visible_and_enabled(ChatComponents.LAST_MESSAGE_TEXT.value)

        if not loaded:
            verify_failure("No messages found in chat.")
        
        # Verifying mention
        verify_text_contains(str(last_message_obj.text), displayName)
        
        # Verifying message
        verify_text_contains(str(last_message_obj.text), message)
        
        # Get link value from chat text:
        try:
            href_info = re.search(_LINK_HREF_REGEX, str(last_message_obj.text)).group(1)
        except AttributeError:
            # <a href=, "> not found in the original string
            verify_failure("Mention link not found in last chat message.")
        
        click_link(ChatComponents.LAST_MESSAGE_TEXT.value, href_info)
        verify(is_found(ChatComponents.MENTION_PROFILE_VIEW.value), "Checking user mentioned profile popup is open.")            
        
    def verify_chat_title(self, title: str):
        info_btn = get_obj(ChatComponents.TOOLBAR_INFO_BUTTON.value)
        verify_text(str(info_btn.title), title)

    def verify_chat_color(self, color: str):
        info_btn = get_obj(ChatComponents.TOOLBAR_INFO_BUTTON.value)
        verify_text(str(info_btn.asset.color.name), str(color.lower()))

    def verify_chat_image(self, path: str):
        fullPath = path + "images/ui-test-image0.jpg"
        image_present(fullPath, True, 95, 25, 150, True)
        
    def verify_members_added(self, members):
        self.verify_total_members_is_displayed_in_toolbar(members)
        self.verify_added_members_message_is_displayed_in_history(members)
        self.verify_members_are_in_list_panel(members)                  

    def verify_members_are_in_list_panel(self, members):
        for row in members[0:]:
            verify(self.find_member_in_panel(row[0]), "Looking for member: " + row[0])
            
    def verify_total_members_is_displayed_in_toolbar(self, members):
        total_members = len(members) + 1  # + Admin
        info_btn_subtitle = str(get_obj(ChatComponents.TOOLBAR_INFO_BUTTON.value).subTitle)
        subtitle_substrings = info_btn_subtitle.split(' ')
        verify(int(subtitle_substrings[0]) == total_members, "Expected members are " + str(total_members) + "and they are displayed " + subtitle_substrings[0])
    
    # NOTE: It is expecting a specific log order and will succeed only just after the chat is created and no messages have been sent.
    # TODO: Improvement --> Iterate through the complete history, check all messages and verify the `createdTxt` is displayed.   
    def verify_added_members_message_is_displayed_in_history(self, members):
        chat_membersAdded_text_obj = self.get_message_at_index(ChatMessagesHistory.HAS_ADDED_TEXT.value)        
        for member in members[0:]:
            verify_text_contains(str(chat_membersAdded_text_obj.messageText), member[0])
            
    # NOTE: It is expecting a specific log order and will succeed only just after the chat is created and no messages have been sent.
    # TODO: Improvement --> Iterate through the complete history, check all messages and verify the `createdTxt` is displayed.
    def verify_chat_created_message_is_displayed_in_history(self, createdTxt: str):
        chat_createChat_text_obj = self.get_message_at_index(ChatMessagesHistory.CHAT_CREATED_TEXT.value)        
        verify_text_contains(str(chat_createChat_text_obj.messageText), createdTxt)

    def verify_last_message_is_sticker(self):
        last_message_obj = get_obj(ChatComponents.CHAT_LOG.value).itemAtIndex(0)
        verify_values_equal(str(last_message_obj.messageContentType), str(MessageContentType.STICKER.value), "The last message is not a sticker")

    def verify_chat_order(self, index: int, chatName: str):
        chat_lists = get_obj(ChatComponents.CHAT_LIST.value)
        chat = chat_lists.itemAtIndex(index)
        verify(not is_null(chat), "Chat ({}) at index {} exists".format(chatName, index))
        chat_list_items = get_children_with_object_name(chat, "chatItem")
        verify(len(chat_list_items) > 0, "StatusChatListItem exists")
        verify(str(chat_list_items[0].name) == chatName, "Chat in order")

    def _verify_image_unfurled_status_for_component(self, objectName: str, image_link: str, unfurled: bool):
        if not unfurled:
            verify_false(is_loaded_visible_and_enabled(objectName, 10)[0], "Image link preview component is not loaded")
        else:
            chat_image_loader = wait_and_get_obj(objectName)
            # Didn't find a way to convert squish QUrls to string
            verify(str(chat_image_loader.source.path) in image_link, "The url is most probably the one expected")

    def verify_image_unfurled_status(self, image_link: str, unfurled: bool):
        message_list = get_obj(ChatComponents.CHAT_LOG.value)
        message_list.positionViewAtEnd()
        self._verify_image_unfurled_status_for_component(ChatComponents.LINK_PREVIEW_UNFURLED_IMAGE.value, image_link, unfurled)

    def verify_link_image_unfurled_status(self, image_link: str, unfurled: bool):
        message_list = get_obj(ChatComponents.CHAT_LOG.value)
        message_list.positionViewAtEnd()
        self._verify_image_unfurled_status_for_component(ChatComponents.LINK_PREVIEW_UNFURLED_LINK_IMAGE.value, image_link, unfurled)
