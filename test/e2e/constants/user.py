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
