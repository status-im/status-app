from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

import configs
from scripts.tools.image import Image
from scripts.utils.generators import (
    COMMUNITY_TAGS,
    random_color,
    random_community_description,
    random_community_introduction,
    random_community_leave_message,
    random_community_name,
    random_community_tags,
)


@dataclass
class CommunityChannel:
    name: str = None
    selected: bool = None
    visible: bool = None


@dataclass
class CommunityData:
    name: str = None
    description: str = None
    members: str = None
    image: Image = None
    logo: dict = field(default_factory=dict)
    banner: dict = field(default_factory=dict)
    color: Optional[str] = None
    tags: list = field(default_factory=list)
    introduction: str = None
    leaving_message: str = None
    request_to_join: bool = False


class RandomCommunity(CommunityData):
    def __init__(self, request_to_join: bool = False):
        super().__init__(
            name=random_community_name(),
            description=random_community_description(),
            logo={'fp': configs.testpath.TEST_IMAGES / 'comm_logo.jpeg', 'zoom': None, 'shift': None},
            banner={'fp': configs.testpath.TEST_IMAGES / 'comm_banner.jpeg', 'zoom': None, 'shift': None},
            color=random_color(),
            tags=random_community_tags(),
            introduction=random_community_introduction(),
            leaving_message=random_community_leave_message(),
            request_to_join=request_to_join
        )


@dataclass
class PermissionData:
    checkbox_state: bool
    first_asset: str | bool
    amount: str
    allowed_to: str
    asset_title: str | bool
    allowed_to_title: str
    second_asset: bool | str = False
    in_channel: bool | str = False
    second_asset_title: bool | str = False


permission_data = [
    PermissionData(
        checkbox_state=True,
        first_asset='Status',
        second_asset=False,
        amount='10',
        allowed_to='becomeMember',
        in_channel=False,
        asset_title='10 SNT',
        second_asset_title=False,
        allowed_to_title='Become member'
    )
]

class PermissionsElements(Enum):
    DUPLICATE_WARNING = 'Permission with same properties is already active, edit properties to create a new permission.'


class MintOwnerTokensElements(Enum):
    OWNER_TOKEN_CHEKLIST_ELEMENT_1 = 'Only 1 will ever exist'
    OWNER_TOKEN_CHEKLIST_ELEMENT_2 = 'Hodler is the owner of the Community'
    OWNER_TOKEN_CHEKLIST_ELEMENT_3 = 'Ability to airdrop / destroy TokenMaster token'
    OWNER_TOKEN_CHEKLIST_ELEMENT_4 = 'Ability to mint and airdrop Community tokens'
    MASTER_TOKEN_CHEKLIST_ELEMENT_1 = 'Unlimited supply'
    MASTER_TOKEN_CHEKLIST_ELEMENT_2 = 'Grants full Community admin rights'
    MASTER_TOKEN_CHEKLIST_ELEMENT_3 = 'Ability to mint and airdrop Community tokens'
    MASTER_TOKEN_CHEKLIST_ELEMENT_4 = 'Non-transferrable'
    MASTER_TOKEN_CHEKLIST_ELEMENT_5 = 'Remotely destructible by the Owner token hodler'
    SIGN_TRANSACTION_MINT_TITLE = ' Owner and TokenMaster tokens on '
    OWNER_TOKEN_NAME = 'Owner-'
    MASTER_TOKEN_NAME = 'TMaster-'
    OWNER_TOKEN_SYMBOL = 'OWN'
    MASTER_TOKEN_SYMBOL = 'TM'
    TOAST_AIRDROPPING_TOKEN_1 = 'Airdropping '
    TOAST_AIRDROPPING_TOKEN_2 = ' Owner token to you...'
    TOAST_TOKENS_BEING_MINTED = ' Owner and TokenMaster tokens are being minted...'
    TOAST_MINTING_TOKENS = 'Minting'


class ToastMessages(Enum):
    CREATE_PERMISSION_TOAST = 'Community permission created'
    UPDATE_PERMISSION_TOAST = 'Community permission updated'
    DELETE_PERMISSION_TOAST = 'Community permission deleted'
    KICKED_USER_TOAST = ' was kicked from '
    BLOCKED_USER_TOAST = ' blocked'
    UNBLOCKED_USER_TOAST = ' unblocked'
    REMOVED_CONTACT_TOAST = 'Contact removed'
    BANNED_USER_TOAST = ' was banned from '
    UNBANNED_USER_TOAST = ' unbanned from '
    UNBANNED_USER_CONFIRM = 'You were unbanned from '


class BlockPopupWarnings(Enum):
    BLOCK_WARNING_PART_1 = 'Blocking a user purges the database of all messages that you’ve previously received from '
    BLOCK_WARNING_PART_2 = ' in all contexts. This can take a moment.'
    UNBLOCK_TEXT_1 = 'Unblocking '
    UNBLOCK_TEXT_2 = ' will allow new messages you receive from '
    UNBLOCK_TEXT_3 = ' to reach you.'


class Channel(Enum):
    DEFAULT_CHANNEL_NAME = 'general'
    DEFAULT_CHANNEL_DESC = 'General channel for the community'
