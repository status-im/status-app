import json
import logging
import os
import random
import tempfile
import time

import configs
from scripts.utils.generators import random_ens_string

STORE_PATH = configs.testpath.ROOT / 'resources' / 'purchased_ens_names.json'
# The UI cannot release the preferred name, so release needs at least two owned names.
MIN_OWNED_NAMES = 2
# Sepolia registrar releaseDelay().
MIN_AGE_SEC = 10 * 60
LOG = logging.getLogger(__name__)
_REQUIRED_FIELDS = {
    'name': str,
    'purchased_at': (int, float),
    'owner_address': str,
    'chain_id': int,
    'tx_hash': str,
}


def _load() -> list:
    if not STORE_PATH.exists():
        return []
    try:
        with open(STORE_PATH, encoding='utf-8') as store_file:
            records = json.load(store_file)
        if not isinstance(records, list) or any(
            not isinstance(record, dict)
            or any(not isinstance(record.get(key), value_type)
                   for key, value_type in _REQUIRED_FIELDS.items())
            for record in records
        ):
            raise ValueError('registry has an invalid schema')
        return records
    except (OSError, ValueError, TypeError) as error:
        LOG.warning('Ignoring unreadable ENS registry %s: %s', STORE_PATH, error)
        return []


def _save(records: list) -> None:
    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(
        dir=STORE_PATH.parent,
        prefix=f'.{STORE_PATH.name}.',
    )
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as store_file:
            json.dump(records, store_file, indent=2)
            store_file.write('\n')
        os.replace(temporary_path, STORE_PATH)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def random_ens_name_for_purchase(attempts: int = 100) -> str:
    owned = {record.get('name') for record in _load()}
    for _ in range(attempts):
        name = random_ens_string()
        if name not in owned:
            return name
    raise RuntimeError('Failed to generate an ENS name that is not already purchased')


def append_purchased_ens_name(
    name: str,
    purchased_at: float,
    owner_address: str,
    chain_id: int,
    tx_hash: str,
) -> None:
    records = _load()
    if any(record.get('name') == name for record in records):
        return
    records.append({
        'name': name,
        'purchased_at': purchased_at,
        'owner_address': owner_address,
        'chain_id': chain_id,
        'tx_hash': tx_hash,
    })
    _save(records)


def remove_purchased_ens_name(name: str) -> None:
    records = _load()
    remaining = [record for record in records if record.get('name') != name]
    if len(remaining) != len(records):
        _save(remaining)


def random_ens_name_ready_for_release() -> str | None:
    records = _load()
    if len(records) < MIN_OWNED_NAMES:
        return None
    now = time.time()
    ready = [
        record['name']
        for record in records
        if now - record['purchased_at'] > MIN_AGE_SEC
    ]
    if not ready:
        return None
    return random.choice(ready)
