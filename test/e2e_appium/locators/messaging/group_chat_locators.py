"""Locators for group chat creation, management, and member list.

QML sources verified against upstream/master at the time of writing:
    ui/app/AppLayouts/Chat/views/CreateChatView.qml
    ui/app/AppLayouts/Chat/views/ChatHeaderContentView.qml
    ui/imports/shared/views/chat/ChatContextMenuView.qml
    ui/imports/shared/popups/RenameGroupPopup.qml
    ui/imports/shared/views/PickedContacts.qml
    ui/imports/shared/views/ExistingContacts.qml

A few UIs did not have a dedicated objectName at the time of writing — those
locators are marked `# TODO: verify objectName` and use a fallback xpath that
needs on-device verification. Fix these as the relevant QML gets objectName'd.
"""

from ..base_locators import BaseLocators


class GroupChatLocators(BaseLocators):
    """Locators for group chat flows.

    This complements ``ChatLocators`` — group-specific elements only.
    For shared elements (MESSAGE_INPUT, CHAT_SEARCH_BOX, etc.) reuse
    ``ChatLocators``.
    """

    # ------------------------------------------------------------------
    # Group creation (CreateChatView)
    # ------------------------------------------------------------------

    # The member-suggestion list inside CreateChatView
    # QML: CreateChatView.qml: objectName: "createChatContactsList"
    CREATE_CHAT_CONTACTS_LIST = BaseLocators.resource_id_contains(
        "createChatContactsList"
    )

    # The free-text input where the user types contact names / ENS / chat keys.
    # QML: InlineSelectorPanel.qml ~line 254 — TextInput { objectName: "chatRecipientInput" }
    MEMBER_PICKER_INPUT = BaseLocators.resource_id_contains("chatRecipientInput")

    # The confirm button in the create-chat view's footer.
    # QML: InlineSelectorPanel.qml ~line 183 — objectName: "inlineSelectorConfirmButton"
    CREATE_CHAT_CONFIRM_BUTTON = BaseLocators.resource_id_contains(
        "inlineSelectorConfirmButton"
    )

    # ------------------------------------------------------------------
    # Group chat header (ChatHeaderContentView)
    # ------------------------------------------------------------------

    # Header button that shows the current chat's title; tapping opens
    # the group info / chat details sheet on mobile.
    # QML: ChatHeaderContentView.qml: objectName: "chatInfoBtnInHeader"
    CHAT_INFO_HEADER_BUTTON = BaseLocators.resource_id_contains(
        "chatInfoBtnInHeader"
    )

    # In-chat header "Members" button → opens UserListPanel. QML
    # ChatHeaderContentView.qml gives it no objectName (id "membersButton"
    # only), so this best-effort locator usually misses; callers fall back
    # to a position tap relative to chatToolbarMoreOptionsButton.
    MEMBERS_BUTTON = BaseLocators.resource_id_contains("membersButton")

    # Members list panel + remove-from-group action. UserListPanel rows
    # (StatusMemberListItem) set Accessible.name = userName, so they're
    # identifiable by member name — unlike the chip picker.
    # QML: UserListPanel.qml "userListPanel"; ProfileContextMenu.qml
    #      "removeFromGroup_StatusItem".
    USER_LIST_PANEL = BaseLocators.resource_id_contains("userListPanel")
    REMOVE_FROM_GROUP_ITEM = BaseLocators.resource_id_contains(
        "removeFromGroup_StatusItem"
    )
    # Any member row in the UserListPanel — used to count current members.
    MEMBER_PANEL_ROW_ANY = BaseLocators.xpath(
        "//*[contains(@resource-id,'StatusMemberListItem')]"
    )

    # Composer placeholder shown when a removed/non-member opens a group:
    # the input switches to this text and sending is disabled.
    # QML: RootStore.qml chatInputPlaceHolderText (bound to
    # isUserAllowedToSendMessage == false for privateGroupChat).
    NOT_A_MEMBER_PLACEHOLDER = BaseLocators.xpath(
        "//*[contains(@text,'You need to be a member of this group') or "
        "contains(@content-desc,'You need to be a member of this group')]"
    )

    @staticmethod
    def member_panel_row_by_name(member_identity: str) -> tuple:
        """A UserListPanel member row, matched by identity name in
        content-desc. ``member_identity`` is the peer's Frilledlizard
        name (from the group name's ``&``-joined parts).
        """
        escaped = member_identity.replace("'", "\\'")
        return BaseLocators.xpath(
            "//*[contains(@resource-id,'StatusMemberListItem')]"
            f"[contains(@content-desc,\"{escaped}\")]"
        )

    # In-chat header "More" button → opens moreOptionsContextMenu, a
    # ChatContextMenuView with the same item objectNames as the chat-list
    # long-press menu. Preferred on Pi: a plain tap is reliable where the
    # long-press → right-click translation isn't.
    # QML: ChatHeaderContentView.qml: objectName "chatToolbarMoreOptionsButton"
    CHAT_TOOLBAR_MORE_OPTIONS_BUTTON = BaseLocators.resource_id_contains(
        "chatToolbarMoreOptionsButton"
    )
    # The chat title lives on this nested Text node, not the parent
    # button — Qt accessibility doesn't surface the button's `title:`.
    # QML: StatusChatInfoButton.qml objectName "statusChatInfoButtonNameText"
    CHAT_INFO_HEADER_NAME_TEXT = BaseLocators.resource_id_contains(
        "statusChatInfoButtonNameText"
    )

    # ------------------------------------------------------------------
    # Chat list context menu (ChatContextMenuView) — applies to the row
    # for a group chat in the chat list.
    # ------------------------------------------------------------------

    # "Add / remove from group" context menu action.
    # QML: ChatContextMenuView.qml: objectName: "addRemoveFromGroupStatusAction"
    ADD_REMOVE_FROM_GROUP_ACTION = BaseLocators.resource_id_contains(
        "addRemoveFromGroupStatusAction"
    )

    # "Edit group name and image" menu item.
    # QML: ChatContextMenuView.qml: objectName: "editNameAndImageMenuItem"
    EDIT_GROUP_NAME_MENU_ITEM = BaseLocators.resource_id_contains(
        "editNameAndImageMenuItem"
    )

    # "Delete / Leave group" menu item — same objectName as 1:1 close chat;
    # the surrounding context determines label.
    # QML: ChatContextMenuView.qml: objectName: "deleteOrLeaveMenuItem"
    DELETE_OR_LEAVE_MENU_ITEM = BaseLocators.resource_id_contains(
        "deleteOrLeaveMenuItem"
    )

    # "Clear history" menu item for groups (distinct from the 1:1 variant).
    # QML: ChatContextMenuView.qml: objectName: "clearHistoryGroupMenuItem"
    CLEAR_GROUP_HISTORY_MENU_ITEM = BaseLocators.resource_id_contains(
        "clearHistoryGroupMenuItem"
    )

    # Confirmation dialog's leave button.
    # QML: ChatContextMenuView.qml's leaveGroupConfirmationDialogComponent
    # uses confirmButtonObjectName "leaveGroupConfirmationDialogLeaveButton"
    # for private group chats. The deleteChatConfirmationDialog (separate
    # component) covers 1:1 / community / channel close flows and uses
    # "deleteChatConfirmationDialogDeleteButton" — not applicable here.
    LEAVE_CONFIRM_BUTTON = BaseLocators.resource_id_contains(
        "leaveGroupConfirmationDialogLeaveButton"
    )

    # ------------------------------------------------------------------
    # Rename group popup (RenameGroupPopup)
    # ------------------------------------------------------------------

    # The popup container bridges as ".../RenameGroupPopup"; the
    # ``groupChatEdit_*`` prefix is only on its child input/save controls.
    # QML: RenameGroupPopup.qml
    RENAME_GROUP_POPUP = BaseLocators.resource_id_contains("RenameGroupPopup")
    RENAME_GROUP_NAME_INPUT = BaseLocators.resource_id_contains(
        "groupChatEdit_name"
    )
    RENAME_GROUP_SAVE_BUTTON = BaseLocators.resource_id_contains(
        "groupChatEdit_save"
    )

    # ------------------------------------------------------------------
    # Member list item (ExistingContacts / PickedContacts)
    # ------------------------------------------------------------------

    @staticmethod
    def member_list_item_by_pubkey(compressed_pubkey: str) -> tuple:
        """Locator for a single member row in the add/remove-member list.

        QML: ExistingContacts.qml / PickedContacts.qml:
            objectName: "statusMemberListItem-%1".arg(model.compressedPubKey)
        """
        escaped = compressed_pubkey.replace("'", "\\'")
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'statusMemberListItem-{escaped}')]"
        )

    @staticmethod
    def member_list_item_by_name(display_name: str) -> tuple:
        """Locator for a member row found by display name anywhere in the row.

        Fallback for when we don't have the compressed pubkey handy; less
        reliable than :meth:`member_list_item_by_pubkey` because another row
        with the same display substring can match.
        """
        escaped = display_name.replace("'", "\\'")
        return BaseLocators.xpath(
            "//*[contains(@resource-id,'statusMemberListItem')]"
            f"[contains(@content-desc,\"{escaped}\") or contains(@text,\"{escaped}\")]"
        )

    # Generic member-list-item pattern.
    #
    # Two different list surfaces use this locator:
    #
    # 1. Create-chat picker (CreateChatView → ContactListItemDelegate over
    #    StatusListView{objectName:"createChatContactsList"}). Each row's
    #    resource-id is the QML-class path
    #    "...CreateChatView_QMLTYPE_N.ContactListItemDelegate_QMLTYPE_M".
    #    Qt's accessibility bridge marks these rows ``clickable="false"``
    #    (onClicked is handled at the QML layer, not bridged to a11y), so
    #    we do NOT filter by ``@clickable``; the element-tap fallback in
    #    ``safe_click`` works regardless of the a11y flag.
    # 2. Add/remove-members sheet (ExistingContacts.qml /
    #    PickedContacts.qml). Rows there have objectName
    #    "statusMemberListItem-{compressedPubKey}".
    #
    # The xpath alternation covers both surfaces.
    ANY_MEMBER_LIST_ITEM = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactListItemDelegate')]"
        " | //*[contains(@resource-id,'statusMemberListItem-')]"
    )

    @staticmethod
    def contact_checkbox(display_name: str) -> tuple:
        """Locator for the tappable checkbox on a contact suggestion row.

        QML: ExistingContacts.qml ~line 105:
            objectName: "contactCheckbox-%1".arg(model.displayName)

        ``displayName`` here is the local identity name Status renders for
        the contact (e.g. "Nippy Idolized Dalmatian"), not the chat-key
        short form. Pair this with reading the peer's identity name from
        the open 1-1 chat header before opening the create-chat surface.
        """
        escaped = display_name.replace("'", "\\'")
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'contactCheckbox-{escaped}')]"
        )

    # ------------------------------------------------------------------
    # Chat list entry for a group chat — reuses the 1:1 chat list row
    # (StatusDraggableListItem) but the display name is the group name.
    # ------------------------------------------------------------------

    @staticmethod
    def group_chat_row_by_name(group_name: str) -> tuple:
        """Locator for a group-chat row in the main chat list.

        QML: ContactsColumnView.qml chat list renders each chat as a
        StatusDraggableListItem. The chat name appears in any of:
        the ``text`` attribute, ``content-desc``, or — for QML
        accessibility names — embedded in the dotted ``resource-id``
        path (e.g. ``"...<chatName>.StatusDraggableListItem_..."``).
        """
        escaped = group_name.replace("'", "\\'")
        return BaseLocators.xpath(
            "//*[contains(@resource-id,'StatusDraggableListItem')]"
            f"[contains(@text,\"{escaped}\") or contains(@content-desc,\"{escaped}\")"
            f" or contains(@resource-id,\"{escaped}\")]"
        )
