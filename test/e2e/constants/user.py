from dataclasses import dataclass, field
from typing import Optional

from scripts.utils.generators import random_name_string, random_password_string


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


user_account_one = UserAccount('community_owner', '1111111111', [None], None)
user_account_two = UserAccount('community_member', '1111111111', [None], None)

community_member = UserAccount('member', '1111111111', [None], None)

wallet_load = UserAccount('wallet_load', '1111111111', [None], None)
wallet_load_alex = UserAccount('wallet_load_alex', '1111111111', [None], None)
status_community_member = UserAccount('status_community_member', '1111111111', [None], None)

message_sync_user = UserAccount('message_sync_user', '1111111111', [None], None)
message_sync_contact = UserAccount('message_sync_contact', '1111111111', [None], None)
