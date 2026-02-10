from collections import namedtuple
from dataclasses import dataclass, field
from typing import Optional

import configs
from scripts.tools.image import Image
from scripts.utils.generators import random_name_string, random_password_string, random_community_name, \
    random_community_description, random_community_introduction, random_community_leave_message, random_community_tags, \
    random_color, random_wallet_acc_keypair_name, random_emoji_with_unicode, random_wallet_account_color


@dataclass
class UserAccount:
    name: str = None
    password: str = None
    seed_phrase: Optional[list] = field(default_factory=list)
    status_address: Optional[str] = None


class RandomUser(UserAccount):
    def __init__(self):
        super().__init__(
            name=random_name_string(),
            password=random_password_string()
        )


class ReturningUser(UserAccount):
    def __init__(self, seed_phrase, status_address):
        super().__init__(
            name=random_name_string(),
            password=random_password_string(),
            seed_phrase=seed_phrase,
            status_address=status_address
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


class RandomCommunity(CommunityData):
    def __init__(self):
        super().__init__(
            name=random_community_name(),
            description=random_community_description(),
            logo={'fp': configs.testpath.TEST_IMAGES / 'comm_logo.jpeg', 'zoom': None, 'shift': None},
            banner={'fp': configs.testpath.TEST_IMAGES / 'comm_banner.jpeg', 'zoom': None, 'shift': None},
            color=random_color(),
            tags=random_community_tags(),
            introduction=random_community_introduction(),
            leaving_message=random_community_leave_message()

        )


user_account_one = UserAccount('squisher', '0000000000', [
    'rail', 'witness', 'era', 'asthma', 'empty', 'cheap', 'shed', 'pond', 'skate', 'amount', 'invite', 'year'
], '0x3286c371ef648fe6232324b27ee0515f4ded24d9')
user_account_two = UserAccount('athletic', '0000000000', [
    'measure', 'cube', 'cousin', 'debris', 'slam', 'ignore', 'seven', 'hat', 'satisfy', 'frown', 'casino', 'inflict'
], '0x99C096bB5F12bDe37DE9dbee8257Ebe2a5667C46')

community_member = UserAccount('member', '1111111111', [None], None)

wallet_load = UserAccount('wallet_load', '1111111111', [None], None)
wallet_load_alex = UserAccount('wallet_load_alex', '1111111111', [None], None)
status_community_member = UserAccount('status_community_member', '1111111111', [None], None)


@dataclass
class WalletAccount:
    name: str = None
    color: str = None
    emoji: str = None


class RandomWalletAccount(WalletAccount):
    def __init__(self):
        super().__init__(
            name=random_wallet_acc_keypair_name(),
            color=random_wallet_account_color(),
            emoji=random_emoji_with_unicode()
        )


wallet_account_list_item = namedtuple('WalletAccountListItem', ['name', 'icon_color', 'icon_emoji', 'object'])

wallet_account = namedtuple('PrivateKeyAddressPair', ['private_key', 'wallet_address'])
private_key_address_pair_1 = wallet_account('2daa36a3abe381a9c01610bf10fda272fbc1b8a22179a39f782c512346e3e470',
                                            '0xd89b48cbcb4244f84a4fb5d3369c120e8f8aa74e')

token_list_item = namedtuple('TokenListItem', ['title', 'object'])

community_tags = ['Activism', 'Art', 'Blockchain', 'Books & blogs', 'Career', 'Collaboration', 'Commerce', 'Culture',
                  'DAO', 'DIY', 'DeFi', 'Design', 'Education', 'Entertainment', 'Environment', 'Ethereum', 'Event',
                  'Fantasy', 'Fashion', 'Food', 'Gaming', 'Global', 'Health', 'Hobby', 'Innovation', 'Language',
                  'Lifestyle', 'Local', 'Love', 'Markets', 'Movies & TV', 'Music', 'NFT', 'NSFW', 'News', 'Non-profit',
                  'Org', 'Pets', 'Play', 'Podcast', 'Politics', 'Privacy', 'Product', 'Psyche', 'Security', 'Social',
                  'Software dev', 'Sports', 'Tech', 'Travel', 'Vehicles', 'Web3']

permission_data = [
    {
        'checkbox_state': True,
        'first_asset': 'Status',
        'second_asset': False,
        'amount': '10',
        'allowed_to': 'becomeMember',
        'in_channel': False,
        'asset_title': '10 SNT',
        'second_asset_title': False,
        'allowed_to_title': 'Become member'
    }
    # {
    #     'checkbox_state': True,
    #     'first_asset': 'Status',
    #     'second_asset': False,
    #     'amount': '1',
    #     'allowed_to': 'becomeAdmin',
    #     'in_channel': False,
    #     'asset_title': '1 SNT',
    #     'second_asset_title': False,
    #     'allowed_to_title': 'Become an admin'
    # },
    # {
    #     'checkbox_state': True,
    #     'first_asset': 'Status',
    #     'second_asset': 'Eggle Energy',
    #     'amount': '10',
    #     'allowed_to': 'viewAndPost',
    #     'in_channel': '#general',
    #     'asset_title': '10 SNT',
    #     'second_asset_title': '10 ENG',
    #     'allowed_to_title': 'View and post'
    # },
    # {
    #     'checkbox_state': True,
    #     'first_asset': 'Status',
    #     'second_asset': 'Eggle Energy',
    #     'amount': '10',
    #     'allowed_to': 'viewOnly',
    #     'in_channel': '#general',
    #     'asset_title': '10 SNT',
    #     'second_asset_title': '10 ENG',
    #     'allowed_to_title': 'View only'
    # },
    # {
    #     'checkbox_state': False,
    #     'first_asset': False,
    #     'second_asset': False,
    #     'amount': False,
    #     'allowed_to': 'becomeAdmin',
    #     'in_channel': False,
    #     'asset_title': False,
    #     'second_asset_title': False,
    #     'allowed_to_title': 'Become an admin'
    # }
]

permission_data_member = [
    {
        'checkbox_state': True,
        'first_asset': 'Status',
        'amount': '1',
        'allowed_to': 'becomeMember',
        'asset_title': '1 SNT',
        'allowed_to_title': 'Become member'
    },
    {
        'checkbox_state': True,
        'first_asset': 'Aragon',
        'amount': '2',
        'allowed_to': 'becomeMember',
        'asset_title': '2 ANT',
        'allowed_to_title': 'Become member'
    },
    {
        'checkbox_state': True,
        'first_asset': '1inch',
        'amount': '3',
        'allowed_to': 'becomeMember',
        'asset_title': '3 1INCH',
        'allowed_to_title': 'Become member'
    },
    {
        'checkbox_state': True,
        'first_asset': 'ABYSS',
        'amount': '4',
        'allowed_to': 'becomeMember',
        'asset_title': '4 ABYSS',
        'allowed_to_title': 'Become member'
    },
    {
        'checkbox_state': True,
        'first_asset': '0x Protocol',
        'amount': '50',
        'allowed_to': 'becomeMember',
        'asset_title': '50 ZRX',
        'allowed_to_title': 'Become member'
    }
]
