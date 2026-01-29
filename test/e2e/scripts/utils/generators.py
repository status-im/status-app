import json
import random
import string
from zpywallet import HDWallet
from zpywallet.network import EthereumMainNet
from eth_account.hdaccount import generate_mnemonic, Mnemonic

import configs
from constants import user, WalletAccountColors


def random_name_string():
    return ''.join((random.choice(
        string.ascii_letters + string.digits + random.choice('_- '))
        for _ in range(5, 25))
    ).strip(' ')


def random_password_string():
    return ''.join((random.choice(
        string.ascii_letters + string.digits + string.punctuation)
        for _ in range(10, 101))
    )


def random_ens_string():
    return ''.join(
        random.choices(string.digits + string.ascii_lowercase, k=8))


def random_network(): # 'Linea Sepolia'
    return random.choice(['Arbitrum Sepolia', 'Optimism Sepolia', 'Base Sepolia', 'Status Network Sepolia', 'Linea Sepolia'])


def random_community_name():
    return ''.join(random.choices(string.ascii_letters +
                                  string.digits, k=30))


def random_community_description():
    return ''.join(random.choices(string.ascii_letters +
                                  string.digits, k=140))


def random_community_introduction():
    return ''.join(random.choices(string.ascii_letters +
                                  string.digits, k=200))


def random_community_leave_message():
    return ''.join(random.choices(string.ascii_letters +
                                  string.digits, k=80))


def random_community_tags():
    num_tags = random.randint(1, 3)
    return random.sample(user.community_tags, num_tags)


def random_color():
    random_number = random.randint(0, 0xFFFFFF)
    hex_color = f'#{random_number:06x}'
    return hex_color


def random_mnemonic():
    words = ''
    while not Mnemonic().is_mnemonic_valid(mnemonic=words):
        new_words = generate_mnemonic(num_words=random.choice([12, 18, 24]), lang='english')
        words = new_words
    return words


def random_wallet_acc_keypair_name():
    return ''.join((random.choice(
        string.ascii_letters + string.digits)
        for _ in range(5, 21)))


def get_wallet_address_from_mnemonic(mnemonic_data) -> str:
    w = HDWallet.from_mnemonic(mnemonic=mnemonic_data, passphrase='', network=EthereumMainNet)
    child_w = w.get_child_for_path("m/44'/60'/0'/0/0")
    address_from_mnemonic = child_w.address()
    return address_from_mnemonic


def random_text_message():
    return ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(1, 141))


def random_emoji_with_unicode() -> tuple:
    with open(configs.testpath.TEST_FILES / 'emojis_unicodes_list.json', "r", encoding="utf-8") as file:
        data = json.load(file)
        random_item = random.choice(data)
        return random_item['shortname'], random_item['unicode']


def random_wallet_account_color():
    color = random.choice(WalletAccountColors.wallet_account_colors())
    return color.lower()
