import os
from dataclasses import dataclass, field
from typing import Optional

from scripts.utils.generators import random_name_string, random_password_string


@dataclass
class UserAccount:
    name: str = None
    password: str = None
    seed_phrase: Optional[list] = field(default_factory=list)
    status_address: Optional[str] = None
    set_display_name: bool = True
    profile_name: Optional[str] = None


class RandomUser(UserAccount):
    def __init__(self, set_display_name: bool = True):
        super().__init__(
            name=random_name_string(),
            password=random_password_string(),
            set_display_name=set_display_name,
        )


class ReturningUser(UserAccount):
    def __init__(self, seed_phrase, status_address):
        super().__init__(
            name=random_name_string(),
            password=random_password_string(),
            seed_phrase=seed_phrase,
            status_address=status_address
        )


def user_data_password() -> str:
    password = (os.getenv('USER_DATA_PASSWORD') or '').strip()
    if not password:
        raise RuntimeError(
            'USER_DATA_PASSWORD is not set. '
            'It is the login password for profiles in ext/user_data.'
        )
    return password


class PrebuiltUser(UserAccount):
    """Profile restored from ext/user_data. Password comes from USER_DATA_PASSWORD."""

    def __init__(self, name: str, status_address: Optional[str] = None):
        super().__init__(
            name=name,
            password='',
            seed_phrase=[None],
            status_address=status_address,
        )

    @property
    def password(self) -> str:
        return user_data_password()

    @password.setter
    def password(self, value: str):
        return

    def __repr__(self) -> str:
        return f'{type(self).__name__}(name={self.name!r}, status_address={self.status_address!r})'


user_account_one = PrebuiltUser('community_owner')
user_account_two = PrebuiltUser('community_member')

community_member = PrebuiltUser('member')

wallet_load = PrebuiltUser('wallet_load')
wallet_load_alex = PrebuiltUser('wallet_load_alex')
funds = PrebuiltUser('funds', '0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')
status_community_member = PrebuiltUser('status_community_member')

message_sync_user = PrebuiltUser('message_sync_user')
message_sync_contact = PrebuiltUser('message_sync_contact')
