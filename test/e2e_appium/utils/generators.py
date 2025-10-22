import logging
import random
import secrets
import string
from typing import Optional

from eth_account import Account
from eth_account.hdaccount import Mnemonic


_DEFAULT_MNEMONIC_LANGUAGE = "english"
_ALLOWED_WORD_COUNTS = (12, 18, 24)
_MNEMONIC_HELPER = Mnemonic(_DEFAULT_MNEMONIC_LANGUAGE)


_SECURE_RANDOM = random.SystemRandom()

try:
    Account.enable_unaudited_hdwallet_features()
except Exception:
    logging.getLogger(__name__).debug(
        "Failed to enable unaudited HD wallet features", exc_info=True
    )


def generate_seed_phrase(word_count: Optional[int] = None) -> str:
    """Generate a valid BIP39 seed phrase.

    Args:
        word_count: Number of words in the seed phrase (12, 18, or 24).
                   If None, randomly selects from [12, 18, 24].

    Returns:
        Valid BIP39 seed phrase as a string.
    """
    if word_count is None:
        word_count = random.choice(_ALLOWED_WORD_COUNTS)

    if word_count not in _ALLOWED_WORD_COUNTS:
        raise ValueError("word_count must be 12, 18, or 24")

    return _MNEMONIC_HELPER.generate(num_words=word_count)


def generate_12_word_seed_phrase() -> str:
    """Generate a 12-word seed phrase."""
    return generate_seed_phrase(12)


def generate_24_word_seed_phrase() -> str:
    """Generate a 24-word seed phrase."""
    return generate_seed_phrase(24)


def generate_ethereum_address() -> str:
    """Generate a random EIP-55 checksummed Ethereum address."""
    acct = Account.create()
    return acct.address.lower()


def generate_account_name(length: int = 12) -> str:
    """Generate a simple name for UI entries."""
    length = max(4, min(length, 24))
    letters = string.ascii_letters
    return "".join(random.choice(letters) for _ in range(length))


def get_wallet_address_from_mnemonic(
    seed_phrase: str, derivation_path: str = "m/44'/60'/0'/0/0"
) -> str:
    account = Account.from_mnemonic(seed_phrase, account_path=derivation_path)
    return account.address


def generate_secure_password(length: int = 16) -> str:
    """Generate a strong password that meets basic complexity requirements."""
    # Desktop UI enforces a 12-character minimum password; mirror that here.
    length = max(length, 12)

    lowercase = string.ascii_lowercase
    uppercase = string.ascii_uppercase
    digits = string.digits
    symbols = "!@#$%^&*"

    password_chars = [
        secrets.choice(lowercase),
        secrets.choice(uppercase),
        secrets.choice(digits),
        secrets.choice(symbols),
    ]

    all_chars = lowercase + uppercase + digits + symbols
    password_chars += [secrets.choice(all_chars) for _ in range(length - 4)]

    _SECURE_RANDOM.shuffle(password_chars)
    return "".join(password_chars)
