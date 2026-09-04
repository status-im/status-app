import random
from dataclasses import dataclass
from enum import Enum, IntEnum

from constants.networks import WalletNetworkNaming
from scripts.utils.generators import (
    random_emoji_with_unicode,
    random_wallet_acc_keypair_name,
    random_wallet_account_color,
)


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


@dataclass
class WalletAccountListItem:
    name: str
    icon_color: str
    icon_emoji: str
    object: object


@dataclass
class TokenListItem:
    title: str
    object: object


@dataclass
class PrivateKeyAddressPair:
    private_key: str
    wallet_address: str


private_key_address_pair_1 = PrivateKeyAddressPair(
    '2daa36a3abe381a9c01610bf10fda272fbc1b8a22179a39f782c512346e3e470',
    '0xd89b48cbcb4244f84a4fb5d3369c120e8f8aa74e'
)


class DerivationPathName(Enum):
    ETHEREUM = 'Ethereum'
    ETHEREUM_LEDGER = 'Ethereum (Ledger)'

    @classmethod
    def xpub_derivation_path_names(cls):
        """Derivation path presets available when deriving from stored xpub."""
        return [cls.ETHEREUM, cls.ETHEREUM_LEDGER]

    @classmethod
    def select_random_path_name(cls):
        return random.choice(cls.xpub_derivation_path_names())


class WalletAddress(Enum):
    RECEIVER_ADDRESS = '0x3286c371ef648fe6232324b27ee0515f4ded24d9'


class WalletTokenSymbols(Enum):
    USDS = 'USDS'
    USDC = 'USDC (EVM)'
    SNT = 'SNT'
    STT = 'STT'
    ETH = 'ETH'
    DAI = 'DAI'

    @property
    def title(self) -> str:
        return _WALLET_TOKEN_TITLES[self]

    @classmethod
    def from_title(cls, title: str) -> 'WalletTokenSymbols':
        for member in cls:
            if member.title == title:
                return member
        raise ValueError(f'Unknown wallet token title: {title!r}')

    @classmethod
    def random_asset_details_symbol(cls) -> str:
        return random.choice([member.value for member in cls if member is not cls.STT])


_WALLET_TOKEN_TITLES = {
    WalletTokenSymbols.USDS: 'USDS',
    WalletTokenSymbols.USDC: 'USDC (EVM)',
    WalletTokenSymbols.SNT: 'Status',
    WalletTokenSymbols.STT: 'Status',
    WalletTokenSymbols.ETH: 'Ethereum',
    WalletTokenSymbols.DAI: 'DAI',
}

WALLET_ACCOUNT_EXPECTED_ASSET_TITLES = frozenset(token.title for token in WalletTokenSymbols)

ASSET_DETAILS_INVALID_VALUES = frozenset({'', 'Dummy', 'N/A'})


class DerivationPathValue(Enum):
    STATUS_ACCOUNT_DERIVATION_PATH = "m / 44' / 60' / 0' / 0 / 0"
    GENERATED_ACCOUNT_DERIVATION_PATH_1 = "m / 44' / 60' / 0' / 0 / 1"


class WalletNetworkSettings(Enum):
    STATUS_ACCOUNT_DEFAULT_NAME = 'Account 1'
    STATUS_ACCOUNT_DEFAULT_COLOR = '#2a4af5'


class WalletAccountSettings(Enum):
    STATUS_ACCOUNT_ORIGIN = 'Derived from your default Status key pair'
    WATCHED_ADDRESS_ORIGIN = 'Watched address'
    STORED_ON_DEVICE = 'On device'
    WATCHED_ADDRESSES_KEYPAIR_LABEL = 'Watched addresses'


class WalletOrigin(Enum):
    WATCHED_ADDRESS_ORIGIN = 'New watched address'


class WalletTransactions(Enum):
    TRANSACTION_SENDING_TOAST_MESSAGE = 'Sending'
    ENS_TRANSACTION_REGISTERING_TOAST_MESSAGE = 'Registering'


# Mirrors Constants.TransactionType in ui/imports/utils/Constants.qml
class WalletTransactionType(IntEnum):
    SEND = 0
    RECEIVE = 1
    BUY = 2
    SWAP = 3
    BRIDGE = 4
    CONTRACT_DEPLOYMENT = 5
    MINT = 6
    APPROVE = 7
    CONTRACT_INTERACTION = 8
    UNKNOWN = 9
    SELL = 10
    DESTROY = 11


class WalletHistoryTitles:
    SEND = ('Sent',)
    ENS = ('Interaction', 'Contract deployed')
    MINT = ('Interaction', 'Token minted', 'Collectible minted', 'Contract deployed')


class WalletScreensHeaders(Enum):
    WALLET_ADD_ACCOUNT_POPUP_TITLE = 'Add a new account'
    WALLET_EDIT_ACCOUNT_POPUP_TITLE = 'Edit account'


class WalletRenameKeypair(Enum):
    WALLET_SUCCESSFUL_RENAMING = 'You successfully renamed your key pair\n'


class WalletSeedPhrase(Enum):
    WALLET_SEED_PHRASE_ALREADY_ADDED = 'The entered recovery phrase is already added'


class WalletAccountPopup(Enum):
    WALLET_ACCOUNT_NAME_MIN = 'Account name must be at least 1 character'
    WALLET_KEYPAIR_NAME_MIN = 'Key pair name must be at least 1 character'
    WALLET_KEYPAIR_MIN = 'Key pair must be at least 1 character(s)'
